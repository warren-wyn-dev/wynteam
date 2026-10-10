-- WYN-219 Phase 2, step 2 (Account): user directory and inactive reminders -> account:view|edit
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10). Each
-- definition is copied verbatim; only its role-check expression changes:
--   staff check (admin or moderator) -> view (or edit where noted)
--   admin check                      -> edit
-- Data uses of profiles.platform_role (e.g. announcement audiences, the user
-- directory's role column) are unchanged.
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- everyone else needs the matching permission from the Team Permissions page.
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_remaining_systems_test.sh
-- ROLLBACK: supabase/rollbacks/20261010170300_wyn219_step2_account_permissions_rollback.sql

-- public.admin_user_directory(p_sort text, p_role text, p_status text, p_limit integer): staff -> account:view
CREATE OR REPLACE FUNCTION public.admin_user_directory(p_sort text DEFAULT 'newest'::text, p_role text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 50)
 RETURNS TABLE(id uuid, username text, display_name text, platform_role text, created_at timestamp with time zone, last_active_at timestamp with time zone, activity_count bigint, current_status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not internal.has_admin_permission('account', 'view') then
    raise exception 'Not permitted to view the user directory';
  end if;

  return query
  with actions as (
    select dl.user_id as actor_id, dl.created_at as acted_at from public.drop_likes dl
    union all
    select pl.user_id, pl.created_at from public.pop_likes pl
    union all
    select cpl.user_id, cpl.created_at from public.club_post_likes cpl
    union all
    select dc.author_id, dc.created_at from public.drop_comments dc
    union all
    select pc.author_id, pc.created_at from public.pop_comments pc
    union all
    select cpc.author_id, cpc.created_at from public.club_post_comments cpc
    union all
    select r.redropper_id, r.created_at from public.redrops r
    union all
    select m.sender_id, m.created_at from public.messages m where m.deleted_at is null
    union all
    select d.author_id, d.created_at from public.drops d
  ),
  activity as (
    select act.actor_id, max(act.acted_at) as last_active, count(*) as total_actions
    from actions act
    group by act.actor_id
  ),
  active_action as (
    select distinct on (ma.target_user_id)
      ma.target_user_id,
      ma.action_type as resolved_action_type
    from public.moderation_actions ma
    where ma.overturned_at is null
      and (
        ma.action_type = 'ban'
        or (ma.action_type in ('restrict', 'suspend') and ma.expires_at > now())
      )
    order by ma.target_user_id, ma.created_at desc
  )
  select
    p.id,
    p.username,
    p.display_name,
    p.platform_role,
    p.created_at,
    act.last_active,
    coalesce(act.total_actions, 0),
    coalesce(aa.resolved_action_type, 'normal')
  from public.profiles p
  left join activity act on act.actor_id = p.id
  left join active_action aa on aa.target_user_id = p.id
  where (p_role is null or p.platform_role = p_role)
    and (p_status is null or coalesce(aa.resolved_action_type, 'normal') = p_status)
  order by
    case when p_sort = 'newest' then p.created_at end desc,
    case when p_sort = 'oldest' then p.created_at end asc,
    case when p_sort = 'most_active' then coalesce(act.total_actions, 0) end desc,
    case when p_sort = 'dormant' then act.last_active end asc nulls first
  limit p_limit;
end;
$function$;

-- public.admin_count_inactive_users(p_inactive_days integer): admin -> account:edit
CREATE OR REPLACE FUNCTION public.admin_count_inactive_users(p_inactive_days integer)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not internal.has_admin_permission('account', 'edit') then
    raise exception 'Only admins can send inactive reminders';
  end if;
  if p_inactive_days is null or p_inactive_days not in (1, 3, 7) then
    raise exception 'Invalid inactive days: %', p_inactive_days;
  end if;
  return (select count(*)::integer from internal.inactive_reminder_recipients(p_inactive_days));
end;
$function$;

-- public.admin_send_inactive_reminder(p_inactive_days integer, p_message text): admin -> account:edit
CREATE OR REPLACE FUNCTION public.admin_send_inactive_reminder(p_inactive_days integer, p_message text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin uuid := auth.uid();
  v_message text := trim(coalesce(p_message, ''));
  v_count integer;
begin
  if not internal.has_admin_permission('account', 'edit') then
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
$function$;
