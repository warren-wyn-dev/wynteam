-- ZOKY-FULFILL-001: pickup at store, store delivery with optional COD,
-- store-decided cancellation and refunds.
-- Founder approval 2026-10-26 (.wyn/company/APPROVALS.md).
-- PRD:      .wyn/docs/product/zoky-fulfill-001-pickup-and-store-delivery.md
-- Design:   .wyn/docs/engineering/zoky-fulfill-001-technical-design.md
-- Contract: .wyn/docs/engineering/zoky-fulfill-001-contract.md (v2)
--
-- Additive. Existing rows become fulfillment_type='delivery',
-- payment_method='transfer'; every store keeps delivery only until it turns
-- pickup or COD on. No new order statuses: pickup reuses ready_for_delivery
-- ("พร้อมให้รับ") and delivered (+ picked_up_at), because sales, finance, GP and
-- reviews already treat delivered as completed.
-- Redefined functions are the live production definitions (read-only dump,
-- GitHub run 40318273032) with the smallest edits, each marked ZOKY-FULFILL-001.
-- Client v2 RPCs keep working unchanged.
-- ROLLBACK: supabase/rollbacks/20261026120000_zoky_fulfill_001_rollback.sql
-- Test:     supabase/tests/zoky_fulfill_001_test.sh

alter table public.food_stores
  add column if not exists pickup_enabled boolean not null default false,
  add column if not exists delivery_enabled boolean not null default true,
  add column if not exists cod_enabled boolean not null default false,
  add column if not exists pickup_prep_minutes integer not null default 15;

alter table public.food_stores
  drop constraint if exists food_stores_fulfillment_mode_check,
  add constraint food_stores_fulfillment_mode_check check (pickup_enabled or delivery_enabled),
  drop constraint if exists food_stores_pickup_prep_minutes_check,
  add constraint food_stores_pickup_prep_minutes_check check (pickup_prep_minutes between 5 and 120);

alter table public.food_orders
  add column if not exists fulfillment_type text not null default 'delivery',
  add column if not exists payment_method text not null default 'transfer',
  add column if not exists pickup_at timestamptz,
  add column if not exists pickup_code text,
  add column if not exists picked_up_at timestamptz,
  add column if not exists cancel_requested_at timestamptz,
  add column if not exists cancel_request_note text,
  add column if not exists refund_slip_path text,
  add column if not exists refunded_by_store_at timestamptz;

alter table public.food_orders
  drop constraint if exists food_orders_fulfillment_type_check,
  add constraint food_orders_fulfillment_type_check check (fulfillment_type in ('delivery','pickup')),
  drop constraint if exists food_orders_payment_method_check,
  add constraint food_orders_payment_method_check check (payment_method in ('transfer','cod')),
  drop constraint if exists food_orders_pickup_fields_check,
  add constraint food_orders_pickup_fields_check check (
    fulfillment_type = 'delivery'
    or (pickup_at is not null and pickup_code is not null and payment_method = 'transfer')),
  drop constraint if exists food_orders_cod_delivery_only_check,
  add constraint food_orders_cod_delivery_only_check check (payment_method = 'transfer' or fulfillment_type = 'delivery'),
  drop constraint if exists food_orders_cancel_request_note_length,
  add constraint food_orders_cancel_request_note_length check (cancel_request_note is null or char_length(cancel_request_note) <= 500),
  drop constraint if exists food_orders_refund_slip_path_check,
  add constraint food_orders_refund_slip_path_check check (
    refund_slip_path is null
    or (refund_slip_path like 'refunds/' || id::text || '/%' and position('..' in refund_slip_path) = 0));

create index if not exists food_orders_pickup_at_idx
  on public.food_orders (store_id, pickup_at)
  where fulfillment_type = 'pickup';

-- Pickup codes restart every Bangkok day; the advisory lock in
-- food_create_order_v3 serialises them and this index backs it up.
create unique index if not exists food_orders_pickup_code_day_key
  on public.food_orders (store_id, pickup_code, ((created_at at time zone 'Asia/Bangkok')::date))
  where pickup_code is not null;

