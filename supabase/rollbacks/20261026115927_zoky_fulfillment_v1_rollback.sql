-- Explicitly approved recovery only. Keeps old delivery orders, refuses new fulfillment/evidence data.
begin;
set local lock_timeout='5s';
drop trigger food_fulfillment_order_guard on public.food_orders;
drop function internal.food_fulfillment_order_guard();
do $$ begin
 if exists(select 1 from public.food_orders where fulfillment_type<>'delivery' or payment_method<>'transfer' or cancel_requested_at is not null or refund_slip_path is not null)
 then raise exception 'fulfillment data exists: preserve evidence and use an approved forward fix'; end if;
end; $$;
CREATE OR REPLACE FUNCTION public.food_create_order(p_store_id uuid, p_recipient_name text, p_recipient_phone text, p_shipping_address text, p_customer_note text, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_campaign public.food_campaigns%rowtype;
  v_line jsonb;
  v_order_id uuid;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2);
  v_count integer := 0;
  v_lines jsonb := '[]'::jsonb;
  v_recent integer;
  v_pending integer;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_delivery_fee numeric(10,2);
  v_distance numeric(6,2);
  v_options jsonb;
  v_surcharge numeric(10,2);
  v_unit numeric(10,2);
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(trim(p_recipient_name)),0)=0
     or coalesce(char_length(trim(p_recipient_phone)),0)=0
     or coalesce(char_length(trim(p_shipping_address)),0)=0 then
    raise exception 'recipient information is required';
  end if;

  if jsonb_typeof(p_items)<>'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  -- WYN-218: limit how fast one buyer can place orders. One lock per buyer
  -- so parallel requests cannot slip past the count.
  if not public.is_developer_account() then
    perform pg_advisory_xact_lock(hashtext('food_create_order:' || auth.uid()::text));
    select count(*) into v_recent
    from public.food_orders o
    where o.buyer_id = auth.uid()
      and o.created_at > now() - interval '10 minutes';
    if v_recent >= 5 then
      raise exception 'too many orders, try again later';
    end if;
    select count(*) into v_pending
    from public.food_orders o
    where o.buyer_id = auth.uid()
      and o.store_id = p_store_id
      and o.status = 'pending_acceptance';
    if v_pending >= 3 then
      raise exception 'too many pending orders';
    end if;
  end if;

  select * into v_store from public.food_stores where id=p_store_id;
  if not found
     or not v_store.is_open
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  -- WYN-196: distance-based fee and delivery radius, computed on the server.
  select z.distance_km, z.delivery_fee into v_distance, v_delivery_fee
  from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id
      and store_id=p_store_id
      and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    -- WYN-218: options are resolved from the menu, never taken from the client.
    select r.options, r.surcharge into v_options, v_surcharge
    from internal.food_resolve_menu_options(v_item.options, v_line->'selected_options') r;
    v_unit := v_item.price + v_surcharge;

    v_subtotal := v_subtotal + (v_unit * v_qty);
    v_count := v_count + 1;
    v_lines := v_lines || jsonb_build_array(jsonb_build_object(
      'menu_item_id', v_item.id,
      'item_name', v_item.name,
      'unit_price', v_unit,
      'quantity', v_qty,
      'selected_options', v_options,
      'note', v_line->>'note'
    ));
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_unit * v_qty)
    );
  end loop;

  if v_count=0 or v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

  -- Select the best promotion, lock it, then re-check under the lock.
  -- If another checkout consumed its final limited use while we waited,
  -- retry so the customer can still receive the next-best eligible campaign.
  loop
    v_campaign_id := null;
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;

    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_delivery_fee,v_item_totals
    ) c
    limit 1;

    exit when v_campaign_id is null;

    select * into v_campaign
    from public.food_campaigns c
    where c.id=v_campaign_id
    for update;

    v_campaign_id := null;
    select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
      into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    from internal.food_campaign_candidates(
      p_store_id,v_subtotal,v_delivery_fee,v_item_totals
    ) c
    where c.campaign_id=v_campaign.id
    limit 1;

    exit when v_campaign_id is not null;
  end loop;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  if v_campaign_id is null then
    v_campaign_name := null;
    v_campaign_type := null;
    v_campaign_discount := 0;
    v_delivery_discount := 0;
  end if;

  v_total := greatest(v_subtotal - v_campaign_discount + v_delivery_fee - v_delivery_discount,0);

  insert into public.food_orders(
    store_id,buyer_id,created_by,source,status,payment_status,
    recipient_name,recipient_phone,shipping_address,customer_note,
    subtotal,delivery_fee,campaign_id,campaign_name,campaign_discount,delivery_discount,total,
    delivery_latitude,delivery_longitude,delivery_distance_km
  ) values (
    p_store_id,
    auth.uid(),
    auth.uid(),
    'app',
    'pending_acceptance',
    'pending',
    left(trim(p_recipient_name),120),
    left(trim(p_recipient_phone),50),
    left(trim(p_shipping_address),800),
    nullif(left(trim(coalesce(p_customer_note,'')),800),''),
    v_subtotal,
    v_delivery_fee,
    v_campaign_id,
    v_campaign_name,
    v_campaign_discount,
    v_delivery_discount,
    v_total,
    case when v_distance is null then null else p_latitude end,
    case when v_distance is null then null else p_longitude end,
    v_distance
  )
  returning id into v_order_id;

  -- Insert the lines exactly as they were priced above.
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.food_order_items(
      order_id,menu_item_id,item_name,unit_price,quantity,selected_options,item_note
    ) values (
      v_order_id,
      (v_line->>'menu_item_id')::uuid,
      v_line->>'item_name',
      (v_line->>'unit_price')::numeric,
      (v_line->>'quantity')::integer,
      v_line->'selected_options',
      nullif(left(trim(coalesce(v_line->>'note','')),500),'')
    );
  end loop;

  if v_campaign_id is not null then
    insert into public.food_order_campaigns(
      order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount
    ) values (
      v_order_id,v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
    );

    update public.food_campaigns
    set usage_count=usage_count+1
    where id=v_campaign_id;

    insert into public.food_order_events(order_id,event_type,note,actor_id)
    values (
      v_order_id,'campaign_applied',
      left(v_campaign_name || ' · ลด ฿' || trim(to_char(v_campaign_discount+v_delivery_discount,'FM999999990.00')),1000),
      auth.uid()
    );
  end if;

  insert into public.food_order_events(order_id,event_type,to_status,note,actor_id)
  values (v_order_id,'created','pending_acceptance','สร้างคำสั่งซื้อ',auth.uid());

  return v_order_id;
