-- Reverse WYNOS Admin QA guardrails migration only if directed during incident response.
-- Captured from Production on 2026-10-09 BEFORE applying the forward migration.
-- Does not modify checkout, orders, Merchant data, coupons, campaigns or Cron schedule.
-- Review impact before rollback: restores the older behavior allowing Admin to
-- enqueue marketing even with a paused scheduler.
begin;
CREATE OR REPLACE FUNCTION public.admin_food_promo_schedule(p_title text, p_body text, p_coupon_id uuid DEFAULT NULL::uuid, p_audience text DEFAULT 'all'::text, p_scheduled_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '')<>'admin' then
    raise exception 'Only admins can send Food promotions';
  end if;
  if p_coupon_id is not null and not exists(
    select 1 from public.food_coupon_codes where id=p_coupon_id and is_active
  ) then raise exception 'coupon_not_active'; end if;
  if p_audience not in ('all','returning') then raise exception 'invalid_audience'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 3 and 90
    or char_length(trim(coalesce(p_body,''))) not between 5 and 260 then
    raise exception 'invalid_promotion_copy';
  end if;
  insert into public.food_promo_broadcasts(title,body,coupon_id,audience,scheduled_at,created_by)
  values(trim(p_title),trim(p_body),p_coupon_id,p_audience,coalesce(p_scheduled_at,now()),auth.uid())
  returning id into v_id;
  return v_id;
end;
$function$;

revoke all on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) from public, anon;
grant execute on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) to authenticated;

create or replace view public.admin_audit_log as
SELECT id,
    actor_id,
    actor_username_snapshot,
    event_type,
    target_id,
    detail,
    created_at
   FROM audit_log
  WHERE (internal.current_platform_role() <> 'user'::text);

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
  WHERE (internal.current_platform_role() <> 'user'::text);

create or replace view public.moderation_queue as
SELECT id,
    target_type,
    target_id,
    category,
    detail,
    status,
    created_at
   FROM reports
  WHERE (internal.current_platform_role() <> 'user'::text);

drop function if exists public.admin_food_promo_scheduler_status();
commit;
