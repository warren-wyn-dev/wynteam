-- WYN-196: WYNOS Food delivery zone and distance-based delivery fee.
--
-- Founder (2026-10-03): stores deliver up to 5 km by default, the fee grows
-- with distance, and customers give their location with "use current
-- location" or a place search.
--
-- * food_stores gets a pinned location, a delivery radius (default 5 km), the
--   distance included in the base fee (default 2 km) and a per-km fee.
--   delivery_fee stays the base fee.
-- * food_customer_addresses and food_orders keep the delivery coordinates.
-- * food_quote_order / food_create_order take optional coordinates. A store
--   without a pinned location keeps today's flat fee and has no radius, so
--   nothing changes until its owner pins the store.
-- * fee = delivery_fee + ceil(max(distance - base_km, 0) * fee_per_km) baht,
--   distance is the straight-line (haversine) distance in km.
--
-- Additive: new nullable/defaulted columns, one helper, two replaced RPCs (the
-- old signatures are dropped so the radius cannot be bypassed).
-- Rollback: unpinning every store (latitude/longitude = null) restores the
-- flat fee immediately and is safe with the new web deployed. A full rollback
-- must revert the WYN-196 web commit first, then drop the (…, double
-- precision, double precision) RPCs and re-run food_quote_order /
-- food_create_order from migrations_wynos_merchant_campaign_center_v1.sql and
-- food_upsert_customer_address from
-- migrations_wynos_food_customer_access_gate_v2.sql; the columns can stay.

alter table public.food_stores
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists delivery_radius_km numeric(5,2) not null default 5,
  add column if not exists delivery_base_km numeric(5,2) not null default 2,
  add column if not exists delivery_fee_per_km numeric(10,2) not null default 0;

alter table public.food_stores drop constraint if exists food_stores_location_pair;
alter table public.food_stores add constraint food_stores_location_pair check (
  (latitude is null and longitude is null)
  or (latitude is not null and longitude is not null
      and latitude between -90 and 90 and longitude between -180 and 180)
);
alter table public.food_stores drop constraint if exists food_stores_delivery_zone_range;
alter table public.food_stores add constraint food_stores_delivery_zone_range check (
  delivery_radius_km > 0 and delivery_radius_km <= 50
  and delivery_base_km >= 0 and delivery_base_km <= 50
  and delivery_fee_per_km >= 0 and delivery_fee_per_km <= 1000
);

alter table public.food_customer_addresses
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;
alter table public.food_customer_addresses drop constraint if exists food_customer_addresses_location_pair;
alter table public.food_customer_addresses add constraint food_customer_addresses_location_pair check (
  (latitude is null and longitude is null)
  or (latitude is not null and longitude is not null
      and latitude between -90 and 90 and longitude between -180 and 180)
);

alter table public.food_orders
  add column if not exists delivery_latitude double precision,
  add column if not exists delivery_longitude double precision,
  add column if not exists delivery_distance_km numeric(6,2);

-- Straight-line distance in km (haversine, mean Earth radius 6371 km).
create or replace function internal.food_distance_km(
  p_lat1 double precision, p_lng1 double precision,
  p_lat2 double precision, p_lng2 double precision
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round((6371 * 2 * asin(least(1, sqrt(
    power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2)
  ))))::numeric, 2);
$$;

