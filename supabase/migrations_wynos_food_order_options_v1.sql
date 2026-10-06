-- WYN-218: WYNOS Food order integrity (QA findings on food.wynos.online).
--
-- * Menu options are resolved on the server. food_quote_order and
--   food_create_order used to ignore option prices and save the client's
--   selected_options as-is, so add-ons were never charged and option names
--   could be forged. Each line now sends only group_id + choice_id; the
--   server checks them against food_menu_items.options (unknown or
--   duplicate choice, required group, max_select), adds the choice prices to
--   the unit price, and saves the names and prices it read from the menu.
-- * food_create_order limits each buyer to 5 orders per 10 minutes and 3
--   orders waiting for acceptance per store. Developer accounts are exempt.
-- * food_submit_payment only accepts a slip while payment_status is pending
--   or issue, so a buyer cannot reset a payment the store already marked
--   paid or refunded.
--
-- Replaces three RPCs with the same signatures and adds one internal helper.
-- No table or data changes.
-- Rollback (Founder, SQL editor): re-run food_quote_order / food_create_order
-- from migrations_wynos_food_delivery_zone_v1.sql and food_submit_payment from
-- migrations_wynos_merchant_payment_core_v1.sql, then
--   drop function internal.food_resolve_menu_options(jsonb, jsonb);

-- 1. Option resolver -------------------------------------------------------
-- p_groups is food_menu_items.options:
--   [{id, name, required, max_select, choices: [{id, name, price}]}]
-- p_selected is the client's list of {group_id, choice_id}; any other keys
-- are ignored. Returns the selection in menu order with names and prices
-- from the menu, and the total surcharge. Matches foodCartLineOptionsValid
-- in web/lib/food-customer.ts.
create or replace function internal.food_resolve_menu_options(
  p_groups jsonb,
  p_selected jsonb
)
returns table(options jsonb, surcharge numeric)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_groups jsonb := case when jsonb_typeof(p_groups) = 'array' then p_groups else '[]'::jsonb end;
  v_selected jsonb;
  v_pick jsonb;
  v_group jsonb;
  v_keys text[] := '{}';
  v_key text;
  v_count integer;
  v_max integer;
  v_options jsonb := '[]'::jsonb;
  v_surcharge numeric := 0;
  v_choice jsonb;
  v_price numeric;
begin
  if p_selected is null or jsonb_typeof(p_selected) = 'null' then
    v_selected := '[]'::jsonb;
  elsif jsonb_typeof(p_selected) <> 'array' or jsonb_array_length(p_selected) > 100 then
    raise exception 'invalid menu option';
  else
    v_selected := p_selected;
  end if;

  -- Every pick must name a real choice of a real group, once.
  for v_pick in select value from jsonb_array_elements(v_selected)
  loop
    if jsonb_typeof(v_pick) <> 'object'
       or coalesce(v_pick->>'group_id', '') = ''
       or coalesce(v_pick->>'choice_id', '') = '' then
      raise exception 'invalid menu option';
    end if;
    v_key := (v_pick->>'group_id') || chr(31) || (v_pick->>'choice_id');
    if v_key = any(v_keys) then
      raise exception 'invalid menu option';
    end if;
    v_keys := v_keys || v_key;
    if not exists (
      select 1
      from jsonb_array_elements(v_groups) g
      cross join lateral jsonb_array_elements(
        case when jsonb_typeof(g.value->'choices') = 'array' then g.value->'choices' else '[]'::jsonb end
      ) c
      where g.value->>'id' = v_pick->>'group_id'
        and c.value->>'id' = v_pick->>'choice_id'
    ) then
      raise exception 'invalid menu option';
    end if;
  end loop;

  -- Group rules, then build the stored selection in menu order.
  for v_group in select value from jsonb_array_elements(v_groups)
  loop
    select count(*) into v_count
    from jsonb_array_elements(v_selected) s
    where s.value->>'group_id' = v_group->>'id';

    v_max := greatest(1, least(20, coalesce(
      case when v_group->>'max_select' ~ '^\s*[0-9]{1,4}(\.[0-9]+)?\s*$' then floor((v_group->>'max_select')::numeric)::integer end,
      1)));
    if v_count > v_max then
      raise exception 'too many menu options selected';
    end if;
    if v_group->'required' = 'true'::jsonb and v_count = 0 then
      raise exception 'required menu option missing';
    end if;

    if v_count > 0 then
      for v_choice in
        select c.value
        from jsonb_array_elements(
          case when jsonb_typeof(v_group->'choices') = 'array' then v_group->'choices' else '[]'::jsonb end
        ) c
        where exists (
          select 1 from jsonb_array_elements(v_selected) s
          where s.value->>'group_id' = v_group->>'id'
            and s.value->>'choice_id' = c.value->>'id'
        )
      loop
        v_price := greatest(0, coalesce(
          case when v_choice->>'price' ~ '^\s*[0-9]{1,7}(\.[0-9]+)?\s*$' then (v_choice->>'price')::numeric end,
          0));
        v_surcharge := v_surcharge + v_price;
        v_options := v_options || jsonb_build_array(jsonb_build_object(
          'group_id', v_group->>'id',
          'group_name', v_group->>'name',
          'choice_id', v_choice->>'id',
          'choice_name', v_choice->>'name',
          'price', v_price
        ));
      end loop;
    end if;
  end loop;

  return query select v_options, round(v_surcharge, 2);
end;
$$;

revoke all on function internal.food_resolve_menu_options(jsonb, jsonb) from public, anon, authenticated;

-- 2. Quote and order RPCs ------------------------------------------------
-- Same as migrations_wynos_food_delivery_zone_v1.sql, plus server-resolved
-- menu options and, in food_create_order, the order rate limit.

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
$$;

revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision) from public, anon;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision) to authenticated;

-- 3. Payment slip ----------------------------------------------------------
-- Same as migrations_wynos_merchant_payment_core_v1.sql, plus the
-- payment_status guard.

create or replace function public.food_submit_payment(p_order_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  -- WYN-218: a slip is accepted only while payment is still owed. Once the
  -- store marks it paid or refunded the buyer cannot reset it.
  if v_order.payment_status not in ('pending','issue') then
    raise exception 'payment already submitted';
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
$$;


revoke all on function public.food_submit_payment(uuid,text) from public, anon;
grant execute on function public.food_submit_payment(uuid,text) to authenticated;