end;
$function$;
CREATE OR REPLACE FUNCTION public.food_quote_order(p_store_id uuid, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_line jsonb;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_total numeric(10,2);
  v_delivery_fee numeric(10,2);
  v_distance numeric(6,2);
  v_options jsonb;
  v_surcharge numeric(10,2);
  v_unit numeric(10,2);
  v_needs_location boolean := false;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items)=0
     or jsonb_array_length(p_items)>50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store from public.food_stores where id=p_store_id;
  if not found
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  -- WYN-196: a store with a pinned location charges by distance and only
  -- delivers inside its radius. The cart can be quoted before an address is
  -- chosen; it then shows the base fee and says a location is needed.
  if v_store.latitude is not null and (p_latitude is null or p_longitude is null) then
    v_needs_location := true;
    v_delivery_fee := v_store.delivery_fee;
  else
    select z.distance_km, z.delivery_fee into v_distance, v_delivery_fee
    from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;
  end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id and store_id=p_store_id and is_available;
    if not found then raise exception 'menu item is unavailable'; end if;

    -- WYN-218: options are resolved from the menu, never taken from the client.
    select r.options, r.surcharge into v_options, v_surcharge
    from internal.food_resolve_menu_options(v_item.options, v_line->'selected_options') r;
    v_unit := v_item.price + v_surcharge;

    v_subtotal := v_subtotal + (v_unit * v_qty);
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_unit * v_qty)
    );
  end loop;

  select c.campaign_id,c.campaign_name,c.campaign_type,c.campaign_discount,c.delivery_discount
    into v_campaign_id,v_campaign_name,v_campaign_type,v_campaign_discount,v_delivery_discount
  from internal.food_campaign_candidates(
    p_store_id,v_subtotal,v_delivery_fee,v_item_totals
  ) c
  limit 1;

  v_campaign_discount := coalesce(v_campaign_discount,0);
  v_delivery_discount := coalesce(v_delivery_discount,0);
  v_total := greatest(v_subtotal - v_campaign_discount + v_delivery_fee - v_delivery_discount,0);

  return jsonb_build_object(
    'subtotal',v_subtotal,
    'delivery_fee',v_delivery_fee,
    'delivery_distance_km',v_distance,
    'delivery_radius_km',case when v_store.latitude is null then null else v_store.delivery_radius_km end,
    'delivery_needs_location',v_needs_location,
    'campaign_discount',v_campaign_discount,
    'delivery_discount',v_delivery_discount,
    'total',v_total,
    'campaign_id',v_campaign_id,
    'campaign_name',v_campaign_name,
    'campaign_type',v_campaign_type
  );
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
CREATE OR REPLACE FUNCTION public.food_cancel_order(p_order_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
  for update;

  if not found or v_order.buyer_id <> auth.uid() then
    raise exception 'order not found';
  end if;

  if v_order.status <> 'pending_acceptance'
     or v_order.payment_status not in ('pending','issue') then
    raise exception 'order cannot be cancelled by customer';
  end if;

  update public.food_orders
  set status = 'cancelled',
      cancelled_at = now()
  where id = p_order_id;

  insert into public.food_order_events (
    order_id, event_type, from_status, to_status, note, actor_id
  ) values (
    p_order_id,
    'customer_cancelled',
    v_order.status,
    'cancelled',
    nullif(left(trim(coalesce(p_reason,'')),1000),''),
    auth.uid()
  );
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
CREATE OR REPLACE FUNCTION public.food_set_payment_status(p_order_id uuid, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_provider = 'stripe'
     or (v_order.stripe_checkout_session_id is not null and v_order.payment_slip_path is null) then
    raise exception 'stripe payment status is managed by webhook';
  end if;
  if p_status not in ('paid','issue','refunded') then raise exception 'invalid payment status'; end if;

  update public.food_orders
  set payment_status=p_status,
      payment_note=v_note,
      payment_verification_status=case
        when p_status='paid' then 'manual_verified'
        when p_status='issue' then 'rejected'
        else payment_verification_status
      end,
      payment_provider=case when p_status in ('paid','issue') then 'merchant_manual' else payment_provider end,
      payment_verified_at=case when p_status in ('paid','issue') then now() else payment_verified_at end,
      payment_verification_note=case when p_status in ('paid','issue') then v_note else payment_verification_note end,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end,
      refund_status=case when p_status='refunded' then 'refunded' else refund_status end,
      refunded_at=case when p_status='refunded' then coalesce(refunded_at,now()) else refunded_at end,
      refund_updated_by=case when p_status='refunded' then auth.uid() else refund_updated_by end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_' || p_status,v_note,auth.uid());
end;
$function$;
CREATE OR REPLACE FUNCTION public.food_timeout_cancel(p_order_id uuid, p_expected_session_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'service role required';
  end if;

  select * into v_order
  from public.food_orders
  where id=p_order_id
  for update;

  if not found or v_order.source <> 'app'
     or v_order.status <> 'pending_acceptance'
     or v_order.payment_status not in ('pending','issue')
     or v_order.paid_at is not null
     or v_order.payment_due_at is null
     or v_order.payment_due_at > clock_timestamp()
     or v_order.stripe_checkout_session_id is distinct from p_expected_session_id
  then
    return false;
  end if;

  perform set_config('wynos.food_auto_cancel','on',true);
  update public.food_orders
  set status='cancelled', cancelled_at=clock_timestamp()
  where id=v_order.id;
  perform set_config('wynos.food_auto_cancel','off',true);

  insert into public.food_order_events
    (order_id,event_type,from_status,to_status,note,actor_id)
  values
    (v_order.id,'auto_cancelled_unpaid',v_order.status,'cancelled',
     'ระบบยกเลิกอัตโนมัติ: ไม่ชำระเงินภายใน 10 นาที',null);

  return true;
end;
$function$;
CREATE OR REPLACE FUNCTION public.merchant_set_refund_status(p_order_id uuid, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order
  from public.food_orders
  where id=p_order_id
  for update;

  if not found then raise exception 'order not found'; end if;
  if not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_provider = 'stripe' then
    raise exception 'stripe refunds must be processed through the payment gateway';
  end if;
  if v_order.status <> 'cancelled' then
    raise exception 'refund is available after cancellation';
  end if;
  if p_status not in ('pending','refunded','failed') then
    raise exception 'invalid refund status';
  end if;
  if v_order.payment_status not in ('paid','refunded') then
    raise exception 'order is not eligible for refund';
  end if;

  update public.food_orders
  set refund_status=p_status,
      refund_note=v_note,
      refund_requested_at=case
        when p_status='pending' then coalesce(refund_requested_at,now())
        else refund_requested_at
      end,
      refunded_at=case when p_status='refunded' then now() else refunded_at end,
      refund_updated_by=(select auth.uid()),
      payment_status=case when p_status='refunded' then 'refunded' else payment_status end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'refund_' || p_status,v_note,(select auth.uid()));

  if p_status='refunded' and v_order.buyer_id is not null then
    insert into public.notifications(recipient_id,actor_id,type,reason)
    values (
      v_order.buyer_id,null,'system',
      'คืนเงินออเดอร์ #' || v_order.order_number || ' แล้ว'
    );
  end if;
end;
$function$;
CREATE OR REPLACE FUNCTION public.merchant_sales_report(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_week_start date := date_trunc('week', now() at time zone 'Asia/Bangkok')::date;
  v_month_start date := date_trunc('month', now() at time zone 'Asia/Bangkok')::date;
  v_result jsonb;
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  with delivered as (
    select
      o.id,
      coalesce(o.total, 0)::numeric as total,
      (o.created_at at time zone 'Asia/Bangkok')::date as order_day
    from public.food_orders o
    where o.store_id = p_store_id
      and o.status = 'delivered'
  ),
  item_totals as (
    select i.item_name as name, sum(i.quantity)::bigint as quantity
    from delivered d
    join public.food_order_items i on i.order_id = d.id
    group by i.item_name
    order by quantity desc, i.item_name asc
    limit 5
  )
  select jsonb_build_object(
    'today_sales', coalesce((select sum(total) from delivered where order_day = v_today), 0),
    'today_orders', (select count(*) from delivered where order_day = v_today),
    'week_sales', coalesce((select sum(total) from delivered where order_day between v_week_start and v_today), 0),
    'week_orders', (select count(*) from delivered where order_day between v_week_start and v_today),
    'month_sales', coalesce((select sum(total) from delivered where order_day between v_month_start and v_today), 0),
    'month_orders', (select count(*) from delivered where order_day between v_month_start and v_today),
    'total_orders', (select count(*) from delivered),
    'average_order', coalesce((select avg(total) from delivered), 0),
    'best', coalesce(
      (select jsonb_agg(jsonb_build_object('name', name, 'quantity', quantity) order by quantity desc, name asc)
       from item_totals),
      '[]'::jsonb
    )
  ) into v_result;

  return v_result;
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
CREATE OR REPLACE FUNCTION public.food_public_catalog()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when not exists (
      select 1 from public.food_rollout_settings r
      where r.id = true and r.public_enabled = true
    ) then '[]'::jsonb
    else coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'slug', s.slug,
          'name', s.name,
          'description', s.description,
          'cover_path', s.cover_path,
          'logo_path', s.logo_path,
          'address', s.address,
          'delivery_fee', s.delivery_fee,
          'is_open', internal.food_store_effectively_open(s.id, now()),
          'menu', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'id', m.id,
                'store_id', m.store_id,
                'category', m.category,
                'name', m.name,
                'description', m.description,
                'price', m.price,
                'image_path', m.image_path,
                'options', coalesce(m.options, '[]'::jsonb),
                'sold_out_until', m.sold_out_until,
                'daily_stock_limit', m.daily_stock_limit
              ) order by m.sort_order, m.created_at
            )
            from (
              select * from public.food_menu_items mi
              where mi.store_id = s.id and mi.is_available = true
              order by mi.sort_order, mi.created_at
              limit 100
            ) m
          ), '[]'::jsonb)
        ) order by s.created_at
      )
      from (
        select * from public.food_stores fs
        where fs.is_published = true and fs.admin_suspended_at is null
        order by fs.created_at
        limit 60
      ) s
    ), '[]'::jsonb)
  end;