CREATE OR REPLACE FUNCTION internal.food_delivery_fee(p_store_id uuid, p_latitude double precision, p_longitude double precision)
 RETURNS TABLE(distance_km numeric, delivery_fee numeric)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_distance numeric;
  v_developer boolean := exists (select 1 from public.developer_accounts d where d.user_id = (select auth.uid()));
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store is not accepting orders';
  end if;
  if not v_developer and not internal.food_in_service_area(v_store.latitude, v_store.longitude) then
    raise exception 'store is outside the service area';
  end if;
  -- ZOKY-FULFILL-001: pickup orders have no delivery fee or customer pin.
  if current_setting('wyn.food_fulfillment', true) = 'pickup' then
    return query select null::numeric, 0::numeric;
    return;
  end if;
  if v_store.latitude is null then
    return query select null::numeric, v_store.delivery_fee;
    return;
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'delivery location required';
  end if;
  if not v_developer and not internal.food_in_service_area(p_latitude, p_longitude) then
    raise exception 'outside service area';
  end if;
  v_distance := internal.food_distance_km(v_store.latitude, v_store.longitude, p_latitude, p_longitude);
  if v_distance > v_store.delivery_radius_km then
    raise exception 'outside delivery area';
  end if;
  return query select
    v_distance,
    (v_store.delivery_fee
      + ceil(greatest(v_distance - v_store.delivery_base_km, 0) * v_store.delivery_fee_per_km))::numeric;
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_orders_gp_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_rate record;
begin
  if tg_op = 'INSERT' then
    select * into v_rate from internal.merchant_gp_rate_at(new.store_id, now());
    new.gp_rate_bp := case
      when current_setting('wyn.food_payment_method', true) = 'cod' then 0
      else coalesce(v_rate.rate_bp, 0) end;
    new.gp_rate_id := v_rate.rate_id;
    new.gp_rule_version := 'gp_v1_food_after_store_discount';
  else
    new.gp_rate_bp := old.gp_rate_bp;
    new.gp_rate_id := old.gp_rate_id;
    new.gp_rule_version := old.gp_rule_version;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_transition_order(p_order_id uuid, p_status text, p_eta_minutes integer DEFAULT NULL::integer, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_allowed boolean := false;
  v_roles text[];
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  v_roles := case
    when p_status='out_for_delivery' then array['owner','admin','manager','orders','delivery']
    else array['owner','admin','manager','orders']
  end;
  if not public.merchant_has_store_role(v_order.store_id, v_roles) then
    raise exception 'order management role required';
  end if;

  if p_eta_minutes is not null and (p_eta_minutes < 1 or p_eta_minutes > 240) then
    raise exception 'invalid ETA';
  end if;

  v_allowed := case
    when v_order.status='pending_acceptance' and p_status in ('preparing','cancelled') then true
    when v_order.status='preparing' and p_status in ('ready_for_delivery','cancelled') then true
    when v_order.status='ready_for_delivery' and p_status in ('out_for_delivery','cancelled') then true
    when v_order.status='out_for_delivery' and p_status='cancelled' then true
    else false
  end;

  -- ZOKY-FULFILL-001: pickup orders never go out for delivery (they finish
  -- through food_complete_pickup); COD orders are accepted before payment.
  if v_order.fulfillment_type='pickup' and p_status='out_for_delivery' then
    v_allowed := false;
  end if;
  if not v_allowed then raise exception 'invalid order transition'; end if;
  if v_order.status='pending_acceptance' and p_status='preparing'
     and v_order.payment_status <> 'paid' and v_order.payment_method <> 'cod' then
    raise exception 'payment must be verified first';
  end if;

  update public.food_orders
  set status=p_status,
      eta_minutes=coalesce(p_eta_minutes,eta_minutes),
      accepted_at=case when p_status='preparing' then coalesce(accepted_at,now()) else accepted_at end,
      ready_at=case when p_status='ready_for_delivery' then now() else ready_at end,
      out_for_delivery_at=case when p_status='out_for_delivery' then now() else out_for_delivery_at end,
      cancelled_at=case when p_status='cancelled' then now() else cancelled_at end,
      refund_status=case
        when p_status='cancelled' and v_order.payment_status='paid'
          and current_setting('wyn.food_cancel_refund', true) = 'none' then 'none'
        when p_status='cancelled' and v_order.payment_status='paid' then 'pending'
        else refund_status
      end,
      refund_requested_at=case
        when p_status='cancelled' and v_order.payment_status='paid'
          and current_setting('wyn.food_cancel_refund', true) is distinct from 'none'
          then coalesce(refund_requested_at,now())
        else refund_requested_at
      end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (
    p_order_id,'status_changed',v_order.status,p_status,
    nullif(left(trim(coalesce(p_note,'')),1000),''),
    auth.uid()
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_complete_delivery(p_order_id uuid, p_method text, p_location_note text DEFAULT NULL::text, p_image_path text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_location_note,''), E' \t\r\n'),500),'');
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders','delivery']) then
    raise exception 'delivery role required';
  end if;
  if v_order.status <> 'out_for_delivery' then
    raise exception 'order is not out for delivery';
  end if;
  if p_method is null or p_method not in ('direct','dropoff') then
    raise exception 'invalid delivery method';
  end if;
  if p_image_path is null
    or p_image_path not like 'delivery/' || p_order_id::text || '/%'
    or position('..' in p_image_path) > 0
    or not exists (
      select 1 from storage.objects o
      where o.bucket_id='food-private' and o.name=p_image_path
    )
  then
    raise exception 'delivery photo is required';
  end if;
  if p_method='dropoff' and v_note is null then
    raise exception 'dropoff location is required';
  end if;

  insert into public.food_delivery_proofs(order_id,method,location_note,image_path,delivered_by)
  values (
    p_order_id,p_method,
    case when p_method='dropoff' then v_note else null end,
    p_image_path,
    auth.uid()
  )
  on conflict (order_id) do update
  set method=excluded.method,
      location_note=excluded.location_note,
      image_path=excluded.image_path,
      delivered_by=excluded.delivered_by,
      created_at=now();

  update public.food_orders
  set status='delivered', delivered_at=now(),
      payment_status=case when v_order.payment_method='cod' then 'paid' else payment_status end,
      paid_at=case when v_order.payment_method='cod' then coalesce(paid_at,now()) else paid_at end,
      payment_verification_status=case when v_order.payment_method='cod' then 'manual_verified' else payment_verification_status end,
      payment_provider=case when v_order.payment_method='cod' then 'cash' else payment_provider end
  where id=p_order_id;

  if v_order.payment_method='cod' then
    insert into public.food_order_events(order_id,event_type,note,actor_id)
    values (p_order_id,'cod_collected','ร้านได้รับเงินสดปลายทางแล้ว',auth.uid());
  end if;

  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (
    p_order_id,'delivered','out_for_delivery','delivered',
    case when p_method='dropoff' then v_note else 'ส่งให้ผู้รับโดยตรง' end,
    auth.uid()
  );

  if v_order.buyer_id is not null and internal.notification_enabled(v_order.buyer_id, 'system') then
    insert into public.notifications(recipient_id,actor_id,type,reason)
    values (
      v_order.buyer_id,null,'system',
      'ออเดอร์ #' || v_order.order_number || ' ส่งถึงแล้ว · ดูรูปยืนยันการจัดส่งได้ในหน้าออเดอร์'
    );
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_submit_payment(p_order_id uuid, p_slip_path text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  if v_order.payment_method = 'cod' then raise exception 'cod order takes no slip'; end if;
  if v_order.payment_status not in ('pending','issue') then
    raise exception 'payment already submitted';
  end if;
  if v_order.stripe_checkout_session_id is not null then
    raise exception 'cancel stripe checkout before submitting slip';
  end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text || '/slips/' || p_order_id::text || '/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status = 'submitted',
      payment_slip_path = p_slip_path,
      payment_note = null,
      payment_verification_status = 'manual_review',
      payment_provider = null,
      payment_provider_code = null,
      payment_transaction_ref = null,
      payment_verified_at = null,
      payment_verification_note = null
  where id = p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_order_status_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'internal'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_account_id uuid;
  v_reason text;
begin
  if new.status is not distinct from old.status then return new; end if;

  if new.status = 'preparing' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร'
      || case when new.eta_minutes is not null then ' (ประมาณ ' || new.eta_minutes || ' นาที)' else '' end);
  elsif new.status = 'ready_for_delivery' and new.fulfillment_type = 'pickup' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' พร้อมให้รับที่ร้านแล้ว · รหัสรับอาหาร ' || coalesce(new.pickup_code,'-'));
  elsif new.status = 'out_for_delivery' and new.buyer_id is not null then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (new.buyer_id, null, 'system',
      'ออเดอร์ #' || new.order_number || ' กำลังจัดส่ง · เตรียมรับอาหารได้เลย');
  elsif new.status = 'cancelled' then
    if current_setting('wynos.food_auto_cancel',true) = 'on' then
      if new.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (new.buyer_id, null, 'system',
          'ออเดอร์ #' || new.order_number || ' ถูกยกเลิกอัตโนมัติ เพราะไม่ชำระเงินภายใน 10 นาที');
      end if;
      v_reason := 'WYNOS Merchant · ออเดอร์ #' || new.order_number ||
                  ' ยกเลิกอัตโนมัติ (ไม่ได้ชำระเงินภายใน 10 นาที)';
      select s.merchant_account_id into v_account_id
      from public.food_stores s where s.id = new.store_id;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'order', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id = v_account_id and mm.active;
      end if;
    elsif new.buyer_id is not null and v_actor is not distinct from new.buyer_id then
      v_reason := 'WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #' || new.order_number;
      select s.merchant_account_id into v_account_id from public.food_stores s where s.id = new.store_id;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'order', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id = v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (new.buyer_id, null, 'system',
        'ออเดอร์ #' || new.order_number || ' ถูกร้านยกเลิก'
          || case
               when new.payment_status = 'paid' and new.refund_status = 'pending' then ' · ร้านจะคืนเงินให้คุณ'
               when new.payment_status = 'paid' and new.refund_status = 'none' then ' · ร้านไม่คืนเงินสำหรับออเดอร์นี้'
               else '' end);
    end if;
  end if;

  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- New server functions (ZOKY-FULFILL-001)
