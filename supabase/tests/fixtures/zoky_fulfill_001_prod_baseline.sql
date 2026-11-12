-- Live production definitions (read-only dump, GitHub run 40318273032, 2026-10-26)
-- that ZOKY-FULFILL-001 builds on but does not redefine. Test fixture only:
-- loaded by supabase/tests/zoky_fulfill_001_test.sh against stub tables.

CREATE OR REPLACE FUNCTION internal.food_schedule_day_key(p_isodow integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select (array['mon','tue','wed','thu','fri','sat','sun'])[greatest(1, least(7, p_isodow))];
$function$;

CREATE OR REPLACE FUNCTION internal.food_slot_open(p_slot jsonb, p_local_time time without time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
declare
  v_open time;
  v_close time;
begin
  if p_slot is null or coalesce((p_slot->>'enabled')::boolean, false) = false then
    return false;
  end if;
  begin
    v_open := (p_slot->>'open')::time;
    v_close := (p_slot->>'close')::time;
  exception when others then
    return false;
  end;
  if v_open = v_close then
    return true;
  end if;
  if v_close > v_open then
    return p_local_time >= v_open and p_local_time < v_close;
  end if;
  return p_local_time >= v_open;
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_store_effectively_open(p_store_id uuid, p_at timestamp with time zone DEFAULT now())
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_store public.food_stores%rowtype;
  v_local timestamp;
  v_date date;
  v_time time;
  v_dow integer;
  v_today jsonb;
  v_prev jsonb;
  v_prev_open time;
  v_prev_close time;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found or not v_store.is_open or v_store.admin_suspended_at is not null then
    return false;
  end if;

  if v_store.temporary_closed_until is not null and v_store.temporary_closed_until > p_at then
    return false;
  end if;

  v_local := p_at at time zone 'Asia/Bangkok';
  v_date := v_local::date;
  v_time := v_local::time;
  v_dow := extract(isodow from v_local)::integer;

  if v_date = any(coalesce(v_store.special_closed_dates, '{}'::date[])) then
    return false;
  end if;

  -- Legacy fallback: a store with no structured weekly schedule keeps using
  -- the manual is_open flag exactly as before.
  if v_store.business_schedule = '{}'::jsonb
     or jsonb_typeof(v_store.business_schedule->'weekly') <> 'object' then
    return true;
  end if;

  v_today := v_store.business_schedule->'weekly'->internal.food_schedule_day_key(v_dow);
  if internal.food_slot_open(v_today, v_time) then
    return true;
  end if;

  -- Previous-day overnight slot, e.g. 18:00–02:00.
  v_prev := v_store.business_schedule->'weekly'->internal.food_schedule_day_key(case when v_dow = 1 then 7 else v_dow - 1 end);
  if v_prev is not null and coalesce((v_prev->>'enabled')::boolean, false) then
    begin
      v_prev_open := (v_prev->>'open')::time;
      v_prev_close := (v_prev->>'close')::time;
      if v_prev_close < v_prev_open and v_time < v_prev_close then
        return true;
      end if;
    exception when others then
      null;
    end;
  end if;

  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION internal.food_distance_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO ''
AS $function$
  select round((6371 * 2 * asin(least(1, sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
  ))))::numeric, 2);
$function$;

CREATE OR REPLACE FUNCTION internal.food_order_guard_store_schedule()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not internal.food_store_effectively_open(new.store_id, now()) then
    raise exception 'store is closed';
  end if;
  return new;
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

CREATE OR REPLACE FUNCTION public.food_quote_order_v2(p_store_id uuid, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_coupon_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_quote jsonb;
  v_coupon public.food_coupon_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_coupon_code,'')));
  v_applied boolean := false;
begin
  if length(v_code)>0 then
    if v_code !~ '^[A-Z0-9][A-Z0-9_-]{3,23}$' then
      raise exception 'invalid_coupon_code';
    end if;
    select * into v_coupon from public.food_coupon_codes
    where code=v_code and is_active and starts_at<=now()
      and (ends_at is null or ends_at>now());
    if not found then raise exception 'coupon_unavailable'; end if;
  end if;
  perform set_config('wyn.food_coupon_code',v_code,true);
  v_quote := public.food_quote_order(p_store_id,p_items,p_latitude,p_longitude);
  if v_code <> '' then
    select exists(
      select 1 from public.food_campaigns c
      where c.id=(v_quote->>'campaign_id')::uuid
        and c.platform_campaign_id=v_coupon.platform_campaign_id
    ) into v_applied;
    if not v_applied then
      raise exception 'coupon_not_applicable_or_better_automatic_discount';
    end if;
  end if;
  return v_quote || jsonb_build_object(
     'coupon_code', nullif(v_code,''), 'coupon_applied',v_applied
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.food_create_order_v2(p_store_id uuid, p_recipient_name text, p_recipient_phone text, p_shipping_address text, p_customer_note text, p_items jsonb, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_coupon_code text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_coupon public.food_coupon_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_coupon_code,'')));
  v_id uuid;
  v_chosen uuid;
  v_used integer;