$function$;
CREATE OR REPLACE FUNCTION public.food_submit_store_review(p_order_id uuid, p_rating integer, p_review_text text DEFAULT NULL::text, p_tags text[] DEFAULT '{}'::text[], p_anonymous boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_order public.food_orders%rowtype;
  v_review_id uuid;
  v_text text := nullif(left(btrim(coalesce(p_review_text,'')),500),'');
  v_tags text[];
  v_label text;
begin
  if (select auth.uid()) is null or not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid review rating';
  end if;

  select array(
    select distinct btrim(t)
    from unnest(coalesce(p_tags,'{}'::text[])) as t
    where btrim(t) <> ''
    order by btrim(t)
  ) into v_tags;

  if cardinality(v_tags) > 5
     or not (v_tags <@ array['อร่อย','ปริมาณดี','แพ็กดี','ตรงปก','คุ้มราคา','ส่งเร็ว']::text[]) then
    raise exception 'invalid review tags';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
    and buyer_id = (select auth.uid())
  for share;

  if not found then
    raise exception 'order not found';
  end if;
  if v_order.status <> 'delivered' or v_order.delivered_at is null then
    raise exception 'only delivered orders can be reviewed';
  end if;
  if exists (select 1 from public.food_store_reviews r where r.order_id = p_order_id) then
    raise exception 'order already reviewed';
  end if;

  v_label := case
    when coalesce(p_anonymous,false) then 'ไม่ระบุชื่อ'
    else internal.food_mask_reviewer_name(v_order.recipient_name)
  end;

  insert into public.food_store_reviews(
    order_id, store_id, buyer_id, rating, review_text, tags,
    reviewer_label, is_anonymous
  ) values (
    v_order.id, v_order.store_id, v_order.buyer_id, p_rating, v_text, v_tags,
    v_label, coalesce(p_anonymous,false)
  )
  returning id into v_review_id;

  return v_review_id;
end;
$function$;
drop function public.admin_food_orders_v2(uuid,text,text,integer,text,text);
drop function public.admin_food_fulfillment_summary(date,date);
drop trigger food_fulfillment_store_guard on public.food_stores;
drop trigger food_fulfillment_notify on public.food_orders;
drop policy "Refund slips scoped read" on storage.objects;
drop policy "Refund slips scoped insert" on storage.objects;
drop policy "Refund slips restrict read" on storage.objects;
drop policy "Refund slips restrict insert" on storage.objects;
drop policy "Refund slips immutable update" on storage.objects;
drop policy "Refund slips immutable delete" on storage.objects;
drop function public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer);
drop function public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text);
drop function public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamptz,text);
drop function public.food_request_cancel(uuid,text);
drop function public.food_store_cancel_order(uuid,boolean,text);
drop function public.food_resolve_cancel_request(uuid,boolean,boolean,text);
drop function public.food_store_mark_refunded(uuid,text,text);
drop function public.food_store_directory_v2(text);
drop function internal.food_fulfillment_store_guard();
drop function internal.food_fulfillment_notify();
drop function internal.food_refund_storage_access(text,boolean);
drop function internal.food_validate_fulfillment(uuid,text,text,timestamptz,boolean);
drop function internal.food_pickup_slots(uuid,timestamptz);
drop index public.food_orders_pickup_code_unique;
drop index public.food_orders_refund_owed;
drop index public.food_orders_cancel_requested;
alter table public.food_orders drop constraint food_orders_status_check;
alter table public.food_orders add constraint food_orders_status_check check(status in ('pending_acceptance','preparing','ready_for_delivery','out_for_delivery','delivered','cancelled'));
alter table public.food_orders drop column fulfillment_type,drop column payment_method,drop column pickup_at,drop column pickup_code,drop column picked_up_at,drop column cancel_requested_at,drop column cancel_request_note,drop column refund_slip_path,drop column refunded_by_store_at;
alter table public.food_stores drop column pickup_enabled,drop column delivery_enabled,drop column cod_enabled,drop column prep_minutes;
drop sequence public.food_pickup_code_sequence;
notify pgrst, 'reload schema';
CREATE OR REPLACE FUNCTION internal.food_set_scheduled_order(p_order_id uuid, p_scheduled_for timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_order public.food_orders%rowtype;
  v_min timestamptz;
  v_max timestamptz;
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  if p_scheduled_for is null then raise exception 'scheduled time is required'; end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id and buyer_id = auth.uid()
  for update;
  if not found then raise exception 'order not found'; end if;

  select * into v_store from public.food_stores where id = v_order.store_id;
  if not found then raise exception 'store not found'; end if;
  if not v_store.scheduled_orders_enabled then raise exception 'scheduled orders are not enabled'; end if;

  v_min := now() + make_interval(mins => v_store.scheduled_min_notice_minutes);
  v_max := now() + make_interval(days => v_store.scheduled_max_days);
  if p_scheduled_for < v_min then raise exception 'scheduled time is too soon'; end if;
  if p_scheduled_for > v_max then raise exception 'scheduled time is too far'; end if;
  if not internal.food_store_effectively_open(v_order.store_id, p_scheduled_for) then
    raise exception 'store is closed at scheduled time';
  end if;

  update public.food_orders
  set scheduled_for = p_scheduled_for
  where id = v_order.id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (
    v_order.id,
    'scheduled',
    left('นัดรับ/จัดส่ง ' || to_char(p_scheduled_for at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI'),1000),
    auth.uid()
  );
end;
$function$
;
drop function internal.food_fulfillment_now();
commit;
