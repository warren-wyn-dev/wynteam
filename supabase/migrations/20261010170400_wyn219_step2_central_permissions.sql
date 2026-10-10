-- WYN-219 Phase 2, step 2 (central): dashboards -> any permission; audit log -> super admin only
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10). Each
-- definition is copied verbatim; only its role-check expression changes:
--   staff check (admin or moderator) -> view (or edit where noted)
--   admin check                      -> edit
-- Data uses of profiles.platform_role (e.g. announcement audiences, the user
-- directory's role column) are unchanged.
--
-- Adds internal.has_any_admin_permission(). public.admin_activity_trend exists only in
-- production (no repository file before this one); its definition comes from the dump.
-- Founder Q3: the audit log is for the super admin only.
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- everyone else needs the matching permission from the Team Permissions page.
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_remaining_systems_test.sh
-- ROLLBACK: supabase/rollbacks/20261010170400_wyn219_step2_central_permissions_rollback.sql

-- True for the super admin or anyone holding at least one per-system permission.
create or replace function internal.has_any_admin_permission()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select internal.is_super_admin()
      or exists (select 1 from public.admin_permissions ap where ap.user_id = (select auth.uid()));
$$;
revoke all on function internal.has_any_admin_permission() from public, anon;
grant execute on function internal.has_any_admin_permission() to authenticated;

-- public.admin_dashboard_metrics(): staff -> *any*:
CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
 RETURNS TABLE(new_users_today bigint, dau bigint, wau bigint, mau bigint, drops_today bigint, views_today bigint, clubs_total bigint, clubs_new_today bigint, likes_today bigint, comments_today bigint, redrops_today bigint, messages_today bigint, reports_total bigint, reports_pending bigint, appeals_pending bigint, active_conversations bigint, signup_started_24h bigint, signup_completed_24h bigint, signup_conversion_pct numeric, activation_pct_24h numeric, activation_count_24h bigint, retention_d1_pct numeric, retention_d7_pct numeric, top_sources jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_today_start timestamptz := date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
begin
  if not internal.has_any_admin_permission() then
    raise exception 'Not permitted to view admin dashboard metrics';
  end if;

  return query
  with actions as (
    select user_id as actor_id, created_at from public.drop_likes
    union all
    select user_id, created_at from public.pop_likes
    union all
    select user_id, created_at from public.club_post_likes
    union all
    select author_id, created_at from public.drop_comments
    union all
    select author_id, created_at from public.pop_comments
    union all
    select author_id, created_at from public.club_post_comments
    union all
    select redropper_id, created_at from public.redrops
    union all
    select sender_id, created_at from public.messages where deleted_at is null
    union all
    select author_id, created_at from public.drops
  ),
  signup_started_rows as (
    select user_id, created_at, source
    from public.analytics_events
    where event_type = 'signup_started'
  ),
  signup_completed_rows as (
    select user_id, created_at
    from public.analytics_events
    where event_type = 'signup_completed'
  ),
  core_action_rows as (
    select user_id, min(created_at) as first_at
    from public.analytics_events
    where event_type = 'first_core_action'
    group by user_id
  ),
  session_rows as (
    select user_id, created_at
    from public.analytics_events
    where event_type = 'session_start'
  ),
  conversion_calc as (
    select
      count(*) as started_count,
      count(*) filter (
        where exists (
          select 1 from signup_completed_rows sc where sc.user_id = s.user_id
        )
      ) as completed_count
    from signup_started_rows s
    where s.created_at >= v_today_start
  ),
  activation_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from core_action_rows ca
          where ca.user_id = c.user_id
            and ca.first_at <= c.created_at + interval '1 day'
        )
      ) as activated_count
    from signup_completed_rows c
    where c.created_at >= v_today_start
  ),
  d1_cohort as (
    select * from signup_completed_rows
    where created_at >= now() - interval '3 days' and created_at < now() - interval '2 days'
  ),
  d1_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from session_rows sr
          where sr.user_id = d.user_id
            and sr.created_at >= d.created_at + interval '1 day'
            and sr.created_at < d.created_at + interval '2 days'
        )
      ) as retained_count
    from d1_cohort d
  ),
  d7_cohort as (
    select * from signup_completed_rows
    where created_at >= now() - interval '9 days' and created_at < now() - interval '8 days'
  ),
  d7_calc as (
    select
      count(*) as cohort_count,
      count(*) filter (
        where exists (
          select 1 from session_rows sr
          where sr.user_id = d.user_id
            and sr.created_at >= d.created_at + interval '7 days'
            and sr.created_at < d.created_at + interval '8 days'
        )
      ) as retained_count
    from d7_cohort d
  ),
  top_sources_calc as (
    select coalesce(source, 'ไม่ระบุที่มา') as source, count(*) as cnt
    from signup_started_rows
    where created_at >= now() - interval '7 days'
    group by coalesce(source, 'ไม่ระบุที่มา')
    order by count(*) desc
    limit 5
  )
  select
    (select count(*) from public.profiles where created_at >= v_today_start),
    (select count(distinct actor_id) from actions where created_at >= v_today_start),
    (select count(distinct actor_id) from actions where created_at >= v_today_start - interval '6 days'),
    (select count(distinct actor_id) from actions where created_at >= v_today_start - interval '29 days'),
    (select count(*) from public.drops where created_at >= v_today_start),
    (select count(*) from public.drop_views where created_at >= v_today_start),
    (select count(*) from public.clubs),
    (select count(*) from public.clubs where created_at >= v_today_start),
    (select count(*) from public.drop_likes where created_at >= v_today_start)
      + (select count(*) from public.pop_likes where created_at >= v_today_start)
      + (select count(*) from public.club_post_likes where created_at >= v_today_start),
    (select count(*) from public.drop_comments where created_at >= v_today_start)
      + (select count(*) from public.pop_comments where created_at >= v_today_start)
      + (select count(*) from public.club_post_comments where created_at >= v_today_start),
    (select count(*) from public.redrops where created_at >= v_today_start),
    (select count(*) from public.messages where deleted_at is null and created_at >= v_today_start),
    (select count(*) from public.reports),
    (select count(*) from public.reports where status = 'pending'),
    (select count(*) from public.appeals where status = 'pending'),
    (select count(*) from public.conversations where status = 'active'),
    (select started_count from conversion_calc),
    (select cohort_count from activation_calc),
    case when (select started_count from conversion_calc) = 0 then null
      else round((select completed_count from conversion_calc)::numeric
        / (select started_count from conversion_calc) * 100, 1)
    end,
    case when (select cohort_count from activation_calc) = 0 then null
      else round((select activated_count from activation_calc)::numeric
        / (select cohort_count from activation_calc) * 100, 1)
    end,
    (select activated_count from activation_calc),
    case when (select cohort_count from d1_calc) = 0 then null
      else round((select retained_count from d1_calc)::numeric
        / (select cohort_count from d1_calc) * 100, 1)
    end,
    case when (select cohort_count from d7_calc) = 0 then null
      else round((select retained_count from d7_calc)::numeric
        / (select cohort_count from d7_calc) * 100, 1)
    end,
    (select coalesce(jsonb_agg(jsonb_build_object('source', source, 'count', cnt)), '[]'::jsonb)
      from top_sources_calc);