begin
  if v_code = '' then
    return public.food_create_order(p_store_id,p_recipient_name,p_recipient_phone,
      p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude);
  end if;
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if v_code !~ '^[A-Z0-9][A-Z0-9_-]{3,23}$' then raise exception 'invalid_coupon_code'; end if;
  -- Serialize redemption for this code. The lock lasts through both the
  -- original order creation and this function's redemption insert.
  select * into v_coupon from public.food_coupon_codes
   where code=v_code for update;
  if not found or not v_coupon.is_active or v_coupon.starts_at>now()
    or (v_coupon.ends_at is not null and v_coupon.ends_at<=now()) then
    raise exception 'coupon_unavailable';
  end if;
  select count(*) into v_used from public.food_coupon_redemptions r
    where r.coupon_id=v_coupon.id and internal.food_coupon_usage_active(r.order_id);
  if v_coupon.max_total_uses is not null and v_used>=v_coupon.max_total_uses then
    raise exception 'coupon_sold_out';
  end if;
  select count(*) into v_used from public.food_coupon_redemptions r
    where r.coupon_id=v_coupon.id and r.user_id=auth.uid()
      and internal.food_coupon_usage_active(r.order_id);
  if v_used>=v_coupon.max_uses_per_user then raise exception 'coupon_already_used'; end if;
  perform set_config('wyn.food_coupon_code',v_code,true);
  v_id:=public.food_create_order(p_store_id,p_recipient_name,p_recipient_phone,
        p_shipping_address,p_customer_note,p_items,p_latitude,p_longitude);
  select c.platform_campaign_id into v_chosen from public.food_orders o
    left join public.food_campaigns c on c.id=o.campaign_id
    where o.id=v_id;
  if v_chosen is distinct from v_coupon.platform_campaign_id then
    raise exception 'coupon_not_applicable_or_better_automatic_discount';
  end if;
  insert into public.food_coupon_redemptions(order_id,coupon_id,user_id)
    values(v_id,v_coupon.id,auth.uid());
  return v_id;
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

CREATE OR REPLACE FUNCTION internal.food_order_notify()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'internal'
AS $function$
declare
  v_reason text;
  v_account_id uuid;
begin
  select s.merchant_account_id into v_account_id
  from public.food_stores s
  where s.id = new.store_id;

  if tg_op = 'INSERT' and new.source in ('app','social') then
    v_reason := 'WYNOS Merchant · ออเดอร์ใหม่ #' || new.order_number || ' · ฿' || trim(to_char(new.total, 'FM999999990.00'));

    if v_account_id is not null then
      insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
      select v_account_id, mm.user_id, 'order', v_reason
      from public.merchant_memberships mm
      where mm.merchant_account_id=v_account_id and mm.active;
    end if;

    insert into public.notifications(recipient_id, actor_id, type, reason)
    select fs.user_id, null, 'system', v_reason
    from public.food_staff fs
    where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
  elsif tg_op = 'UPDATE' and new.payment_status is distinct from old.payment_status then
    if new.payment_status = 'submitted' then
      v_reason := 'WYNOS Merchant · ลูกค้าส่งสลิป #' || new.order_number;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'payment', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id=v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'paid' then
      if new.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (new.buyer_id, null, 'system', 'ชำระเงินออเดอร์ #' || new.order_number || ' สำเร็จแล้ว');
      end if;
      v_reason := 'WYNOS Merchant · ชำระเงินแล้ว #' || new.order_number;
      if v_account_id is not null then
        insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
        select v_account_id, mm.user_id, 'payment', v_reason
        from public.merchant_memberships mm
        where mm.merchant_account_id=v_account_id and mm.active;
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'issue' and new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (
        new.buyer_id, null, 'system',
        coalesce(new.payment_verification_note, new.payment_note, 'สลิปออเดอร์ #' || new.order_number || ' ต้องตรวจสอบอีกครั้ง')
      );
    end if;
  end if;

  return new;
end;
$function$;
