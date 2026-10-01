-- WYNOS Food customer developer preview v1
-- Customer-side data needed for the closed developer-only preview.

create table if not exists public.food_customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null default 'ที่อยู่',
  recipient_name text not null,
  recipient_phone text not null,
  address text not null,
  delivery_note text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_customer_addresses_label_length check (char_length(label) between 1 and 80),
  constraint food_customer_addresses_name_length check (char_length(recipient_name) between 1 and 120),
  constraint food_customer_addresses_phone_length check (char_length(recipient_phone) between 1 and 50),
  constraint food_customer_addresses_address_length check (char_length(address) between 1 and 800),
  constraint food_customer_addresses_note_length check (delivery_note is null or char_length(delivery_note) <= 500)
);

create index if not exists food_customer_addresses_user_idx
on public.food_customer_addresses(user_id, created_at desc);

create unique index if not exists food_customer_addresses_one_default_idx
on public.food_customer_addresses(user_id)
where is_default;

drop trigger if exists food_customer_addresses_touch_updated_at on public.food_customer_addresses;
create trigger food_customer_addresses_touch_updated_at
before update on public.food_customer_addresses
for each row execute function public.food_touch_updated_at();

alter table public.food_customer_addresses enable row level security;

drop policy if exists "Food customer addresses own rows" on public.food_customer_addresses;
create policy "Food customer addresses own rows"
on public.food_customer_addresses for select to authenticated
using (user_id = auth.uid() and public.food_is_permanent_account());

revoke all on table public.food_customer_addresses from anon, authenticated;
grant select on table public.food_customer_addresses to authenticated;

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
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
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
    select 1 from public.food_customer_addresses
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
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
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
      update public.food_customer_addresses set is_default = true where id = v_next;
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
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
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

-- Developer Preview must be testable while the Food store remains unpublished.
-- Public users will still require is_published=true after launch; only a confirmed
-- developer account may order from an unpublished store.
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
  if not found
     or not v_store.is_open
     or (not v_store.is_published and not public.is_developer_account()) then
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

    if not found then raise exception 'menu item is unavailable'; end if;

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
    left(trim(p_recipient_name),120),
    left(trim(p_recipient_phone),50),
    left(trim(p_shipping_address),800),
    nullif(left(trim(coalesce(p_customer_note,'')),800),''),
    v_subtotal, v_store.delivery_fee, v_total
  )
  returning id into v_order_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));

    select * into v_item
    from public.food_menu_items
    where id = v_menu_id and store_id = p_store_id;

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
    v_order_id, 'created', 'pending_acceptance', 'สร้างคำสั่งซื้อ', auth.uid()
  );

  return v_order_id;
end;
$$;

revoke all on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean) from public, anon;
revoke all on function public.food_delete_customer_address(uuid) from public, anon;
revoke all on function public.food_cancel_order(uuid,text) from public, anon;
revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon;

grant execute on function public.food_upsert_customer_address(uuid,text,text,text,text,text,boolean) to authenticated;
grant execute on function public.food_delete_customer_address(uuid) to authenticated;
grant execute on function public.food_cancel_order(uuid,text) to authenticated;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;
