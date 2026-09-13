-- WYN-157 / full-system QA hardening.
--
-- Fixes three production-only gaps found during the 2026-09-13 audit:
--   1) WYN-155 accidentally restored authenticated EXECUTE on RPCs that older
--      migrations deliberately restricted to service/backend callers.
--   2) Anonymous Supabase users carry the `authenticated` Postgres role, so
--      hiding the Guest UI alone did not make guest sessions read-only.
--   3) Feed ranking caches had no scheduler and had stopped refreshing.
--
-- This migration is forward-only. It does not revert WYN-155; it narrows the
-- explicit exceptions that must stay backend-only, adds one restrictive write
-- guard to every RLS-protected public table (plus storage.objects), and installs
-- the missing feed-cache scheduler when pg_cron is available.

-- ---------------------------------------------------------------------------
-- 1. Restore service/backend-only RPC privileges that WYN-155 broadened.
-- ---------------------------------------------------------------------------

revoke all on function public.reserve_location_search_request(uuid,integer,integer)
  from public, anon, authenticated;
revoke all on function public.refresh_trending_scores(timestamptz)
  from public, anon, authenticated;
revoke all on function public.refresh_top100_scores(timestamptz)
  from public, anon, authenticated;
revoke all on function public.refresh_feed_content_quality(timestamptz)
  from public, anon, authenticated;
revoke all on function public.refresh_feed_similarities(timestamptz)
  from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.reserve_location_search_request(uuid,integer,integer)
      to service_role;
    grant execute on function public.refresh_trending_scores(timestamptz)
      to service_role;
    grant execute on function public.refresh_top100_scores(timestamptz)
      to service_role;
    grant execute on function public.refresh_feed_content_quality(timestamptz)
      to service_role;
    grant execute on function public.refresh_feed_similarities(timestamptz)
      to service_role;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. Make "Guest disabled" a database boundary, not a UI convention.
--
-- Supabase anonymous users use role `authenticated`. A RESTRICTIVE policy is
-- AND-ed with every existing permissive policy, so an anonymous JWT cannot
-- write even when a feature-specific policy otherwise allows auth.uid().
-- Reads are deliberately unchanged. Missing is_anonymous on legacy/permanent
-- JWTs is treated as false so old real-account sessions keep working.
-- ---------------------------------------------------------------------------

do $$
declare
  t record;
begin
  for t in
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
    order by c.relname
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      'wyn157_permanent_insert', t.schema_name, t.table_name
    );
    execute format(
      'create policy %I on %I.%I as restrictive for insert to authenticated '
      'with check (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)',
      'wyn157_permanent_insert', t.schema_name, t.table_name
    );

    execute format(
      'drop policy if exists %I on %I.%I',
      'wyn157_permanent_update', t.schema_name, t.table_name
    );
    execute format(
      'create policy %I on %I.%I as restrictive for update to authenticated '
      'using (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false) '
      'with check (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)',
      'wyn157_permanent_update', t.schema_name, t.table_name
    );

    execute format(
      'drop policy if exists %I on %I.%I',
      'wyn157_permanent_delete', t.schema_name, t.table_name
    );
    execute format(
      'create policy %I on %I.%I as restrictive for delete to authenticated '
      'using (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)',
      'wyn157_permanent_delete', t.schema_name, t.table_name
    );
  end loop;
end
$$;

-- Storage is outside public, so mirror the same boundary explicitly.
do $$
begin
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists "wyn157_permanent_insert" on storage.objects';
    execute 'create policy "wyn157_permanent_insert" on storage.objects '
      'as restrictive for insert to authenticated '
      'with check (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)';

    execute 'drop policy if exists "wyn157_permanent_update" on storage.objects';
    execute 'create policy "wyn157_permanent_update" on storage.objects '
      'as restrictive for update to authenticated '
      'using (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false) '
      'with check (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)';

    execute 'drop policy if exists "wyn157_permanent_delete" on storage.objects';
    execute 'create policy "wyn157_permanent_delete" on storage.objects '
      'as restrictive for delete to authenticated '
      'using (coalesce((select (auth.jwt()->>''is_anonymous'')::boolean), false) is false)';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Refresh feed caches through one ordered backend-only job.
-- ---------------------------------------------------------------------------

create schema if not exists internal;

create or replace function internal.refresh_feed_caches()
returns jsonb
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_at timestamptz := clock_timestamp();
  v_trending integer;
  v_top100 integer;
  v_quality integer;
  v_similarity integer;
begin
  -- Keep this order: downstream ranking uses the newest trending evidence,
  -- then quality and similarity caches are rebuilt against the same snapshot.
  v_trending := public.refresh_trending_scores(v_at);
  v_top100 := public.refresh_top100_scores(v_at);
  v_quality := public.refresh_feed_content_quality(v_at);
  v_similarity := public.refresh_feed_similarities(v_at);

  return jsonb_build_object(
    'refreshed_at', v_at,
    'trending_rows', v_trending,
    'top100_rows', v_top100,
    'quality_rows', v_quality,
    'similarity_rows', v_similarity
  );
end;
$$;

revoke all on function internal.refresh_feed_caches() from public;
revoke all on function internal.refresh_feed_caches() from anon, authenticated;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant usage on schema internal to service_role;
    grant execute on function internal.refresh_feed_caches() to service_role;
  end if;
end
$$;

-- pg_cron is available on hosted Supabase but is not guaranteed to exist in
-- the lightweight PostgreSQL used by repository regression tests. Install and
-- schedule only when the extension is available on this server.
do $$
declare
  v_job_id bigint;
  v_existing_job_id bigint;
begin
  if exists (
    select 1 from pg_available_extensions where name = 'pg_cron'
  ) then
    execute 'create extension if not exists pg_cron';

    if to_regclass('cron.job') is not null then
      for v_existing_job_id in
        select jobid from cron.job where jobname = 'wynos-refresh-feed-caches'
      loop
        execute 'select cron.unschedule($1)' using v_existing_job_id;
      end loop;
    end if;

    execute 'select cron.schedule($1, $2, $3)'
      into v_job_id
      using
        'wynos-refresh-feed-caches',
        '*/5 * * * *',
        'select internal.refresh_feed_caches();';
  end if;
end
$$;

-- Refresh immediately so production does not wait for the first cron tick.
do $$
begin
  perform internal.refresh_feed_caches();
end
$$;
