-- WYNOS Web — Daily Follow Suggestions.
-- One Web Push per local day for eligible activated users. Reuses the existing
-- recommendation rules (self/followed/blocked/muted/dismissed/onboarding filters)
-- and avoids showing the same suggested profiles again for 7 days.

create table if not exists public.daily_follow_suggestion_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  local_date date not null,
  profile_ids uuid[] not null check (cardinality(profile_ids) between 1 and 5),
  status text not null default 'claimed' check (status in ('claimed','sent','failed')),
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (user_id, local_date)
);

create index if not exists daily_follow_suggestion_deliveries_user_created_idx
  on public.daily_follow_suggestion_deliveries(user_id, created_at desc);

alter table public.daily_follow_suggestion_deliveries enable row level security;
revoke all on table public.daily_follow_suggestion_deliveries from public, anon, authenticated;

create or replace function internal.daily_follow_suggestion_ids(
  p_user_id uuid,
  p_limit integer default 5
)
returns uuid[]
language sql
stable
security definer
set search_path = public, internal
as $$
  select coalesce(array_agg(candidate.id order by candidate.score desc, candidate.id), '{}'::uuid[])
  from (
    select
      p.id,
      (
        1000 * (
          select count(*)
          from public.follows social_edge
          where social_edge.following_id = p.id
            and social_edge.follower_id in (
              select mine.following_id
              from public.follows mine
              where mine.follower_id = p_user_id
            )
        )
        + least(100, (
          select count(*) from public.follows fc where fc.following_id = p.id
        ))
      )::bigint as score
    from public.profiles p
    where p.id <> p_user_id
      and not internal.is_blocked_either_way(p_user_id, p.id)
      and not exists (
        select 1 from public.follows f
        where f.follower_id = p_user_id and f.following_id = p.id
      )
      and not exists (
        select 1 from public.mutes m
        where m.muter_id = p_user_id and m.muted_id = p.id
      )
      and not exists (
        select 1 from public.profile_recommendation_dismissals d
        where d.user_id = p_user_id and d.dismissed_profile_id = p.id
      )
      and exists (
        select 1 from public.profile_private pp
        where pp.id = p.id and pp.onboarding_completed = true
      )
      and not exists (
        select 1
        from public.daily_follow_suggestion_deliveries old
        where old.user_id = p_user_id
          and old.created_at >= now() - interval '7 days'
          and p.id = any(old.profile_ids)
      )
    order by score desc, p.id
    limit greatest(1, least(coalesce(p_limit, 5), 5))
  ) candidate;
$$;

revoke all on function internal.daily_follow_suggestion_ids(uuid, integer)
  from public, anon, authenticated;

create or replace function public.claim_daily_follow_suggestion_pushes(p_limit integer default 100)
returns table (
  delivery_id uuid,
  user_id uuid,
  profile_ids uuid[]
)
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 100), 300));
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'service_role required';
  end if;

  return query
  with candidates as (
    select
      p.id as uid,
      coalesce(s.push_timezone, 'UTC') as tz,
      internal.daily_follow_suggestion_ids(p.id, 5) as ids,
      ((now() at time zone coalesce(s.push_timezone, 'UTC'))::date) as local_day
    from public.profiles p
    left join public.notification_settings s on s.user_id = p.id
    where coalesce(s.push_system, true)
      and exists (
        select 1 from public.push_tokens t
        where t.user_id = p.id and t.platform = 'web'
      )
      and not exists (
        select 1 from public.web_reactivation_state wr
        where wr.user_id = p.id and wr.activated_at is null
      )
      and (
        (now() at time zone coalesce(s.push_timezone, 'UTC'))::time >= time '10:00'
      )
      and not internal.web_reactivation_quiet_now(p.id)
      and not exists (
        select 1
        from public.daily_follow_suggestion_deliveries d
        where d.user_id = p.id
          and d.local_date = (now() at time zone coalesce(s.push_timezone, 'UTC'))::date
      )
    order by p.id
  ),
  inserted as (
    insert into public.daily_follow_suggestion_deliveries(user_id, local_date, profile_ids)
    select uid, local_day, ids
    from candidates
    where cardinality(ids) > 0
    limit v_limit
    on conflict (user_id, local_date) do nothing
    returning id, user_id, profile_ids
  )
  select i.id, i.user_id, i.profile_ids from inserted i;
end;
$$;

revoke all on function public.claim_daily_follow_suggestion_pushes(integer)
  from public, anon, authenticated;
grant execute on function public.claim_daily_follow_suggestion_pushes(integer)
  to service_role;

create or replace function public.finish_daily_follow_suggestion_push(
  p_delivery_id uuid,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'service_role required';
  end if;

  update public.daily_follow_suggestion_deliveries
  set status = case when p_success then 'sent' else 'failed' end,
      sent_at = case when p_success then now() else null end,
      error = case when p_success then null else left(p_error, 300) end
  where id = p_delivery_id
    and status = 'claimed';
end;
$$;

revoke all on function public.finish_daily_follow_suggestion_push(uuid, boolean, text)
  from public, anon, authenticated;
grant execute on function public.finish_daily_follow_suggestion_push(uuid, boolean, text)
  to service_role;

create or replace function public.verify_daily_follow_suggestion_cron_key(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_key is not null
     and length(p_key) >= 32
     and exists (
       select 1
       from vault.decrypted_secrets
       where name = 'wynos_daily_follow_cron_key'
         and decrypted_secret = p_key
     );
$$;

revoke all on function public.verify_daily_follow_suggestion_cron_key(text)
  from public, anon, authenticated;
grant execute on function public.verify_daily_follow_suggestion_cron_key(text)
  to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule(
      'wynos-daily-follow-suggestions',
      '37 * * * *',
      $job$
      select net.http_post(
        url := (
          select decrypted_secret from vault.decrypted_secrets
          where name = 'wynos_project_url' limit 1
        ) || '/functions/v1/send-daily-follow-suggestions',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-Wynos-Cron-Key', (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'wynos_daily_follow_cron_key' limit 1
          )
        ),
        body := '{"source":"pg_cron"}'::jsonb,
        timeout_milliseconds := 10000
      );
      $job$
    );

    perform cron.alter_job(
      job_id := (select jobid from cron.job where jobname = 'wynos-daily-follow-suggestions'),
      active := false
    );
  end if;
end
$$;
