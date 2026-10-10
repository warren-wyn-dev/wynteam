-- WYN-219 Phase 2, step 2 (Social): moderation, reports, appeals and announcements -> social:view|edit
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10). Each
-- definition is copied verbatim; only its role-check expression changes:
--   staff check (admin or moderator) -> view (or edit where noted)
--   admin check                      -> edit
-- Data uses of profiles.platform_role (e.g. announcement audiences, the user
-- directory's role column) are unchanged.
--
-- Moderator actions (remove/restore content, user sanctions, appeal decisions) map to
-- social:edit (Founder Q2: user sanctions are Social). Moderators were seeded social:edit,
-- which also lets them send announcements (previously admin-only).
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- everyone else needs the matching permission from the Team Permissions page.
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_remaining_systems_test.sh
-- ROLLBACK: supabase/rollbacks/20261010170200_wyn219_step2_social_permissions_rollback.sql

-- public.admin_search_drops(p_query text): staff -> social:view
CREATE OR REPLACE FUNCTION public.admin_search_drops(p_query text)
 RETURNS TABLE(id uuid, image_url text, caption text, author_id uuid, author_username text, deleted_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not internal.has_admin_permission('social', 'view') then
    raise exception 'Not authorized';
  end if;

  return query
  select d.id, d.image_url, d.caption, d.author_id, p.username, d.deleted_at, d.created_at
  from public.drops d
  join public.profiles p on p.id = d.author_id
  where d.caption ilike '%' || p_query || '%' or p.username ilike '%' || p_query || '%'
  order by d.created_at desc
  limit 30;
end;
$function$;

-- public.admin_get_drop(p_drop_id uuid): staff -> social:view
CREATE OR REPLACE FUNCTION public.admin_get_drop(p_drop_id uuid)
 RETURNS TABLE(id uuid, image_url text, caption text, author_id uuid, author_username text, deleted_at timestamp with time zone, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not internal.has_admin_permission('social', 'view') then
    raise exception 'Not authorized';
  end if;

  return query
  select d.id, d.image_url, d.caption, d.author_id, p.username, d.deleted_at, d.created_at
  from public.drops d
  join public.profiles p on p.id = d.author_id
  where d.id = p_drop_id;
end;
$function$;

-- public.admin_feed_algorithm_dashboard(p_hours integer): staff -> social:view
CREATE OR REPLACE FUNCTION public.admin_feed_algorithm_dashboard(p_hours integer DEFAULT 24)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare v_result jsonb;
begin
 if not internal.has_admin_permission('social', 'view') then raise exception 'Not authorized';end if;
 if p_hours not in(1,24,168,720) then raise exception 'Invalid time window';end if;
 with scoped as(select * from public.feed_impressions where created_at>=now()-make_interval(hours=>p_hours)),
 source_metrics as(select feed_source,count(*) impressions,count(distinct user_id) unique_viewers,count(distinct content_id) unique_content,count(distinct topic) unique_topics,avg(rank_position) avg_rank,
   percentile_cont(.5) within group(order by latency_ms) p50_latency_ms,percentile_cont(.95) within group(order by latency_ms) p95_latency_ms,percentile_cont(.99) within group(order by latency_ms) p99_latency_ms,
   count(*) filter(where fallback_used) fallback_count,count(*) filter(where candidate_origin<>'direct') similarity_impressions from scoped group by feed_source),
 maturity as(select maturity_state,count(*) impressions,count(distinct user_id) unique_viewers from scoped group by maturity_state),
 trend_diag as(select count(*) candidate_count,avg(content_age_hours) avg_age_hours,avg(unique_engagers_1h) avg_unique_engagers,max(extract(epoch from(now()-updated_at))) max_staleness_seconds from public.trending_scores),
 top_diag as(select count(*) candidate_count,count(distinct creator_id) creators,max(extract(epoch from(now()-updated_at))) max_staleness_seconds from public.top100_scores),
 overlap as(select count(*) overlap_top20 from(select drop_id from public.trending_scores order by trend_score desc limit 20)t join(select drop_id from public.top100_scores order by current_rank limit 20)q using(drop_id))
 select jsonb_build_object('algorithmVersion',1,'windowHours',p_hours,'sources',coalesce((select jsonb_agg(to_jsonb(source_metrics)) from source_metrics),'[]'),'maturity',coalesce((select jsonb_agg(to_jsonb(maturity)) from maturity),'[]'),'trending',(select to_jsonb(trend_diag) from trend_diag),'top100',(select to_jsonb(top_diag) from top_diag),'trendingTop100',(select to_jsonb(overlap) from overlap),'experiments',coalesce((select jsonb_agg(to_jsonb(m)) from internal.feed_experiment_variant_metrics m),'[]')) into v_result;
 return v_result;end $function$;

-- public.get_message_for_moderation(p_message_id uuid): notuser -> social:view
CREATE OR REPLACE FUNCTION public.get_message_for_moderation(p_message_id uuid)
 RETURNS TABLE(text text, image_url text, shared_content_type text, shared_content_id uuid, deleted_at timestamp with time zone, sender_username text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.text, m.image_url, m.shared_content_type, m.shared_content_id, m.deleted_at, p.username
  from public.messages m
  join public.profiles p on p.id = m.sender_id
  where m.id = p_message_id
    and (internal.has_admin_permission('social', 'view'));
$function$;

-- public.admin_remove_drop(p_drop_id uuid, p_reason text): staff -> social:edit
CREATE OR REPLACE FUNCTION public.admin_remove_drop(p_drop_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_drop record;
  v_action_id uuid;
begin
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.deleted_at is not null then
    raise exception 'Drop is already deleted';
  end if;

  update public.drops set deleted_at = now() where id = p_drop_id;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason,
    target_content_type, target_content_id, reviewer_id
  ) values (
    null, v_drop.author_id, 'remove_content', v_trimmed_reason,
    'drop', p_drop_id, v_reviewer
  )
  returning id into v_action_id;

  insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
  values (v_drop.author_id, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, 'remove_content');

  perform internal.log_audit_event(
    v_reviewer,
    'admin_content_removed',
    v_drop.author_id,
    jsonb_build_object('target_content_type', 'drop', 'target_content_id', p_drop_id, 'reason', v_trimmed_reason)
  );
end;
$function$;

-- public.admin_restore_drop(p_drop_id uuid, p_reason text): staff -> social:edit
CREATE OR REPLACE FUNCTION public.admin_restore_drop(p_drop_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_drop record;
begin
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_drop from public.drops where id = p_drop_id for update;
  if v_drop is null then
    raise exception 'Drop not found';
  end if;
  if v_drop.deleted_at is null then
    raise exception 'Drop is not deleted';
  end if;

  update public.drops set deleted_at = null where id = p_drop_id;

  update public.moderation_actions
  set overturned_at = now()
  where target_content_type = 'drop'
    and target_content_id = p_drop_id
    and action_type = 'remove_content'
    and overturned_at is null;

  perform internal.log_audit_event(
    v_reviewer,
    'admin_content_restored',
    v_drop.author_id,
    jsonb_build_object('target_content_type', 'drop', 'target_content_id', p_drop_id, 'reason', v_trimmed_reason)
  );
end;
$function$;

-- public.admin_apply_user_action(p_target_user_id uuid, p_action_type text, p_reason text, p_duration_days integer): staff -> social:edit
CREATE OR REPLACE FUNCTION public.admin_apply_user_action(p_target_user_id uuid, p_action_type text, p_reason text, p_duration_days integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_expires_at timestamptz;
  v_action_id uuid;
begin
  -- coalesce() is load-bearing here -- see
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md
  -- for exactly why a bare `not in (...)` against a possibly-NULL role
  -- silently lets an unverified caller through.
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('warning', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    raise exception 'Target user not found';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for %', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at, reviewer_id
  ) values (
    null,
    p_target_user_id,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer
  )
  returning id into v_action_id;

  -- Only Warn gets an explicit push notification here, mirroring
  -- apply_moderation_action() exactly -- Restrict/Suspend/Ban are
  -- surfaced to the target through get_my_moderation_status() the next
  -- time AuthGate/RestrictionBanner checks, same as the report-driven
  -- path already relies on.
  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (p_target_user_id, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  end if;

  perform internal.log_audit_event(
    v_reviewer,
    'admin_user_action_applied',
    p_target_user_id,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$function$;

-- public.admin_unban_user(p_target_user_id uuid, p_reason text): staff -> social:edit
CREATE OR REPLACE FUNCTION public.admin_unban_user(p_target_user_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
begin
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  update public.moderation_actions
  set overturned_at = now()
  where target_user_id = p_target_user_id
    and overturned_at is null
    and (
      action_type = 'ban'
      or (action_type in ('restrict', 'suspend') and expires_at > now())
    );

  perform internal.log_audit_event(
    v_reviewer,
    'admin_user_unbanned',
    p_target_user_id,
    jsonb_build_object('reason', v_trimmed_reason)
  );
end;
$function$;

-- public.admin_send_announcement(p_category text, p_message text, p_audience text): admin -> social:edit
CREATE OR REPLACE FUNCTION public.admin_send_announcement(p_category text, p_message text, p_audience text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_admin uuid := auth.uid();
  v_trimmed_message text := trim(coalesce(p_message, ''));
  v_recipient_count integer;
begin
  -- coalesce() is load-bearing -- see
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md.
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Only admins can send announcements';
  end if;

  if p_category not in ('system_update', 'policy_update', 'maintenance', 'important') then
    raise exception 'Invalid category: %', p_category;
  end if;

  if length(v_trimmed_message) = 0 then
    raise exception 'Announcement message must not be blank';
  end if;

  if p_audience not in ('all', 'users', 'staff') then
    raise exception 'Invalid audience: %', p_audience;
  end if;

  with recipients as (
    select id from public.profiles
    where
      case p_audience
        when 'users' then platform_role = 'user'
        when 'staff' then platform_role in ('moderator', 'admin')
        else true
      end
      and internal.notification_enabled(id, 'system')
  ),
  inserted as (
    insert into public.notifications (recipient_id, actor_id, type, reason)
    select id, null, 'system', v_trimmed_message from recipients
    returning 1
  )
  select count(*) into v_recipient_count from inserted;

  perform internal.log_audit_event(
    v_admin,
    'admin_announcement_sent',
    null,
    jsonb_build_object(
      'category', p_category,
      'message', v_trimmed_message,
      'audience', p_audience,
      'recipient_count', v_recipient_count
    )
  );

  return v_recipient_count;
end;
$function$;

-- public.send_system_notification(p_recipient_id uuid, p_message text): admin -> social:edit
CREATE OR REPLACE FUNCTION public.send_system_notification(p_recipient_id uuid, p_message text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- coalesce() is load-bearing, not decoration -- current_platform_role()
  -- returns NULL for a caller with no `profiles` row at all, and
  -- `NULL <> 'admin'` evaluates to NULL, which PL/pgSQL's `if` treats
  -- as false (branch skipped, exception never raised) -- the same
  -- NULL-role-bypass class WYN-050 found and fixed in
  -- admin_dashboard_metrics(), found here too during WYN-051's QA. See
  -- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md
  -- and .wyn/tasks/bugs/WYN-043-send-system-notification-null-role-bypass.md.
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Only admins can send system notifications';
  end if;

  if p_message is null or length(trim(p_message)) = 0 then
    raise exception 'System notification message must not be blank';
  end if;

  if internal.notification_enabled(p_recipient_id, 'system') then
    insert into public.notifications (recipient_id, actor_id, type, reason)
    values (p_recipient_id, null, 'system', p_message);

    -- WYN-048: audit trail. actor_id is the real admin caller --
    -- audit_log has no client-facing SELECT policy at all (unlike
    -- notifications.actor_id, which this function already correctly
    -- nulls out above so the recipient never learns who sent it), so
    -- recording the true sender identity here creates no leak. Placed
    -- inside this `if` branch (not unconditionally at the end of the
    -- function) on purpose -- the event_type is 'system_notification_
    -- sent', and if the recipient has this category turned off nothing
    -- was actually sent, so nothing should be logged as sent. detail
    -- stores the message plainly, same as the notifications row above
    -- -- not a new exposure, since the recipient already sees this
    -- exact text via the notification itself.
    perform internal.log_audit_event(
      auth.uid(),
      'system_notification_sent',
      p_recipient_id,
      jsonb_build_object('message', p_message)
    );
  end if;
end;
$function$;

-- public.apply_moderation_action(p_report_id uuid, p_action_type text, p_reason text, p_duration_days integer): reviewer -> social:edit
CREATE OR REPLACE FUNCTION public.apply_moderation_action(p_report_id uuid, p_action_type text, p_reason text, p_duration_days integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_report record;
  v_target_user uuid;
  v_target_content_type text;
  v_target_content_id uuid;
  v_expires_at timestamptz;
  v_trimmed_reason text := trim(coalesce(p_reason, ''));
  v_action_id uuid;
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  if p_action_type not in ('no_action', 'warning', 'remove_content', 'restrict', 'suspend', 'ban') then
    raise exception 'Invalid action_type: %', p_action_type;
  end if;

  if length(v_trimmed_reason) = 0 then
    raise exception 'Reason is required';
  end if;

  select * into v_report from public.reports where id = p_report_id for update;
  if v_report is null then
    raise exception 'Report not found';
  end if;
  if v_report.status not in ('pending', 'reviewing') then
    raise exception 'Report has already been actioned';
  end if;

  if v_report.target_type = 'user' then
    v_target_user := v_report.target_id;
  elsif v_report.target_type = 'drop' then
    select author_id into v_target_user from public.drops where id = v_report.target_id;
  elsif v_report.target_type = 'drop_comment' then
    select author_id into v_target_user from public.drop_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club' then
    select owner_id into v_target_user from public.clubs where id = v_report.target_id;
  elsif v_report.target_type = 'club_post' then
    select author_id into v_target_user from public.club_posts where id = v_report.target_id;
  elsif v_report.target_type = 'club_post_comment' then
    select author_id into v_target_user from public.club_post_comments where id = v_report.target_id;
  elsif v_report.target_type = 'club_channel_message' then
    select author_id into v_target_user from public.club_channel_messages where id = v_report.target_id;
  else
    raise exception 'Unsupported report target type: %', v_report.target_type;
  end if;

  if p_action_type = 'remove_content' and v_report.target_type in ('user', 'club') then
    raise exception 'Remove Content is not supported for target type %', v_report.target_type;
  end if;

  if v_target_user is null and p_action_type <> 'no_action' then
    raise exception 'Target no longer exists -- use No Action to close this report';
  end if;

  if p_action_type in ('restrict', 'suspend') then
    if p_duration_days is null or p_duration_days not in (1, 3, 7) then
      raise exception 'duration_days must be 1, 3, or 7 for % ', p_action_type;
    end if;
    v_expires_at := now() + (p_duration_days || ' days')::interval;
  else
    v_expires_at := null;
  end if;

  if p_action_type = 'remove_content' and v_report.target_type = 'drop' then
    v_target_content_type := 'drop';
    v_target_content_id := v_report.target_id;
  end if;

  insert into public.moderation_actions (
    report_id, target_user_id, action_type, reason, duration_days, expires_at,
    reviewer_id, target_content_type, target_content_id
  ) values (
    p_report_id,
    v_target_user,
    p_action_type,
    v_trimmed_reason,
    case when p_action_type in ('restrict', 'suspend') then p_duration_days else null end,
    v_expires_at,
    v_reviewer,
    v_target_content_type,
    v_target_content_id
  )
  returning id into v_action_id;

  update public.reports
  set status = case when p_action_type = 'no_action' then 'dismissed' else 'actioned' end
  where id = p_report_id;

  if p_action_type = 'warning' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_warning', v_trimmed_reason, v_action_id, p_action_type);
  elsif p_action_type = 'remove_content' then
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_target_user, null, 'moderation_content_removed', v_trimmed_reason, v_action_id, p_action_type);

    if v_report.target_type = 'drop' then
      update public.drops set deleted_at = now() where id = v_report.target_id and deleted_at is null;
    elsif v_report.target_type = 'drop_comment' then
      delete from public.drop_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_post' then
      delete from public.club_posts where id = v_report.target_id;
    elsif v_report.target_type = 'club_post_comment' then
      delete from public.club_post_comments where id = v_report.target_id;
    elsif v_report.target_type = 'club_channel_message' then
      delete from public.club_channel_messages where id = v_report.target_id;
    end if;
  end if;

  perform internal.log_audit_event(
    v_reviewer,
    'moderation_action_applied',
    v_target_user,
    jsonb_build_object('action_type', p_action_type, 'reason', v_trimmed_reason)
  );
end;
$function$;

-- public.decide_appeal(p_appeal_id uuid, p_approve boolean, p_decision_reason text): reviewer -> social:edit
CREATE OR REPLACE FUNCTION public.decide_appeal(p_appeal_id uuid, p_approve boolean, p_decision_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_reviewer uuid := auth.uid();
  v_reviewer_role text;
  v_appeal record;
  v_action record;
  v_trimmed_reason text := trim(coalesce(p_decision_reason, ''));
begin
  if v_reviewer is null then
    raise exception 'Not authenticated';
  end if;

  select platform_role into v_reviewer_role from public.profiles where id = v_reviewer;
  if not internal.has_admin_permission('social', 'edit') then
    raise exception 'Not authorized';
  end if;

  select * into v_appeal from public.appeals where id = p_appeal_id for update;
  if v_appeal is null then
    raise exception 'Appeal not found';
  end if;
  if v_appeal.status <> 'pending' then
    raise exception 'This appeal has already been decided';
  end if;

  select * into v_action from public.moderation_actions where id = v_appeal.moderation_action_id;
  if v_action is null then
    raise exception 'Moderation action not found';
  end if;

  if v_reviewer = v_action.target_user_id then
    raise exception 'You cannot decide an appeal for a moderation action taken against your own account';
  end if;

  if not p_approve and length(v_trimmed_reason) = 0 then
    raise exception 'A reason is required to reject an appeal';
  end if;

  update public.appeals
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewer_id = v_reviewer,
      decision_reason = case when p_approve then null else v_trimmed_reason end,
      decided_at = now()
  where id = p_appeal_id;

  if p_approve then
    update public.moderation_actions
    set overturned_at = now()
    where id = v_action.id;

    -- actor_id deliberately NULL, exactly like apply_moderation_action()
    -- above -- the real reviewer identity lives only in
    -- appeals.reviewer_id, a column the target has no SELECT access to.
    -- This is the third time this project has had to protect a
    -- moderation-adjacent identity this way (WYN-027, WYN-029); it is
    -- done correctly from the very first insert here, not patched in
    -- afterward.
    insert into public.notifications (recipient_id, actor_id, type, moderation_action_id, moderation_action_type)
    values (v_action.target_user_id, null, 'appeal_approved', v_action.id, v_action.action_type);
  else
    -- Reuses notifications.reason (WYN-029's column) for the rejection
    -- message -- see the design doc's scope decision #6.
    insert into public.notifications (recipient_id, actor_id, type, reason, moderation_action_id, moderation_action_type)
    values (v_action.target_user_id, null, 'appeal_rejected', v_trimmed_reason, v_action.id, v_action.action_type);
  end if;

  -- WYN-048: audit trail, recorded after the decision has already
  -- committed above. actor_id is the real reviewer identity (same
  -- reasoning as apply_moderation_action()'s own WYN-048 comment --
  -- audit_log has no client-facing SELECT policy, so this creates no
  -- reviewer-identity leak the way notifications.actor_id would).
  -- target = the appellant (v_appeal.appellant_id), not the reviewer.
  perform internal.log_audit_event(
    v_reviewer,
    'appeal_decided',
    v_appeal.appellant_id,
    jsonb_build_object('decision', case when p_approve then 'approved' else 'rejected' end)
  );
end;
$function$;

-- view public.moderation_queue: notuser -> social:view
create or replace view public.moderation_queue as
 SELECT id,
    target_type,
    target_id,
    category,
    detail,
    status,
    created_at
   FROM reports
  WHERE (internal.has_admin_permission('social', 'view'));

-- view public.admin_user_moderation_history: notuser -> social:view
create or replace view public.admin_user_moderation_history as
 SELECT ma.id,
    ma.target_user_id,
    ma.action_type,
    ma.reason,
    ma.duration_days,
    ma.expires_at,
    ma.overturned_at,
    ma.created_at,
    p.username AS reviewer_username,
    ma.target_content_type,
    ma.target_content_id
   FROM (moderation_actions ma
     JOIN profiles p ON ((p.id = ma.reviewer_id)))
  WHERE (internal.has_admin_permission('social', 'view'));

-- policy Moderators can view all appeals on public.appeals: notuser -> social:view
drop policy if exists "Moderators can view all appeals" on public.appeals;
create policy "Moderators can view all appeals"
  on public.appeals
  for select
  to authenticated
  using ((internal.has_admin_permission('social', 'view')));

-- policy Moderators can view moderation action history on public.moderation_actions: notuser -> social:view
drop policy if exists "Moderators can view moderation action history" on public.moderation_actions;
create policy "Moderators can view moderation action history"
  on public.moderation_actions
  for select
  to authenticated
  using ((internal.has_admin_permission('social', 'view')));

-- policy Appellants and moderators can view appeal evidence on storage.objects: notuser -> social:view
drop policy if exists "Appellants and moderators can view appeal evidence" on storage.objects;
create policy "Appellants and moderators can view appeal evidence"
  on storage.objects
  for select
  to authenticated
  using (((bucket_id = 'appeal-evidence'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (internal.has_admin_permission('social', 'view')))));
