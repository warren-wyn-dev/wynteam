-- WYNOS Web Beta 1 — new-user reactivation Push
-- Cadence: +24h, +3d, +7d, then every 7d until the account becomes active.
-- This migration only owns durable state/RPCs. The production cron caller is
-- provisioned separately because its project URL/API credential belong in Vault.

create table if not exists internal.web_reactivation_state (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  registered_at timestamptz not null,
  activated_at timestamptz,
  send_count integer not null default 0 check (send_count >= 0),
  last_sent_at timestamptz,
  next_due_at timestamptz not null,
  lease_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

revoke all on table internal.web_reactivation_state from public, anon, authenticated;

create or replace function internal.web_reactivation_safe_due(p_due timestamptz)
returns timestamptz
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_local timestamp;
begin
  -- Never wake people overnight. The first WYNOS Web Beta 1 market is
  -- Thailand; a future timezone-aware campaign can replace this helper.
  v_local := p_due at time zone 'Asia/Bangkok';

  if v_local::time < time '09:00' then
    v_local := date_trunc('day', v_local) + interval '9 hours';
  elsif v_local::time >= time '21:00' then
    v_local := date_trunc('day', v_local) + interval '1 day 9 hours';
  end if;

  return v_local at time zone 'Asia/Bangkok';
end;
$$;

revoke all on function internal.web_reactivation_safe_due(timestamptz) from public, anon, authenticated;

create or replace function internal.enroll_web_reactivation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into internal.web_reactivation_state (
    user_id,
    registered_at,
    next_due_at
  )
  values (
    new.id,
    new.created_at,
    internal.web_reactivation_safe_due(new.created_at + interval '24 hours')
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function internal.enroll_web_reactivation() from public, anon, authenticated;

drop trigger if exists profiles_enroll_web_reactivation on public.profiles;
create trigger profiles_enroll_web_reactivation
after insert on public.profiles
for each row
execute function internal.enroll_web_reactivation();

-- Do not blast old accounts when this launches. Only preserve users who
-- registered during the previous 24 hours, and treat a later Web Push token
-- refresh as evidence they already returned after signup.
insert into internal.web_reactivation_state (
  user_id,
  registered_at,
  activated_at,
  next_due_at
)
select
  p.id,
  p.created_at,
  case
    when exists (
      select 1
      from public.push_tokens pt
      where pt.user_id = p.id
        and pt.platform = 'web'
        and pt.updated_at > p.created_at + interval '10 minutes'
    ) then now()
    else null
  end,
  internal.web_reactivation_safe_due(p.created_at + interval '24 hours')
from public.profiles p
where p.created_at >= now() - interval '24 hours'
on conflict (user_id) do nothing;

create or replace function public.mark_web_reactivation_activated()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_marked boolean := false;
begin
  if v_user_id is null then
    return false;
  end if;

  update internal.web_reactivation_state
  set
    activated_at = now(),
    lease_until = null,
    updated_at = now()
  where user_id = v_user_id
    and activated_at is null
    -- The first few minutes after account creation are onboarding, not a
    -- "return". Remaining in WYNOS for 10 minutes does count as activation.
    and registered_at <= now() - interval '10 minutes'
  returning true into v_marked;

  return coalesce(v_marked, false);
end;
$$;

revoke all on function public.mark_web_reactivation_activated() from public, anon, authenticated;
grant execute on function public.mark_web_reactivation_activated() to authenticated;

create or replace function internal.web_reactivation_is_quiet(
  p_timezone text,
  p_start time,
  p_end time
)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_now time;
  v_timezone text := coalesce(nullif(p_timezone, ''), 'UTC');
begin
  if p_start is null or p_end is null or p_start = p_end then
    return false;
  end if;

  begin
    v_now := (now() at time zone v_timezone)::time;
  exception
    when others then
      v_now := (now() at time zone 'UTC')::time;
  end;

  if p_start < p_end then
    return v_now >= p_start and v_now < p_end;
  end if;

  return v_now >= p_start or v_now < p_end;
end;
$$;

revoke all on function internal.web_reactivation_is_quiet(text, time, time) from public, anon, authenticated;

create or replace function public.claim_due_web_reactivations(p_limit integer default 50)
returns table (
  user_id uuid,
  stage integer,
  language text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service role required';
  end if;

  -- Global WYNOS Web Beta 1 guard: 09:00–21:00 Asia/Bangkok.
  if (now() at time zone 'Asia/Bangkok')::time < time '09:00'
     or (now() at time zone 'Asia/Bangkok')::time >= time '21:00' then
    return;
  end if;

  return query
  with due as (
    select s.user_id
    from internal.web_reactivation_state s
    left join public.notification_settings ns on ns.user_id = s.user_id
    where s.activated_at is null
      and s.next_due_at <= now()
      and (s.lease_until is null or s.lease_until < now())
      and coalesce(ns.system, true)
      and coalesce(ns.push_system, true)
      and (
        not coalesce(ns.push_quiet_enabled, false)
        or not internal.web_reactivation_is_quiet(
          ns.push_timezone,
          ns.push_quiet_start,
          ns.push_quiet_end
        )
      )
      and exists (
        select 1
        from public.push_tokens pt
        where pt.user_id = s.user_id
          and pt.platform = 'web'
      )
    order by s.next_due_at, s.user_id
    limit v_limit
    for update of s skip locked
  ),
  leased as (
    update internal.web_reactivation_state s
    set
      lease_until = now() + interval '15 minutes',
      updated_at = now()
    from due d
    where s.user_id = d.user_id
    returning s.user_id, s.send_count + 1 as stage
  )
  select
    l.user_id,
    l.stage,
    case when up.language_preference = 'en' then 'en' else 'th' end
  from leased l
  left join public.user_preferences up on up.user_id = l.user_id;
end;
$$;

revoke all on function public.claim_due_web_reactivations(integer) from public, anon, authenticated;
grant execute on function public.claim_due_web_reactivations(integer) to service_role;

create or replace function public.complete_web_reactivation(
  p_user_id uuid,
  p_sent boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service role required';
  end if;

  if p_sent then
    update internal.web_reactivation_state
    set
      send_count = send_count + 1,
      last_sent_at = now(),
      next_due_at = internal.web_reactivation_safe_due(
        case send_count
          when 0 then greatest(
            registered_at + interval '3 days',
            now() + interval '24 hours'
          )
          when 1 then greatest(
            registered_at + interval '7 days',
            now() + interval '24 hours'
          )
          else now() + interval '7 days'
        end
      ),
      lease_until = null,
      updated_at = now()
    where user_id = p_user_id
      and activated_at is null;
  else
    update internal.web_reactivation_state
    set
      next_due_at = greatest(next_due_at, now() + interval '1 hour'),
      lease_until = null,
      updated_at = now()
    where user_id = p_user_id
      and activated_at is null;
  end if;
end;
$$;

revoke all on function public.complete_web_reactivation(uuid, boolean) from public, anon, authenticated;
grant execute on function public.complete_web_reactivation(uuid, boolean) to service_role;
