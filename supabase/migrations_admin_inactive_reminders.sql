-- =====================================================================
-- WYNOS Admin: remind people who signed up but stopped using WYNOS
--
-- Founder request (2026-09-29): an Admin picks "not used for more than
-- 24 hours / 3 days / 7 days", writes the message and sends it by hand.
-- Delivery is the existing in-app 'system' notification, so the existing
-- send-push-notification webhook also sends a Push to registered devices.
--
-- Applied to production only by the Founder-approved workflow
-- .github/workflows/admin-apply-inactive-reminders.yml (AGENTS.md Change
-- Control). Tested by supabase/tests/admin_inactive_reminders_test.sh.
-- Additive and idempotent: one new internal table, three functions, and
-- one more allowed audit_log event type. No existing row is changed.
--
-- "Last used" is the latest of: account creation, sign-in, the auth
-- session being refreshed (the app is open), and any post, like,
-- comment, repost or message. Opening the app without posting therefore
-- counts as using it, so nobody is told to "come back" while they are here.
--
-- Guards:
--   * Admin only (same as admin_send_announcement).
--   * Only platform_role = 'user'; never staff; never banned, suspended
--     or restricted accounts.
--   * Respects the person's "system" notification setting.
--   * At most one reminder per person per 24 hours, whatever is chosen.
--   * Message trimmed, 1-500 characters.
--   * Every send is written to audit_log with the recipient count.
-- =====================================================================

create schema if not exists internal;

-- When each person was last reminded (one row per person).
create table if not exists internal.inactive_reminders (
  user_id uuid primary key references auth.users (id) on delete cascade,
  last_sent_at timestamptz not null
);
revoke all on internal.inactive_reminders from public;

-- The allowed audit_log event types are rebuilt from the live constraint,
-- so any type added elsewhere is kept.
do $$
declare
  v_name text;
  v_def text;
  v_values text[];
begin
  select con.conname, pg_get_constraintdef(con.oid)
    into v_name, v_def
  from pg_constraint con
  join pg_attribute att
    on att.attrelid = con.conrelid and att.attnum = any (con.conkey)
  where con.conrelid = 'public.audit_log'::regclass
    and con.contype = 'c'
    and att.attname = 'event_type'
  limit 1;

  if v_def is null then
    raise exception 'audit_log event_type check constraint not found';
  end if;

  -- The constraint is always written as `event_type in ('a', 'b', ...)`,
  -- which Postgres shows as ARRAY['a'::text, ...], so every value is quoted.
  select array_agg(distinct x.m[1] order by x.m[1])
    into v_values
  from regexp_matches(v_def, '''([a-z0-9_]+)''', 'g') as x(m);

  if v_values is null or cardinality(v_values) < 2 then
    raise exception 'Could not read the audit_log event types from: %', v_def;
  end if;

  if 'admin_inactive_reminder_sent' = any (v_values) then
    return;
  end if;

  v_values := array_append(v_values, 'admin_inactive_reminder_sent');

  execute format('alter table public.audit_log drop constraint %I', v_name);
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type in (%s))',
    (select string_agg(quote_literal(v), ', ') from unnest(v_values) as v)
  );
end
$$;

-- People an inactive reminder would reach right now for p_inactive_days.
create or replace function internal.inactive_reminder_recipients(p_inactive_days integer)
returns table (user_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  with cutoff as (
    select now() - make_interval(days => p_inactive_days) as at
  )
  select p.id
  from public.profiles p
  join auth.users u on u.id = p.id
  cross join cutoff c
  where p.platform_role = 'user'
    and p.created_at <= c.at
    and coalesce(u.last_sign_in_at, '-infinity') <= c.at
    and not exists (
      select 1 from auth.sessions s
      where s.user_id = p.id and greatest(s.created_at, s.updated_at) > c.at
    )
    and not exists (select 1 from public.drops d where d.author_id = p.id and d.created_at > c.at)
    and not exists (select 1 from public.drop_likes x where x.user_id = p.id and x.created_at > c.at)
    and not exists (select 1 from public.drop_comments x where x.author_id = p.id and x.created_at > c.at)
    and not exists (select 1 from public.redrops x where x.redropper_id = p.id and x.created_at > c.at)
    and not exists (select 1 from public.club_post_likes x where x.user_id = p.id and x.created_at > c.at)
    and not exists (select 1 from public.club_post_comments x where x.author_id = p.id and x.created_at > c.at)
    and not exists (select 1 from public.messages x where x.sender_id = p.id and x.created_at > c.at)
    and not exists (
      select 1 from internal.inactive_reminders r
      where r.user_id = p.id and r.last_sent_at > now() - interval '24 hours'
    )
    and not internal.is_posting_blocked(p.id)
    and internal.notification_enabled(p.id, 'system');
$$;

revoke all on function internal.inactive_reminder_recipients(integer) from public, anon, authenticated;

-- How many people a send would reach (the Admin sees this before sending).
create or replace function public.admin_count_inactive_users(p_inactive_days integer)
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can send inactive reminders';
  end if;
  if p_inactive_days is null or p_inactive_days not in (1, 3, 7) then
    raise exception 'Invalid inactive days: %', p_inactive_days;
  end if;
  return (select count(*)::integer from internal.inactive_reminder_recipients(p_inactive_days));
end;
$$;

-- Sends the reminder as a 'system' notification (in-app + Push).
create or replace function public.admin_send_inactive_reminder(
  p_inactive_days integer,
  p_message text
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_message text := trim(coalesce(p_message, ''));
  v_count integer;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can send inactive reminders';
  end if;
  if p_inactive_days is null or p_inactive_days not in (1, 3, 7) then
    raise exception 'Invalid inactive days: %', p_inactive_days;
  end if;
  if length(v_message) = 0 or length(v_message) > 500 then
    raise exception 'Reminder message must be 1-500 characters';
  end if;

  -- One send at a time, so two Admins cannot remind the same people twice.
  perform pg_advisory_xact_lock(hashtext('admin_send_inactive_reminder'));

  with recipients as (
    select user_id from internal.inactive_reminder_recipients(p_inactive_days)
  ),
  remembered as (
    insert into internal.inactive_reminders (user_id, last_sent_at)
    select user_id, now() from recipients
    on conflict (user_id) do update set last_sent_at = excluded.last_sent_at
    returning user_id
  ),
  inserted as (
    insert into public.notifications (recipient_id, actor_id, type, reason)
    select user_id, null, 'system', v_message from remembered
    returning 1
  )
  select count(*) into v_count from inserted;

  perform internal.log_audit_event(
    v_admin,
    'admin_inactive_reminder_sent',
    null,
    jsonb_build_object(
      'inactive_days', p_inactive_days,
      'message', v_message,
      'recipient_count', v_count
    )
  );

  return v_count;
end;
$$;

revoke all on function public.admin_count_inactive_users(integer) from public, anon;
revoke all on function public.admin_send_inactive_reminder(integer, text) from public, anon;
grant execute on function public.admin_count_inactive_users(integer) to authenticated;
grant execute on function public.admin_send_inactive_reminder(integer, text) to authenticated;
