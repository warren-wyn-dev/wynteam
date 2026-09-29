-- WYNOS Web Beta 1 — reactivation Push for newly enrolled web accounts.
-- Existing profiles are baselined as activated so this rollout never back-sends
-- reactivation messages to historical users.
--
-- Schedule after signup:
--   1) +24 hours
--   2) +3 days
--   3) +7 days
--   4+) every 7 days
-- The sequence stops permanently once the account is marked activated.

create table if not exists public.web_reactivation_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  enrolled_at timestamptz not null,
  first_app_seen_at timestamptz,
  last_seen_at timestamptz,
  activated_at timestamptz,
  sent_count integer not null default 0 check (sent_count >= 0),
  last_sent_at timestamptz,
  next_due_at timestamptz,
  lease_until timestamptz,
  lease_stage integer check (lease_stage is null or lease_stage >= 1),
  updated_at timestamptz not null default now()
);

create index if not exists web_reactivation_due_idx
  on public.web_reactivation_state(next_due_at)
  where activated_at is null and next_due_at is not null;

alter table public.web_reactivation_state enable row level security;
revoke all on table public.web_reactivation_state from public, anon, authenticated;

create table if not exists public.web_reactivation_deliveries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  stage integer not null check (stage >= 1),
  status text not null check (status in ('sent', 'failed', 'skipped')),
  error text,
  created_at timestamptz not null default now()
);

create index if not exists web_reactivation_deliveries_user_created_idx
  on public.web_reactivation_deliveries(user_id, created_at desc);

alter table public.web_reactivation_deliveries enable row level security;
revoke all on table public.web_reactivation_deliveries from public, anon, authenticated;

-- Baseline everyone who already exists at rollout time as activated.
insert into public.web_reactivation_state (
  user_id, enrolled_at, first_app_seen_at, last_seen_at, activated_at, next_due_at
)
select p.id, p.created_at, p.created_at, now(), now(), null
from public.profiles p
on conflict (user_id) do nothing;

