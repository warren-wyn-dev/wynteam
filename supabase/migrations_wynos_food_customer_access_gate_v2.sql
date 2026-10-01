-- WYNOS Food customer access gate v2
-- Closed Developer Preview by default, while keeping a single explicit database
-- switch for a future public launch. This supersedes the temporary hard-lock
-- policies applied during preview QA.

create or replace function public.food_customer_access_enabled()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.food_is_permanent_account()
    and (
      public.is_developer_account()
      or public.food_public_access_enabled()
    );
$$;

revoke all on function public.food_customer_access_enabled() from public, anon;
grant execute on function public.food_customer_access_enabled() to authenticated;

drop policy if exists "Food stores visible to customers and staff" on public.food_stores;
drop policy if exists "Food stores visible to developers and staff" on public.food_stores;
create policy "Food stores visible by rollout gate"
on public.food_stores for select to authenticated
using (
  public.food_has_merchant_access(id)
  or public.is_developer_account()
  or (
    is_published
    and public.food_public_access_enabled()
    and public.food_is_permanent_account()
  )
);

drop policy if exists "Food menu visible to customers and staff" on public.food_menu_items;
drop policy if exists "Food menu visible to developers and staff" on public.food_menu_items;
create policy "Food menu visible by rollout gate"
on public.food_menu_items for select to authenticated
using (
  public.food_has_merchant_access(store_id)
  or public.is_developer_account()
  or (
    is_available
    and public.food_public_access_enabled()
    and public.food_is_permanent_account()
    and exists (
      select 1
      from public.food_stores s
      where s.id = food_menu_items.store_id
        and s.is_published
    )
  )
);

create or replace function public.food_can_view_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.food_orders o
    where o.id = p_order_id
      and (
        public.food_has_merchant_access(o.store_id)
        or (
          o.buyer_id = auth.uid()
          and public.food_customer_access_enabled()
        )
      )
  );
$$;

revoke all on function public.food_can_view_order(uuid) from public, anon;
grant execute on function public.food_can_view_order(uuid) to authenticated;

drop policy if exists "Food orders visible to buyer and merchant" on public.food_orders;
drop policy if exists "Food orders visible to developer buyer and merchant" on public.food_orders;
create policy "Food orders visible by rollout gate"
on public.food_orders for select to authenticated
using (
  public.food_has_merchant_access(store_id)
  or (
    buyer_id = auth.uid()
    and public.food_customer_access_enabled()
  )
);

drop policy if exists "Food order items visible to buyer and merchant" on public.food_order_items;
drop policy if exists "Food order items visible to developer buyer and merchant" on public.food_order_items;
create policy "Food order items visible by rollout gate"
on public.food_order_items for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food order events visible to buyer and merchant" on public.food_order_events;
drop policy if exists "Food order events visible to developer buyer and merchant" on public.food_order_events;
create policy "Food order events visible by rollout gate"
on public.food_order_events for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food delivery proofs visible to buyer and merchant" on public.food_delivery_proofs;
drop policy if exists "Food delivery proofs visible to developer buyer and merchant" on public.food_delivery_proofs;
create policy "Food delivery proofs visible by rollout gate"
on public.food_delivery_proofs for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food customer addresses own rows" on public.food_customer_addresses;
drop policy if exists "Food customer addresses developer own rows" on public.food_customer_addresses;
create policy "Food customer addresses visible by rollout gate"
on public.food_customer_addresses for select to authenticated
using (
  user_id = auth.uid()
  and public.food_customer_access_enabled()
);