-- ---------------------------------------------------------------------------

-- Pickup slots for today (Asia/Bangkok), every 15 minutes, from now + prep
-- time to closing time - prep time. Needs a structured weekly schedule.
create or replace function internal.food_pickup_slots(p_store_id uuid, p_now timestamptz default now())
returns setof timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_prep interval;
  v_t timestamptz;
  v_day date;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  -- Only published stores that are open right now offer slots, the same
  -- rule the order insert guard applies.
  if not found or not v_store.pickup_enabled or not v_store.is_published
     or not internal.food_store_effectively_open(p_store_id, p_now)
     or jsonb_typeof(v_store.business_schedule->'weekly') is distinct from 'object' then
    return;
  end if;
  v_prep := make_interval(mins => v_store.pickup_prep_minutes);
  v_day := (p_now at time zone 'Asia/Bangkok')::date;
  v_t := to_timestamp(ceil(extract(epoch from p_now + v_prep) / 900) * 900);
  while (v_t at time zone 'Asia/Bangkok')::date = v_day loop
    if internal.food_store_effectively_open(p_store_id, v_t)
       and internal.food_store_effectively_open(p_store_id, v_t + v_prep - interval '1 minute') then
      return next v_t;
    end if;
    v_t := v_t + interval '15 minutes';
  end loop;
