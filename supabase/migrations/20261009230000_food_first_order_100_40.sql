-- WYNOS Food: Founder-approved first order food subtotal >= THB 100, THB 40 off.
-- Changes the previously deployed THB 120/20 preset, not the rest of the campaign engine.
-- Deliberately leaves the campaign inactive: Admin may activate only after the web
-- release is ready. Existing merchant opt-ins to THB 20 are invalidated, because
-- a merchant must affirmatively accept funding the new THB 40 discount.
-- The historical 20261009120000 migration remains immutable.

do $preflight$
begin
  if (select count(*) from public.food_platform_campaigns where first_order_only) <> 1 then
    raise exception 'Expected exactly one preexisting first-order campaign';
  end if;
  if exists (select 1 from public.food_platform_campaigns where first_order_only and is_active) then
    raise exception 'Disable first-order campaign before changing monetary terms';
  end if;
  if exists (
    select 1 from public.food_order_campaigns oc
    join public.food_platform_campaigns pc on pc.id=oc.platform_campaign_id
    where pc.first_order_only
  ) then
    raise exception 'First-order campaign has historical redemptions: manual financial review required';
  end if;
end;
$preflight$;

-- Preserve previous consent only as soft-deleted history; no store automatically
-- agrees to pay THB 40. New opt-in creates a new store-scoped campaign snapshot.
do $expire_old_opt_ins$
begin
  perform set_config('wyn.platform_campaign_write', 'on', true);
  update public.food_campaigns c
  set is_active=false, deleted_at=now(), updated_at=now()
  where c.platform_campaign_id in (
    select id from public.food_platform_campaigns where first_order_only
  ) and c.deleted_at is null;
  perform set_config('wyn.platform_campaign_write', '', true);
end;
$expire_old_opt_ins$;

alter table public.food_platform_campaigns
  drop constraint food_platform_first_order_fixed_terms_check;

update public.food_platform_campaigns
set name='โปรลูกค้าใหม่ · สั่งครบ ฿100 ลด ฿40',
    description='สำหรับลูกค้าที่ยังไม่เคยสั่งอาหารบน WYNOS Food ใช้ได้ 1 ครั้งต่อบัญชี ร้านเป็นผู้รับผิดชอบส่วนลดทั้งหมด',
    campaign_type='fixed', discount_value=40, min_subtotal=100, max_discount=null,
    platform_share_percent=0, is_active=false, join_open=false, updated_at=now()
where first_order_only;

alter table public.food_platform_campaigns
  add constraint food_platform_first_order_fixed_terms_check
  check (not first_order_only or (
    campaign_type='fixed' and discount_value=40 and min_subtotal=100
    and max_discount is null and platform_share_percent=0
  ));

-- Revalidate server-side redemption at checkout; this is not cosmetic.

create or replace function internal.food_first_order_validate_redemption()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare
  v_buyer uuid;
  v_is_first_order boolean;
begin
  select pc.first_order_only into v_is_first_order
  from public.food_platform_campaigns pc
  where pc.id = new.platform_campaign_id;
  if coalesce(v_is_first_order, false) = false then
    return new;
  end if;

  select o.buyer_id into v_buyer
  from public.food_orders o where o.id = new.order_id;
  if v_buyer is null then
    raise exception 'first_order_requires_customer';
  end if;
  if new.campaign_discount <> 40 or new.delivery_discount <> 0
     or new.platform_funded <> 0 then
    raise exception 'first_order_discount_mismatch';
  end if;
  if exists (
    select 1 from public.food_orders prior
    where prior.buyer_id = v_buyer
      and prior.id <> new.order_id
      and (
        prior.status <> 'cancelled'
        or prior.payment_status in ('paid','submitted','refunded')
      )
  ) then
    raise exception 'first_order_already_used';
  end if;
  return new;
end;
$fn$;

create or replace function public.admin_food_first_order_set_active(p_active boolean)
returns uuid language plpgsql security definer set search_path = '' as $fn$
declare
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS first-order promotions';
  end if;
  select id into v_id from public.food_platform_campaigns
  where first_order_only for update;
  if v_id is null then
    insert into public.food_platform_campaigns (
      name,description,campaign_type,discount_value,min_subtotal,max_discount,
      platform_share_percent,join_open,is_active,first_order_only,created_by
    ) values (
      'โปรลูกค้าใหม่ · สั่งครบ ฿100 ลด ฿40',
      'สำหรับลูกค้าที่ยังไม่เคยสั่งอาหารบน WYNOS Food ใช้ได้ 1 ครั้งต่อบัญชี ร้านเป็นผู้รับผิดชอบส่วนลดทั้งหมด',
      'fixed',40,100,null,0,true,false,true,auth.uid()
    ) returning id into v_id;
  end if;
  update public.food_platform_campaigns
  set is_active = coalesce(p_active,false),
      join_open = coalesce(p_active,false),
      updated_at = now()
  where id = v_id;
  perform set_config('wyn.platform_campaign_write', 'on', true);
  update public.food_campaigns
  set is_active=coalesce(p_active,false)
  where platform_campaign_id=v_id and deleted_at is null;
  perform set_config('wyn.platform_campaign_write', '', true);
  perform internal.log_audit_event(
    auth.uid(), 'admin_platform_campaign_saved', null,
    jsonb_build_object('campaign_id',v_id,'first_order_only',true,
      'is_active',coalesce(p_active,false),'merchant_funded',true)
  );
  return v_id;
end;
$fn$;

create or replace function public.food_first_order_offer(p_store_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_joined boolean := false;
  v_new_customer boolean := false;
begin
  if auth.uid() is null then
    return jsonb_build_object('eligible',false,'joined',false);
  end if;
  select exists (
    select 1 from public.food_campaigns c
    join public.food_platform_campaigns pc on pc.id = c.platform_campaign_id
    where c.store_id = p_store_id and pc.first_order_only
      and pc.is_active and pc.join_open
      and c.deleted_at is null and c.is_active
      and c.starts_at <= now()
      and (c.ends_at is null or c.ends_at > now())
      and (c.usage_limit is null or c.usage_count < c.usage_limit)
  ) into v_joined;
  select not exists (
    select 1 from public.food_orders prior
    where prior.buyer_id = auth.uid()
      and (prior.status <> 'cancelled'
           or prior.payment_status in ('paid','submitted','refunded'))
  ) into v_new_customer;
  return jsonb_build_object(
    'eligible', v_joined and v_new_customer,
    'joined', v_joined,
    'min_subtotal', 100,
    'discount_amount', 40
  );
end;
$fn$;