create or replace function public.food_upsert_customer_address(
  p_address_id uuid,
  p_label text,
  p_recipient_name text,
  p_recipient_phone text,
  p_address text,
  p_delivery_note text default null,
  p_is_default boolean default false
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

  if p_is_default then
    update public.food_customer_addresses
    set is_default = false
    where user_id = auth.uid() and is_default;
  end if;

  if p_address_id is null then
    insert into public.food_customer_addresses (
      user_id, label, recipient_name, recipient_phone, address, delivery_note, is_default
    ) values (
      auth.uid(),
      left(trim(p_label),80),
      left(trim(p_recipient_name),120),
      left(trim(p_recipient_phone),50),
      left(trim(p_address),800),
      nullif(left(trim(coalesce(p_delivery_note,'')),500),''),
      p_is_default
    )
    returning id into v_id;
  else
    update public.food_customer_addresses
    set label = left(trim(p_label),80),
        recipient_name = left(trim(p_recipient_name),120),
        recipient_phone = left(trim(p_recipient_phone),50),
        address = left(trim(p_address),800),
        delivery_note = nullif(left(trim(coalesce(p_delivery_note,'')),500),''),
        is_default = p_is_default
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

create or replace function public.food_delete_customer_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_was_default boolean := false;
  v_next uuid;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select is_default into v_was_default
  from public.food_customer_addresses
  where id = p_address_id and user_id = auth.uid();

  if not found then raise exception 'address not found'; end if;

  delete from public.food_customer_addresses
  where id = p_address_id and user_id = auth.uid();

  if v_was_default then
    select id into v_next
    from public.food_customer_addresses
    where user_id = auth.uid()
    order by created_at desc
    limit 1;

    if v_next is not null then
      update public.food_customer_addresses
      set is_default = true
      where id = v_next;
    end if;
  end if;
end;
$$;

create or replace function public.food_cancel_order(
  p_order_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.food_create_order(
  p_store_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_line jsonb;
  v_order_id uuid;
  v_menu_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2) := 0;
  v_total numeric(10,2);
  v_count integer := 0;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(trim(p_recipient_name)),0) = 0
     or coalesce(char_length(trim(p_recipient_phone)),0) = 0
     or coalesce(char_length(trim(p_shipping_address)),0) = 0 then
    raise exception 'recipient information is required';
  end if;

  if jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store
  from public.food_stores
  where id = p_store_id;

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

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    begin
      v_menu_id := (v_line->>'menu_item_id')::uuid;
      v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));
    exception when others then
      raise exception 'invalid order item';
    end;

    select * into v_item
    from public.food_menu_items
    where id = v_menu_id
      and store_id = p_store_id
      and is_available;

    if not found then
      raise exception 'menu item is unavailable';
    end if;

    v_subtotal := v_subtotal + (v_item.price * v_qty);
    v_count := v_count + 1;
  end loop;

  if v_count = 0 or v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

  v_total := v_subtotal + v_store.delivery_fee;

  insert into public.food_orders (
    store_id, buyer_id, created_by, source, status, payment_status,
    recipient_name, recipient_phone, shipping_address, customer_note,
    subtotal, delivery_fee, total
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
    v_store.delivery_fee,
    v_total
  )
  returning id into v_order_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));

    select * into v_item
    from public.food_menu_items
    where id = v_menu_id
      and store_id = p_store_id;

    insert into public.food_order_items (
      order_id, menu_item_id, item_name, unit_price, quantity, selected_options, item_note
    ) values (
      v_order_id,
      v_item.id,
      v_item.name,
      v_item.price,
      v_qty,
      case
        when jsonb_typeof(v_line->'selected_options') = 'array' then v_line->'selected_options'
        else '[]'::jsonb
      end,
      nullif(left(trim(coalesce(v_line->>'note','')),500),'')
    );
  end loop;

  insert into public.food_order_events (
    order_id, event_type, to_status, note, actor_id
  ) values (
    v_order_id,
    'created',
    'pending_acceptance',
    'สร้างคำสั่งซื้อ',
    auth.uid()
  );

  return v_order_id;
end;
$$;

create or replace function public.food_submit_payment(p_order_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id;

  if not found or v_order.buyer_id <> auth.uid() then
    raise exception 'order not found';
  end if;

  if v_order.status in ('delivered','cancelled') then
    raise exception 'order is closed';
  end if;

  if p_slip_path is null
     or p_slip_path not like (auth.uid()::text || '/slips/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status = 'submitted',
      payment_slip_path = p_slip_path,
      payment_note = null
  where id = p_order_id;

  insert into public.food_order_events (
    order_id, event_type, note, actor_id
  ) values (
    p_order_id,
    'payment_submitted',
    'ลูกค้าแนบหลักฐานการชำระเงิน',
    auth.uid()
  );
end;
$$;

revoke all on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean) from public, anon;
revoke all on function public.food_delete_customer_address(uuid) from public, anon;
revoke all on function public.food_cancel_order(uuid,text) from public, anon;
revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon;
revoke all on function public.food_submit_payment(uuid,text) from public, anon;

grant execute on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean) to authenticated;
grant execute on function public.food_delete_customer_address(uuid) to authenticated;
grant execute on function public.food_cancel_order(uuid,text) to authenticated;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;
grant execute on function public.food_submit_payment(uuid,text) to authenticated;

drop policy if exists "Food private media readable" on storage.objects;
create policy "Food private media readable by rollout gate"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(name))[2]
          and o.buyer_id = auth.uid()
      )
    )
  )
);

drop policy if exists "Food private customer and merchant upload" on storage.objects;
drop policy if exists "Food private developer customer and merchant upload" on storage.objects;
create policy "Food private upload by rollout gate"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant update" on storage.objects;
drop policy if exists "Food private developer customer and merchant update" on storage.objects;
create policy "Food private update by rollout gate"
on storage.objects for update to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
)
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant delete" on storage.objects;
drop policy if exists "Food private developer customer and merchant delete" on storage.objects;
create policy "Food private delete by rollout gate"
on storage.objects for delete to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);