end;
$$;
revoke all on function internal.food_pickup_slots(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.food_pickup_slots(p_store_id uuid)
returns timestamptz[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(s order by s), '{}'::timestamptz[])
  from internal.food_pickup_slots(p_store_id, now()) s;
$$;
revoke all on function public.food_pickup_slots(uuid) from public;
grant execute on function public.food_pickup_slots(uuid) to anon, authenticated;

create or replace function public.food_quote_order_v3(
  p_store_id uuid, p_items jsonb,
  p_latitude double precision default null, p_longitude double precision default null,
  p_coupon_code text default null, p_fulfillment_type text default 'delivery'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_quote jsonb;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then raise exception 'store is not accepting orders'; end if;
  if p_fulfillment_type = 'pickup' then
    if not v_store.pickup_enabled then raise exception 'pickup_not_available'; end if;
    perform set_config('wyn.food_fulfillment', 'pickup', true);
    -- The store's own pin keeps the quote on the fee path (which returns 0 for
    -- pickup) instead of the "needs a location" base-fee preview.
    v_quote := public.food_quote_order_v2(p_store_id, p_items, v_store.latitude, v_store.longitude, p_coupon_code);
    perform set_config('wyn.food_fulfillment', '', true);
  elsif p_fulfillment_type = 'delivery' then
    if not v_store.delivery_enabled then raise exception 'delivery_not_available'; end if;
    v_quote := public.food_quote_order_v2(p_store_id, p_items, p_latitude, p_longitude, p_coupon_code);
  else
    raise exception 'invalid fulfillment type';
  end if;
  return v_quote || jsonb_build_object(
    'fulfillment_type', p_fulfillment_type,
    'pickup_slots', case when p_fulfillment_type = 'pickup' then to_jsonb(public.food_pickup_slots(p_store_id)) else '[]'::jsonb end,
    'cod_available', p_fulfillment_type = 'delivery' and v_store.cod_enabled
  );
end;
$$;
revoke all on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text) from public, anon;
grant execute on function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text) to authenticated;