create or replace function internal.enroll_web_reactivation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.web_reactivation_state (
    user_id,
    enrolled_at,
    next_due_at
  )
  values (
    new.id,
    new.created_at,
    new.created_at + interval '24 hours'
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists profiles_enroll_web_reactivation on public.profiles;
create trigger profiles_enroll_web_reactivation
after insert on public.profiles
for each row execute function internal.enroll_web_reactivation();

create or replace function public.mark_web_reactivation_seen()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_state public.web_reactivation_state%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select *
  into v_state
  from public.web_reactivation_state
  where user_id = v_uid
  for update;

  if not found then
    -- Fail safe for an account that predates this rollout but missed the
    -- baseline for any reason: treat it as already activated, never enroll it.
    insert into public.web_reactivation_state (
      user_id, enrolled_at, first_app_seen_at, last_seen_at, activated_at
    )
    select p.id, p.created_at, now(), now(), now()
    from public.profiles p
    where p.id = v_uid
    on conflict (user_id) do nothing;
    return true;
  end if;

  if v_state.activated_at is not null then
    update public.web_reactivation_state
    set last_seen_at = now(), updated_at = now()
    where user_id = v_uid;
    return true;
  end if;

  if v_state.first_app_seen_at is null then
    -- If the first tracker touch happens well after signup, the person has
    -- already returned from the abandoned signup session. Activate at once.
    if now() - v_state.enrolled_at >= interval '5 minutes' then
      update public.web_reactivation_state
      set first_app_seen_at = now(),
          last_seen_at = now(),
          activated_at = now(),
          next_due_at = null,
          lease_until = null,
          lease_stage = null,
          updated_at = now()
      where user_id = v_uid;
      return true;
    end if;

    update public.web_reactivation_state
    set first_app_seen_at = now(),
        last_seen_at = now(),
        updated_at = now()
    where user_id = v_uid;
    return false;
  end if;

  -- Any later touch means the person returned to WYNOS. The web tracker
  -- intentionally calls this a second time after five minutes if the first
  -- session stays open, so continuous real use also activates the account.
  update public.web_reactivation_state
  set activated_at = now(),
      last_seen_at = now(),
      next_due_at = null,
      lease_until = null,
      lease_stage = null,
      updated_at = now()
  where user_id = v_uid;
  return true;
end;
$$;

revoke all on function public.mark_web_reactivation_seen() from public, anon;
grant execute on function public.mark_web_reactivation_seen() to authenticated;

create or replace function internal.web_reactivation_quiet_now(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_enabled boolean;
  v_start time;
  v_end time;
  v_timezone text;
  v_local time;
begin
  select
    coalesce(n.push_quiet_enabled, false),
    coalesce(n.push_quiet_start, '22:00'::time),
    coalesce(n.push_quiet_end, '08:00'::time),
    coalesce(n.push_timezone, 'UTC')
  into v_enabled, v_start, v_end, v_timezone
  from public.notification_settings n
  where n.user_id = p_user_id;

  if not coalesce(v_enabled, false) or v_start = v_end then
    return false;
  end if;

  begin
    v_local := (now() at time zone v_timezone)::time;
  exception when others then
    return false;
  end;

  if v_start < v_end then
    return v_local >= v_start and v_local < v_end;
  end if;
  return v_local >= v_start or v_local < v_end;
end;
$$;

create or replace function public.claim_web_reactivation_pushes(p_limit integer default 50)
returns table (user_id uuid, stage integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 200));
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service_role required';
  end if;

  return query
  with candidates as (
    select s.user_id, s.sent_count + 1 as next_stage
    from public.web_reactivation_state s
    left join public.notification_settings n on n.user_id = s.user_id
    where s.activated_at is null
      and s.next_due_at is not null
      and s.next_due_at <= now()
      and (s.lease_until is null or s.lease_until < now())
      and coalesce(n.push_system, true)
      and not internal.web_reactivation_quiet_now(s.user_id)
      and exists (
        select 1
        from public.push_tokens t
        where t.user_id = s.user_id
          and t.platform = 'web'
      )
    order by s.next_due_at asc
    for update of s skip locked
    limit v_limit
  )
  update public.web_reactivation_state s
  set lease_until = now() + interval '10 minutes',
      lease_stage = c.next_stage,
      updated_at = now()
  from candidates c
  where s.user_id = c.user_id
  returning s.user_id, s.lease_stage;
end;
$$;

revoke all on function public.claim_web_reactivation_pushes(integer) from public, anon, authenticated;
grant execute on function public.claim_web_reactivation_pushes(integer) to service_role;

create or replace function public.finish_web_reactivation_push(
  p_user_id uuid,
  p_stage integer,
  p_success boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_state public.web_reactivation_state%rowtype;
  v_status text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service_role required';
  end if;

  select *
  into v_state
  from public.web_reactivation_state
  where user_id = p_user_id
  for update;

  if not found or v_state.lease_stage is distinct from p_stage then
    return;
  end if;

  if v_state.activated_at is not null then
    v_status := 'skipped';
    insert into public.web_reactivation_deliveries(user_id, stage, status, error)
    values (p_user_id, p_stage, v_status, 'activated');
    update public.web_reactivation_state
    set lease_until = null, lease_stage = null, next_due_at = null, updated_at = now()
    where user_id = p_user_id;
    return;
  end if;

  v_status := case when p_success then 'sent' else 'failed' end;
  insert into public.web_reactivation_deliveries(user_id, stage, status, error)
  values (p_user_id, p_stage, v_status, left(p_error, 300));

  if p_success then
    update public.web_reactivation_state
    set sent_count = p_stage,
        last_sent_at = now(),
        next_due_at = case
          when p_stage = 1 then greatest(enrolled_at + interval '3 days', now() + interval '1 hour')
          when p_stage = 2 then greatest(enrolled_at + interval '7 days', now() + interval '1 hour')
          else now() + interval '7 days'
        end,
        lease_until = null,
        lease_stage = null,
        updated_at = now()
    where user_id = p_user_id;
  else
    -- Keep next_due_at unchanged so the hourly runner retries the same stage.
    update public.web_reactivation_state
    set lease_until = null, lease_stage = null, updated_at = now()
    where user_id = p_user_id;
  end if;
end;
$$;

revoke all on function public.finish_web_reactivation_push(uuid, integer, boolean, text)
  from public, anon, authenticated;
grant execute on function public.finish_web_reactivation_push(uuid, integer, boolean, text)
  to service_role;

-- The actual key values are provisioned into Vault out-of-band; this migration
-- contains names only, never credentials.

create or replace function public.verify_web_reactivation_cron_key(p_key text)
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
       where name = 'wynos_web_reactivation_cron_key'
         and decrypted_secret = p_key
     );
$$;

revoke all on function public.verify_web_reactivation_cron_key(text)
  from public, anon, authenticated;
grant execute on function public.verify_web_reactivation_cron_key(text)
  to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net') then
    perform cron.schedule(
      'wynos-web-reactivation',
      '17 * * * *',
      $job$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'wynos_project_url'
          limit 1
        ) || '/functions/v1/send-web-reactivation',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'wynos_cron_anon_key'
            limit 1
          ),
          'Authorization', 'Bearer ' || (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'wynos_cron_anon_key'
            limit 1
          ),
          'X-Wynos-Cron-Key', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'wynos_web_reactivation_cron_key'
            limit 1
          )
        ),
        body := '{"source":"pg_cron"}'::jsonb,
        timeout_milliseconds := 10000
      );
      $job$
    );
  end if;
end
$$;
