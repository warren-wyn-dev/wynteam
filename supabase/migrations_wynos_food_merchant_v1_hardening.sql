-- WYNOS Merchant v1 hardening
-- WYNOS anonymous Auth sessions must never create permanent Food orders
-- or consume private receipt/proof storage.

create or replace function public.food_is_permanent_account()
returns boolean
language sql
stable
set search_path = public
as $$
  select auth.uid() is not null
    and coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false) is false;
$$;

revoke all on function public.food_is_permanent_account() from public, anon;
grant execute on function public.food_is_permanent_account() to authenticated;

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
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
  end if;
  if coalesce(char_length(trim(p_recipient_name)),0) = 0
     or coalesce(char_length(trim(p_recipient_phone)),0) = 0
     or coalesce(char_length(trim(p_shipping_address)),0) = 0 then
    raise exception 'recipient information is required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 50 then
    raise exception 'invalid order items';
  end if;

  select * into v_store from public.food_stores where id = p_store_id;
  if not found or not v_store.is_published or not v_store.is_open then
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
    where id = v_menu_id and store_id = p_store_id and is_available;
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
    p_store_id, auth.uid(), auth.uid(), 'app', 'pending_acceptance', 'pending',
    trim(p_recipient_name), trim(p_recipient_phone), trim(p_shipping_address),
    nullif(trim(coalesce(p_customer_note,'')), ''),
    v_subtotal, v_store.delivery_fee, v_total
  )
  returning id into v_order_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));
    select * into v_item from public.food_menu_items where id = v_menu_id;
    insert into public.food_order_items (
      order_id, menu_item_id, item_name, unit_price, quantity, selected_options, item_note
    ) values (
      v_order_id, v_item.id, v_item.name, v_item.price, v_qty,
      case when jsonb_typeof(v_line->'selected_options') = 'array' then v_line->'selected_options' else '[]'::jsonb end,
      nullif(left(trim(coalesce(v_line->>'note','')),500),'')
    );
  end loop;

  insert into public.food_order_events(order_id,event_type,to_status,note,actor_id)
  values (v_order_id,'created','pending_acceptance','สร้างคำสั่งซื้อ',auth.uid());

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
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
  end if;

  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then
    raise exception 'order not found';
  end if;
  if v_order.status in ('delivered','cancelled') then
    raise exception 'order is closed';
  end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text || '/slips/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status='submitted', payment_slip_path=p_slip_path, payment_note=null
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$$;

drop policy if exists "Food private media readable" on storage.objects;
create policy "Food private media readable"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or (
      public.food_is_permanent_account()
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
create policy "Food private customer and merchant upload"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant update" on storage.objects;
create policy "Food private customer and merchant update"
on storage.objects for update to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_is_permanent_account()
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
      public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant delete" on storage.objects;
create policy "Food private customer and merchant delete"
on storage.objects for delete to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);