create or replace function public.food_create_order_v3(
  p_store_id uuid, p_recipient_name text, p_recipient_phone text,
  p_shipping_address text, p_customer_note text, p_items jsonb,
  p_latitude double precision default null, p_longitude double precision default null,
  p_coupon_code text default null,
  p_fulfillment_type text default 'delivery',
  p_pickup_at timestamptz default null,
  p_payment_method text default 'transfer'
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_id uuid;
  v_code text;
  v_day date := (now() at time zone 'Asia/Bangkok')::date;
  v_seq integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_fulfillment_type is null or p_fulfillment_type not in ('delivery','pickup') then
    raise exception 'invalid fulfillment type';
  end if;
  if p_payment_method is null or p_payment_method not in ('transfer','cod') then
    raise exception 'invalid payment method';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then raise exception 'store is not accepting orders'; end if;

  if p_fulfillment_type = 'pickup' then
    if not v_store.pickup_enabled then raise exception 'pickup_not_available'; end if;
    if p_payment_method <> 'transfer' then raise exception 'cod_delivery_only'; end if;
    -- The slot is re-checked against the server clock and schedule; the
    -- client only picks one of the offered values.
    if p_pickup_at is null or not exists (
      select 1 from internal.food_pickup_slots(p_store_id, now()) s where s = p_pickup_at
    ) then
      raise exception 'invalid_pickup_time';
    end if;
    perform set_config('wyn.food_fulfillment', 'pickup', true);
    v_id := public.food_create_order_v2(
      p_store_id, p_recipient_name, p_recipient_phone,
      coalesce(nullif(btrim(p_shipping_address), ''), 'รับเองที่ร้าน'),
      p_customer_note, p_items, null, null, p_coupon_code);
    perform set_config('wyn.food_fulfillment', '', true);

    -- Short code shown at the counter, unique per store per Bangkok day.
    perform pg_advisory_xact_lock(hashtext('food_pickup_code:' || p_store_id::text || ':' || v_day::text));
    -- Highest code today + 1, so a deleted order never makes the next code collide.
    select coalesce(max(substr(o.pickup_code, 2)::integer), 0) + 1 into v_seq
    from public.food_orders o
    where o.store_id = p_store_id and o.pickup_code ~ '^P[0-9]+$'
      and (o.created_at at time zone 'Asia/Bangkok')::date = v_day;
    v_code := 'P' || lpad(v_seq::text, 3, '0');

    update public.food_orders
    set fulfillment_type = 'pickup', pickup_at = p_pickup_at, pickup_code = v_code
    where id = v_id;
    insert into public.food_order_events(order_id, event_type, note, actor_id)
    values (v_id, 'pickup_scheduled',
      'รับเองที่ร้าน · รหัส ' || v_code || ' · ' || to_char(p_pickup_at at time zone 'Asia/Bangkok', 'HH24:MI'),
      auth.uid());
  else
    if not v_store.delivery_enabled then raise exception 'delivery_not_available'; end if;
    if p_pickup_at is not null then raise exception 'invalid_pickup_time'; end if;
    if p_payment_method = 'cod' then
      if not v_store.cod_enabled then raise exception 'cod_not_available'; end if;
      perform set_config('wyn.food_payment_method', 'cod', true);
    end if;
    v_id := public.food_create_order_v2(
      p_store_id, p_recipient_name, p_recipient_phone, p_shipping_address,
      p_customer_note, p_items, p_latitude, p_longitude, p_coupon_code);
    perform set_config('wyn.food_payment_method', '', true);
    if p_payment_method = 'cod' then
      -- Cash is collected at the door: no 10-minute transfer deadline.
      update public.food_orders
      set payment_method = 'cod', payment_due_at = null
      where id = v_id;
      insert into public.food_order_events(order_id, event_type, note, actor_id)
      values (v_id, 'cod_selected', 'ลูกค้าเลือกจ่ายเงินสดปลายทาง', auth.uid());
    end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text) from public, anon;