-- Delivery fee for one store and one drop-off point. A store without a
-- pinned location keeps its flat fee (distance null). A pinned store needs
-- valid coordinates inside its radius.
create or replace function internal.food_delivery_fee(
  p_store_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns table(distance_km numeric, delivery_fee numeric)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_distance numeric;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store is not accepting orders';
  end if;
  if v_store.latitude is null then
    return query select null::numeric, v_store.delivery_fee;
    return;
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'delivery location required';
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
$$;

revoke all on function internal.food_distance_km(double precision,double precision,double precision,double precision) from public, anon, authenticated;
revoke all on function internal.food_delivery_fee(uuid,double precision,double precision) from public, anon, authenticated;

drop function if exists public.food_quote_order(uuid,jsonb);
drop function if exists public.food_create_order(uuid,text,text,text,text,jsonb);

create or replace function public.food_quote_order(
  p_store_id uuid,
  p_items jsonb,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

    v_subtotal := v_subtotal + (v_item.price * v_qty);
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_item.price * v_qty)
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
$$;

revoke all on function public.food_quote_order(uuid,jsonb,double precision,double precision) from public, anon;
grant execute on function public.food_quote_order(uuid,jsonb,double precision,double precision) to authenticated;

create or replace function public.food_create_order(
  p_store_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
  v_item_totals jsonb := '{}'::jsonb;
  v_campaign_id uuid;
  v_campaign_name text;
  v_campaign_type text;
  v_campaign_discount numeric(10,2) := 0;
  v_delivery_discount numeric(10,2) := 0;
  v_delivery_fee numeric(10,2);
  v_distance numeric(6,2);
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

    v_subtotal := v_subtotal + (v_item.price * v_qty);
    v_count := v_count + 1;
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_item.price * v_qty)
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

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1,least(99,coalesce((v_line->>'quantity')::integer,1)));

    select * into v_item
    from public.food_menu_items
    where id=v_menu_id and store_id=p_store_id;

    insert into public.food_order_items(
      order_id,menu_item_id,item_name,unit_price,quantity,selected_options,item_note
    ) values (
      v_order_id,
      v_item.id,
      v_item.name,
      v_item.price,
      v_qty,
      case
        when jsonb_typeof(v_line->'selected_options')='array' then v_line->'selected_options'
        else '[]'::jsonb
      end,
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
$$;

revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision) from public, anon;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision) to authenticated;


drop function if exists public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean);
create or replace function public.food_upsert_customer_address(
  p_address_id uuid,
  p_label text,
  p_recipient_name text,
  p_recipient_phone text,
  p_address text,
  p_delivery_note text default null,
  p_is_default boolean default false,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(trim(p_label)),0) = 0
     or coalesce(char_length(trim(p_recipient_name)),0) = 0
     or coalesce(char_length(trim(p_recipient_phone)),0) = 0
     or coalesce(char_length(trim(p_address)),0) = 0 then
    raise exception 'address information is required';
  end if;

  -- WYN-196: the delivery pin is optional but must be a full, valid pair.
  if (p_latitude is null) <> (p_longitude is null)
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'invalid delivery location';
  end if;

  if p_is_default then
    update public.food_customer_addresses
    set is_default = false
    where user_id = auth.uid() and is_default;
  end if;

  if p_address_id is null then
    insert into public.food_customer_addresses (
      user_id, label, recipient_name, recipient_phone, address, delivery_note, is_default,
      latitude, longitude
    ) values (
      auth.uid(),
      left(trim(p_label),80),
      left(trim(p_recipient_name),120),
      left(trim(p_recipient_phone),50),
      left(trim(p_address),800),
      nullif(left(trim(coalesce(p_delivery_note,'')),500),''),
      p_is_default,
      p_latitude,
      p_longitude
    )
    returning id into v_id;
  else
    update public.food_customer_addresses
    set label = left(trim(p_label),80),
        recipient_name = left(trim(p_recipient_name),120),
        recipient_phone = left(trim(p_recipient_phone),50),
        address = left(trim(p_address),800),
        delivery_note = nullif(left(trim(coalesce(p_delivery_note,'')),500),''),
        is_default = p_is_default,
        latitude = p_latitude,
        longitude = p_longitude
    where id = p_address_id and user_id = auth.uid()
    returning id into v_id;

    if v_id is null then raise exception 'address not found'; end if;
  end if;

  if not exists (
    select 1
    from public.food_customer_addresses
    where user_id = auth.uid() and is_default
  ) then
    update public.food_customer_addresses
    set is_default = true
    where id = v_id;
  end if;

  return v_id;
end;
$$;

revoke all on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean,double precision,double precision) from public, anon;
grant execute on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean,double precision,double precision) to authenticated;
