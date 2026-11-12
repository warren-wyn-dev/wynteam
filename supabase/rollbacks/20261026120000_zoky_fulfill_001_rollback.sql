-- Rollback for 20261026120000_zoky_fulfill_001.sql (needs Founder approval).
-- 1. Refuses to run once any order or store has used the feature (pickup,
--    COD, a cancel request or a store refund slip), because dropping the
--    columns would delete that order history. This rollback is only for the
--    window before stores turn the feature on; after that, fix forward.
-- 2. Drops the new functions and refund-slip storage policies.
-- 3. Restores the six redefined functions to the live production definitions
--    of 2026-10-26 (read-only dump, GitHub run 40318273032).
-- 4. Drops the new constraints, index and columns.
-- Client v2 RPCs keep working throughout.
do $$
begin
  if exists (select 1 from public.food_orders
             where fulfillment_type <> 'delivery' or payment_method <> 'transfer'
                or cancel_requested_at is not null or refund_slip_path is not null
                or refunded_by_store_at is not null) then
    raise exception 'ZOKY-FULFILL-001 order data exists; rollback would lose it, fix forward instead';
  end if;
  if exists (select 1 from public.food_order_events
             where event_type in ('cancel_requested','cancel_request_rejected','pickup_scheduled','cod_selected')) then
    raise exception 'ZOKY-FULFILL-001 order events exist; rollback would orphan them, fix forward instead';
  end if;
end;
$$;

drop trigger if exists food_orders_fulfillment_guard on public.food_orders;
drop trigger if exists food_stores_fulfillment_settings_guard on public.food_stores;
drop function if exists internal.food_orders_fulfillment_guard();
drop function if exists internal.food_stores_fulfillment_settings_guard();
drop policy if exists "Food refund slip upload by store" on storage.objects;
drop policy if exists "Food refund slip readable by store and customer" on storage.objects;
drop function if exists public.food_store_mark_refunded(uuid, text, text);
drop function if exists public.food_resolve_cancel_request(uuid, boolean, boolean, text);
drop function if exists public.food_request_cancel(uuid, text);
drop function if exists public.food_complete_pickup(uuid, text);
drop function if exists public.food_store_set_fulfillment(uuid, boolean, boolean, boolean, integer);
drop function if exists public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text);
drop function if exists public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text);
drop function if exists public.food_pickup_slots(uuid);
drop function if exists internal.food_pickup_slots(uuid, timestamptz);

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
    new.gp_rate_bp := coalesce(v_rate.rate_bp, 0);
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

  if not v_allowed then raise exception 'invalid order transition'; end if;
  if v_order.status='pending_acceptance' and p_status='preparing' and v_order.payment_status <> 'paid' then
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
        when p_status='cancelled' and v_order.payment_status='paid' then 'pending'
        else refund_status
      end,
      refund_requested_at=case
        when p_status='cancelled' and v_order.payment_status='paid'
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
  set status='delivered', delivered_at=now()
  where id=p_order_id;

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
          || case when new.payment_status = 'paid' then ' · ร้านจะคืนเงินให้คุณ' else '' end);
    end if;
  end if;

  return new;
end;
$function$;

alter table public.food_orders
  drop constraint if exists food_orders_fulfillment_type_check,
  drop constraint if exists food_orders_payment_method_check,
  drop constraint if exists food_orders_pickup_fields_check,
  drop constraint if exists food_orders_cod_delivery_only_check,
  drop constraint if exists food_orders_cancel_request_note_length,
  drop constraint if exists food_orders_refund_slip_path_check;
drop index if exists public.food_orders_pickup_code_day_key;
drop index if exists public.food_orders_pickup_at_idx;
alter table public.food_orders
  drop column if exists fulfillment_type,
  drop column if exists payment_method,
  drop column if exists pickup_at,
  drop column if exists pickup_code,
  drop column if exists picked_up_at,
  drop column if exists cancel_requested_at,
  drop column if exists cancel_request_note,
  drop column if exists refund_slip_path,
  drop column if exists refunded_by_store_at;
alter table public.food_stores
  drop constraint if exists food_stores_fulfillment_mode_check,
  drop constraint if exists food_stores_pickup_prep_minutes_check;
alter table public.food_stores
  drop column if exists pickup_enabled,
  drop column if exists delivery_enabled,
  drop column if exists cod_enabled,
  drop column if exists pickup_prep_minutes;
