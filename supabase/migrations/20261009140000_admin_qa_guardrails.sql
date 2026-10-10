-- WYNOS Admin QA hardening only.
-- Does not change Food/Merchant checkout, orders, merchant permissions,
-- push delivery workers, campaign terms, balances or existing records.
-- Do not apply to production without isolated staging/role regression QA.

-- The marketing cron is deliberately disabled until launch approval.
-- Admin must read its real status rather than telling operators queued
-- messages are being sent when no scheduler is running.
create or replace function public.admin_food_promo_scheduler_status()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $fn$
declare
  v_present boolean;
  v_active boolean;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Admin access required';
  end if;
  select exists(
    select 1 from cron.job where jobname = 'wynos-food-promotions-5min'
  ), exists(
    select 1 from cron.job where jobname = 'wynos-food-promotions-5min' and active
  ) into v_present, v_active;
  return jsonb_build_object('configured', v_present, 'active', v_active);
end;
$fn$;
revoke all on function public.admin_food_promo_scheduler_status() from public, anon;
grant execute on function public.admin_food_promo_scheduler_status() to authenticated;

-- Guard the original RPC, not just the UI, so a stale browser/session
-- cannot insert undeliverable broadcasts when cron is paused.
-- Preserve all original parameters, role checks and input validations.
create or replace function public.admin_food_promo_schedule(
  p_title text, p_body text, p_coupon_id uuid default null,
  p_audience text default 'all', p_scheduled_at timestamptz default null
)
returns uuid
language plpgsql security definer set search_path = ''
as $fn$
declare
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can send Food promotions';
  end if;
  if not exists(
    select 1 from cron.job
    where jobname = 'wynos-food-promotions-5min' and active
  ) then
    raise exception 'food_promo_scheduler_disabled';
  end if;
  if p_coupon_id is not null and not exists(
    select 1 from public.food_coupon_codes
    where id = p_coupon_id and is_active
  ) then
    raise exception 'coupon_not_active';
  end if;
  if p_audience not in ('all', 'returning') then
    raise exception 'invalid_audience';
  end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 90
     or char_length(trim(coalesce(p_body, ''))) not between 5 and 260 then
    raise exception 'invalid_promotion_copy';
  end if;
  insert into public.food_promo_broadcasts (
    title, body, coupon_id, audience, scheduled_at, created_by
  ) values (
    trim(p_title), trim(p_body), p_coupon_id, p_audience,
    coalesce(p_scheduled_at, now()), auth.uid()
  ) returning id into v_id;
  return v_id;
end;
$fn$;
revoke all on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) from public, anon;
grant execute on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) to authenticated;

-- Whitelist staff roles explicitly. Before this hardening these views
-- matched any non-'user' role, including roles introduced in the future.
-- Preserve the existing SECURITY DEFINER view behavior: switching to
-- SECURITY INVOKER here would break audited moderation reads because the
-- underlying tables have different RLS grants.
create or replace view public.moderation_queue as
select id, target_type, target_id, category, detail, status, created_at
from public.reports
where coalesce(internal.current_platform_role(), '') in ('admin', 'moderator');

create or replace view public.admin_user_moderation_history as
select
  ma.id, ma.target_user_id, ma.action_type, ma.reason,
  ma.duration_days, ma.expires_at, ma.overturned_at, ma.created_at,
  p.username as reviewer_username, ma.target_content_type, ma.target_content_id
from public.moderation_actions ma
join public.profiles p on p.id = ma.reviewer_id
where coalesce(internal.current_platform_role(), '') in ('admin', 'moderator');

create or replace view public.admin_audit_log as
select id, actor_id, actor_username_snapshot, event_type,
       target_id, detail, created_at
from public.audit_log
where coalesce(internal.current_platform_role(), '') in ('admin', 'moderator');