end;
$function$;

-- public.admin_dashboard_trends(): staff -> *any*:
CREATE OR REPLACE FUNCTION public.admin_dashboard_trends()
 RETURNS TABLE(new_users_yesterday bigint, drops_yesterday bigint, views_yesterday bigint, likes_yesterday bigint, comments_yesterday bigint, redrops_yesterday bigint, messages_yesterday bigint, new_users_yesterday_matched bigint, drops_yesterday_matched bigint, views_yesterday_matched bigint, likes_yesterday_matched bigint, comments_yesterday_matched bigint, redrops_yesterday_matched bigint, messages_yesterday_matched bigint, active_users_yesterday_matched bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_today_start timestamptz := date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
  v_yesterday_start timestamptz;
  v_yesterday_matched_end timestamptz;
begin
  if not internal.has_any_admin_permission() then
    raise exception 'Not permitted to view admin dashboard trends';
  end if;

  v_yesterday_start := v_today_start - interval '1 day';
  v_yesterday_matched_end := v_yesterday_start + (now() - v_today_start);

  return query
  with actions as (
    select user_id as actor_id, created_at from public.drop_likes
    union all
    select user_id, created_at from public.pop_likes
    union all
    select user_id, created_at from public.club_post_likes
    union all
    select author_id, created_at from public.drop_comments
    union all
    select author_id, created_at from public.pop_comments
    union all
    select author_id, created_at from public.club_post_comments
    union all
    select redropper_id, created_at from public.redrops
    union all
    select sender_id, created_at from public.messages where deleted_at is null
    union all
    select author_id, created_at from public.drops
  )
  select
    (select count(*) from public.profiles
      where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.drops
      where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.drop_views
      where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.drop_likes where created_at >= v_yesterday_start and created_at < v_today_start)
      + (select count(*) from public.pop_likes where created_at >= v_yesterday_start and created_at < v_today_start)
      + (select count(*) from public.club_post_likes where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.drop_comments where created_at >= v_yesterday_start and created_at < v_today_start)
      + (select count(*) from public.pop_comments where created_at >= v_yesterday_start and created_at < v_today_start)
      + (select count(*) from public.club_post_comments where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.redrops
      where created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.messages where deleted_at is null
      and created_at >= v_yesterday_start and created_at < v_today_start),
    (select count(*) from public.profiles
      where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.drops
      where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.drop_views
      where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.drop_likes where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end)
      + (select count(*) from public.pop_likes where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end)
      + (select count(*) from public.club_post_likes where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.drop_comments where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end)
      + (select count(*) from public.pop_comments where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end)
      + (select count(*) from public.club_post_comments where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.redrops
      where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(*) from public.messages where deleted_at is null
      and created_at >= v_yesterday_start and created_at < v_yesterday_matched_end),
    (select count(distinct actor_id) from actions
      where created_at >= v_yesterday_start and created_at < v_yesterday_matched_end);
end;
$function$;

-- public.admin_signup_counts(): staff -> *any*:
CREATE OR REPLACE FUNCTION public.admin_signup_counts()
 RETURNS TABLE(today bigint, this_week bigint, this_month bigint, this_year bigint, all_time bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not internal.has_any_admin_permission() then
    raise exception 'Not permitted to view signup counts';
  end if;

  return query
  select
    (select count(*) from public.profiles
      where created_at >= date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'),
    (select count(*) from public.profiles
      where created_at >= date_trunc('week', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'),
    (select count(*) from public.profiles
      where created_at >= date_trunc('month', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'),
    (select count(*) from public.profiles
      where created_at >= date_trunc('year', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'),
    (select count(*) from public.profiles);
end;
$function$;

-- public.admin_activity_trend(p_days integer): staff -> *any*:
CREATE OR REPLACE FUNCTION public.admin_activity_trend(p_days integer DEFAULT 30)
 RETURNS TABLE(day date, active_users bigint, engagement bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_today_start timestamptz := date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
begin
  if not internal.has_any_admin_permission() then
    raise exception 'Not permitted to view admin activity trend';
  end if;

  return query
  with actions as (
    select user_id as actor_id, created_at from public.drop_likes
    union all
    select user_id, created_at from public.pop_likes
    union all
    select user_id, created_at from public.club_post_likes
    union all
    select author_id, created_at from public.drop_comments
    union all
    select author_id, created_at from public.pop_comments
    union all
    select author_id, created_at from public.club_post_comments
    union all
    select redropper_id, created_at from public.redrops
    union all
    select sender_id, created_at from public.messages where deleted_at is null
    union all
    select author_id, created_at from public.drops
  ),
  engagement_events as (
    select created_at from public.drop_likes
    union all select created_at from public.pop_likes
    union all select created_at from public.club_post_likes
    union all select created_at from public.drop_comments
    union all select created_at from public.pop_comments
    union all select created_at from public.club_post_comments
    union all select created_at from public.redrops
  ),
  days as (
    select generate_series(
      v_today_start - (v_days - 1) * interval '1 day',
      v_today_start,
      interval '1 day'
    ) as day_start
  ),
  daily_active as (
    select d.day_start, count(distinct a.actor_id) as cnt
    from days d
    left join actions a
      on a.created_at >= d.day_start and a.created_at < d.day_start + interval '1 day'
    group by d.day_start
  ),
  daily_engagement as (
    select d.day_start, count(*) as cnt
    from days d
    left join engagement_events e
      on e.created_at >= d.day_start and e.created_at < d.day_start + interval '1 day'
    group by d.day_start
  )
  select (d.day_start at time zone 'Asia/Bangkok')::date, coalesce(da.cnt, 0), coalesce(de.cnt, 0)
  from days d
  left join daily_active da on da.day_start = d.day_start
  left join daily_engagement de on de.day_start = d.day_start
  order by d.day_start;
end;
$function$;

-- view public.admin_audit_log: notuser -> *super*:
create or replace view public.admin_audit_log as
 SELECT id,
    actor_id,
    actor_username_snapshot,
    event_type,
    target_id,
    detail,
    created_at
   FROM audit_log
  WHERE (internal.is_super_admin());
