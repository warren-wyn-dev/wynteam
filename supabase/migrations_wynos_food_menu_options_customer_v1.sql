-- WYNOS Food: validate customer menu options and price add-ons on the server.
-- The client only sends option IDs. Names and prices are always resolved from
-- food_menu_items.options so a customer cannot forge an add-on price.

create or replace function internal.food_resolve_menu_options(
  p_item_options jsonb,
  p_selected jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_groups jsonb := case when jsonb_typeof(coalesce(p_item_options, '[]'::jsonb)) = 'array' then coalesce(p_item_options, '[]'::jsonb) else '[]'::jsonb end;
  v_selected jsonb := case when jsonb_typeof(coalesce(p_selected, '[]'::jsonb)) = 'array' then coalesce(p_selected, '[]'::jsonb) else '[]'::jsonb end;
  v_group jsonb;
  v_entry jsonb;
  v_choice jsonb;
  v_group_id text;
  v_choice_id text;
  v_count integer;
  v_distinct_count integer;
  v_required boolean;
  v_max_select integer;
  v_price numeric(10,2);
  v_extra numeric(10,2) := 0;
  v_normalized jsonb := '[]'::jsonb;
begin
  if jsonb_array_length(v_selected) > 40 then
    raise exception 'too many menu options';
  end if;

  for v_group in select value from jsonb_array_elements(v_groups)
  loop
    v_group_id := nullif(v_group->>'id', '');
    if v_group_id is null then
      continue;
    end if;

    v_required := coalesce((v_group->>'required')::boolean, false);
    v_max_select := greatest(1, least(20, coalesce((v_group->>'max_select')::integer, 1)));

    select count(*), count(distinct value->>'choice_id')
      into v_count, v_distinct_count
    from jsonb_array_elements(v_selected)
    where value->>'group_id' = v_group_id;

    if v_count <> v_distinct_count then
      raise exception 'duplicate menu option';
    end if;
    if v_count > v_max_select then
      raise exception 'too many choices for menu option group';
    end if;
    if v_required and v_count = 0 then
      raise exception 'required menu option missing';
    end if;

    for v_entry in
      select value
      from jsonb_array_elements(v_selected)
      where value->>'group_id' = v_group_id
    loop
      v_choice_id := nullif(v_entry->>'choice_id', '');
      if v_choice_id is null then
        raise exception 'invalid menu option';
      end if;

      select value into v_choice
      from jsonb_array_elements(
        case when jsonb_typeof(coalesce(v_group->'choices', '[]'::jsonb)) = 'array'
          then coalesce(v_group->'choices', '[]'::jsonb)
          else '[]'::jsonb
        end
      )
      where value->>'id' = v_choice_id
      limit 1;

      if v_choice is null then
        raise exception 'unknown menu option';
      end if;

      v_price := greatest(0, coalesce((v_choice->>'price')::numeric, 0));
      v_extra := v_extra + v_price;
      v_normalized := v_normalized || jsonb_build_array(jsonb_build_object(
        'group_id', v_group_id,
        'group_name', coalesce(v_group->>'name', ''),
        'choice_id', v_choice_id,
        'choice_name', coalesce(v_choice->>'name', ''),
        'price', v_price
      ));
    end loop;
  end loop;

  if exists (
    select 1
    from jsonb_array_elements(v_selected) s
    where not exists (
      select 1
      from jsonb_array_elements(v_groups) g
      where g->>'id' = s->>'group_id'
    )
  ) then
    raise exception 'unknown menu option group';
  end if;

  return jsonb_build_object(
    'selected_options', v_normalized,
    'extra_price', v_extra
  );
end;
$$;

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
  v_resolved jsonb;
  v_line_unit numeric(10,2);
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

    v_resolved := internal.food_resolve_menu_options(v_item.options, v_line->'selected_options');
    v_line_unit := v_item.price + coalesce((v_resolved->>'extra_price')::numeric, 0);
    v_subtotal := v_subtotal + (v_line_unit * v_qty);
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_line_unit * v_qty)
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
  v_resolved jsonb;
  v_selected jsonb;
  v_line_unit numeric(10,2);
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

    v_resolved := internal.food_resolve_menu_options(v_item.options, v_line->'selected_options');
    v_line_unit := v_item.price + coalesce((v_resolved->>'extra_price')::numeric, 0);
    v_subtotal := v_subtotal + (v_line_unit * v_qty);
    v_count := v_count + 1;
    v_item_totals := v_item_totals || jsonb_build_object(
      v_menu_id::text,
      coalesce((v_item_totals->>v_menu_id::text)::numeric,0) + (v_line_unit * v_qty)
    );
  end loop;

  if v_count=0 or v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

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

    v_resolved := internal.food_resolve_menu_options(v_item.options, v_line->'selected_options');
    v_selected := v_resolved->'selected_options';
    v_line_unit := v_item.price + coalesce((v_resolved->>'extra_price')::numeric, 0);

    insert into public.food_order_items(
      order_id,menu_item_id,item_name,unit_price,quantity,selected_options,item_note
    ) values (
      v_order_id,
      v_item.id,
      v_item.name,
      v_line_unit,
      v_qty,
      v_selected,
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