grant execute on function public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text) to authenticated;

create or replace function public.food_store_set_fulfillment(
  p_store_id uuid, p_pickup boolean, p_delivery boolean, p_cod boolean, p_prep_minutes integer
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin']) then
    raise exception 'store settings role required';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then raise exception 'store not found'; end if;
  if not coalesce(p_pickup, false) and not coalesce(p_delivery, false) then
    raise exception 'at_least_one_mode';
  end if;
  if coalesce(p_pickup, false)
     and jsonb_typeof(v_store.business_schedule->'weekly') is distinct from 'object' then
    raise exception 'pickup_requires_schedule';
  end if;
  if coalesce(p_cod, false) and not coalesce(p_delivery, false) then
    raise exception 'cod_delivery_only';
  end if;
  if p_prep_minutes is null or p_prep_minutes not between 5 and 120 then
    raise exception 'invalid_prep_minutes';
  end if;
  perform set_config('wyn.food_fulfillment_settings', 'on', true);
  update public.food_stores
  set pickup_enabled = p_pickup, delivery_enabled = p_delivery,
      cod_enabled = coalesce(p_cod, false), pickup_prep_minutes = p_prep_minutes
  where id = p_store_id;
  perform set_config('wyn.food_fulfillment_settings', '', true);
end;
$$;
revoke all on function public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer) from public, anon;
grant execute on function public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer) to authenticated;

-- Pickup: the customer collected the order (no photo).
create or replace function public.food_complete_pickup(p_order_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.fulfillment_type <> 'pickup' then raise exception 'not a pickup order'; end if;
  if v_order.status <> 'ready_for_delivery' then raise exception 'invalid order transition'; end if;
  update public.food_orders
  set status = 'delivered', delivered_at = now(), picked_up_at = now(),
      cancel_requested_at = null
  where id = p_order_id;
  insert into public.food_order_events(order_id, event_type, from_status, to_status, note, actor_id)
  values (p_order_id, 'picked_up', 'ready_for_delivery', 'delivered',
    coalesce(nullif(left(btrim(coalesce(p_note, '')), 500), ''), 'ลูกค้ารับอาหารที่ร้านแล้ว'), auth.uid());
  if v_order.buyer_id is not null and internal.notification_enabled(v_order.buyer_id, 'system') then
    insert into public.notifications(recipient_id, actor_id, type, reason)
    values (v_order.buyer_id, null, 'system', 'ออเดอร์ #' || v_order.order_number || ' รับอาหารเรียบร้อยแล้ว');
  end if;
end;
$$;
revoke all on function public.food_complete_pickup(uuid, text) from public, anon;
grant execute on function public.food_complete_pickup(uuid, text) to authenticated;

-- Pickup: after payment or acceptance the customer can only ask to cancel;
-- the store decides (Founder 2026-10-26).
create or replace function public.food_request_cancel(p_order_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
  v_reason text;
  v_account_id uuid;
begin
  if not public.food_customer_access_enabled() then raise exception 'food customer access required'; end if;
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or v_order.buyer_id is distinct from auth.uid() then raise exception 'order not found'; end if;
  if v_order.fulfillment_type <> 'pickup' then raise exception 'cancel request is for pickup orders'; end if;
  -- Only paid orders: a slip still under review has no money confirmed, so a
  -- refund decision would have nothing to refund.
  if v_order.status not in ('pending_acceptance','preparing','ready_for_delivery')
     or v_order.payment_status <> 'paid' then
    raise exception 'cancel request not available';
  end if;
  if v_order.cancel_requested_at is not null then raise exception 'cancel already requested'; end if;
  -- One request per order: after the store says no, the customer contacts the store.
  if exists (select 1 from public.food_order_events e
             where e.order_id = p_order_id and e.event_type = 'cancel_request_rejected') then
    raise exception 'cancel request not available';
  end if;
  update public.food_orders
  set cancel_requested_at = now(),
      cancel_request_note = nullif(left(btrim(coalesce(p_note, '')), 500), '')
  where id = p_order_id;
  insert into public.food_order_events(order_id, event_type, note, actor_id)
  values (p_order_id, 'cancel_requested', nullif(left(btrim(coalesce(p_note, '')), 500), ''), auth.uid());
  v_reason := 'WYNOS Merchant · ลูกค้าขอยกเลิกออเดอร์ #' || v_order.order_number;
  select s.merchant_account_id into v_account_id from public.food_stores s where s.id = v_order.store_id;
  if v_account_id is not null then
    insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
    select v_account_id, mm.user_id, 'order', v_reason
    from public.merchant_memberships mm
    where mm.merchant_account_id = v_account_id and mm.active;
  end if;
end;
$$;
revoke all on function public.food_request_cancel(uuid, text) from public, anon;
grant execute on function public.food_request_cancel(uuid, text) to authenticated;

create or replace function public.food_resolve_cancel_request(
  p_order_id uuid, p_approve boolean, p_refund boolean, p_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 500), '');
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.cancel_requested_at is null then raise exception 'no cancel request'; end if;
  if not coalesce(p_approve, false) then
    update public.food_orders set cancel_requested_at = null where id = p_order_id;
    insert into public.food_order_events(order_id, event_type, note, actor_id)
    values (p_order_id, 'cancel_request_rejected', v_note, auth.uid());
    if v_order.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (v_order.buyer_id, null, 'system',
        'ร้านไม่อนุมัติการยกเลิกออเดอร์ #' || v_order.order_number || coalesce(' · ' || v_note, ''));
    end if;
    return;
  end if;
  -- The store chooses whether a paid order is refunded; the existing
  -- transition writes refund_status from this setting.
  perform set_config('wyn.food_cancel_refund', case when coalesce(p_refund, false) then 'pending' else 'none' end, true);
  perform public.food_transition_order(p_order_id, 'cancelled', null, coalesce(v_note, 'ร้านอนุมัติคำขอยกเลิกของลูกค้า'));
  perform set_config('wyn.food_cancel_refund', '', true);
  update public.food_orders set cancel_requested_at = null where id = p_order_id;
  insert into public.food_order_events(order_id, event_type, note, actor_id)
  values (p_order_id, case when coalesce(p_refund, false) then 'cancel_request_approved_refund' else 'cancel_request_approved_no_refund' end,
    v_note, auth.uid());
end;
$$;
revoke all on function public.food_resolve_cancel_request(uuid, boolean, boolean, text) from public, anon;
grant execute on function public.food_resolve_cancel_request(uuid, boolean, boolean, text) to authenticated;

-- Transfer refunds are done by the store; it attaches the refund slip.
create or replace function public.food_store_mark_refunded(
  p_order_id uuid, p_refund_slip_path text, p_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager']) then
    raise exception 'refund role required';
  end if;
  if v_order.refund_status <> 'pending' then raise exception 'no refund pending'; end if;
  if p_refund_slip_path is null
     or p_refund_slip_path not like 'refunds/' || p_order_id::text || '/%'
     or position('..' in p_refund_slip_path) > 0
     or not exists (select 1 from storage.objects o where o.bucket_id = 'food-private' and o.name = p_refund_slip_path) then
    raise exception 'refund slip is required';
  end if;
  perform public.merchant_set_refund_status(p_order_id, 'refunded', p_note);
  update public.food_orders
  set refund_slip_path = p_refund_slip_path, refunded_by_store_at = now()
  where id = p_order_id;
end;
$$;
revoke all on function public.food_store_mark_refunded(uuid, text, text) from public, anon;
grant execute on function public.food_store_mark_refunded(uuid, text, text) to authenticated;

-- Refund slips: refunds/<order_id>/<file> in food-private. Store staff of that
-- order's store upload and read; the order's customer reads. Added as new
-- permissive policies; existing food-private policies are not touched.
drop policy if exists "Food refund slip upload by store" on storage.objects;
create policy "Food refund slip upload by store"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'refunds'
  and exists (
    select 1 from public.food_orders o
    where o.id = public.food_path_uuid((storage.foldername(name))[2])
      and o.refund_status = 'pending'
      and public.merchant_has_store_role(o.store_id, array['owner','admin','manager'])
  )
);

drop policy if exists "Food refund slip readable by store and customer" on storage.objects;
create policy "Food refund slip readable by store and customer"
on storage.objects for select to authenticated
using (
  bucket_id = 'food-private'
  and (storage.foldername(name))[1] = 'refunds'
  and exists (
    select 1 from public.food_orders o
    where o.id = public.food_path_uuid((storage.foldername(name))[2])
      and (o.buyer_id = auth.uid() or public.food_has_merchant_access(o.store_id))
  )
);

-- ---------------------------------------------------------------------------
-- Guards (QA 2026-10-26)
-- ---------------------------------------------------------------------------

-- A store that turned delivery off gets no delivery orders from any client,
-- including the v1/v2 RPCs. Pickup orders pass (v3 sets the flag), and so do
-- the store's own manual/social orders.
create or replace function internal.food_orders_fulfillment_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.source = 'app'
     and current_setting('wyn.food_fulfillment', true) is distinct from 'pickup'
     and exists (select 1 from public.food_stores s where s.id = new.store_id and not s.delivery_enabled) then
    raise exception 'delivery_not_available';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_orders_fulfillment_guard() from public, anon, authenticated;
drop trigger if exists food_orders_fulfillment_guard on public.food_orders;
create trigger food_orders_fulfillment_guard
before insert on public.food_orders
for each row execute function internal.food_orders_fulfillment_guard();

-- Pickup / delivery / COD / prep time change only through
-- food_store_set_fulfillment (owner/admin, schedule check). Store staff who may
-- update other store fields directly cannot change these. Service-role jobs
-- (no auth.uid()) are not affected.
create or replace function internal.food_stores_fulfillment_settings_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.pickup_enabled, new.delivery_enabled, new.cod_enabled, new.pickup_prep_minutes)
       is distinct from (old.pickup_enabled, old.delivery_enabled, old.cod_enabled, old.pickup_prep_minutes)
     and auth.uid() is not null
     and current_setting('wyn.food_fulfillment_settings', true) is distinct from 'on' then
    raise exception 'use food_store_set_fulfillment';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_stores_fulfillment_settings_guard() from public, anon, authenticated;
drop trigger if exists food_stores_fulfillment_settings_guard on public.food_stores;
create trigger food_stores_fulfillment_settings_guard
before update on public.food_stores
for each row execute function internal.food_stores_fulfillment_settings_guard();

