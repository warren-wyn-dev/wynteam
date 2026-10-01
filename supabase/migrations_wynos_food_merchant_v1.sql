-- WYNOS Food / WYNOS Merchant v1
-- Single-store, self-delivery restaurant workflow.
-- Additive migration: does not modify the existing social or commerce tables.

create sequence if not exists public.food_order_number_seq start with 1 increment by 1;

create or replace function public.food_next_order_number()
returns text
language sql
volatile
set search_path = public
as $$
  select 'WF' || lpad(nextval('public.food_order_number_seq')::text, 6, '0');
$$;

create table if not exists public.food_stores (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique default 'main',
  name text not null,
  description text,
  phone text,
  address text,
  logo_path text,
  cover_path text,
  business_hours text,
  delivery_area text,
  delivery_fee numeric(10,2) not null default 0 check (delivery_fee >= 0),
  minimum_order numeric(10,2) not null default 0 check (minimum_order >= 0),
  promptpay_name text,
  promptpay_id text,
  bank_name text,
  bank_account_name text,
  bank_account_number text,
  payment_qr_path text,
  is_open boolean not null default false,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_stores_name_length check (char_length(name) between 1 and 100),
  constraint food_stores_phone_length check (phone is null or char_length(phone) <= 50),
  constraint food_stores_address_length check (address is null or char_length(address) <= 500),
  constraint food_stores_description_length check (description is null or char_length(description) <= 1000)
);

create table if not exists public.food_staff (
  store_id uuid not null references public.food_stores(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'staff' check (role in ('owner','staff','delivery')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (store_id, user_id)
);

create table if not exists public.food_menu_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  category text not null default 'อาหาร',
  name text not null,
  description text,
  price numeric(10,2) not null check (price >= 0),
  image_path text,
  options jsonb not null default '[]'::jsonb,
  is_available boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_menu_items_name_length check (char_length(name) between 1 and 160),
  constraint food_menu_items_description_length check (description is null or char_length(description) <= 1000),
  constraint food_menu_items_category_length check (char_length(category) between 1 and 60),
  constraint food_menu_items_options_array check (jsonb_typeof(options) = 'array')
);

create table if not exists public.food_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default public.food_next_order_number(),
  store_id uuid not null references public.food_stores(id) on delete restrict,
  buyer_id uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  source text not null default 'app' check (source in ('app','manual')),
  status text not null default 'pending_acceptance'
    check (status in ('pending_acceptance','preparing','ready_for_delivery','out_for_delivery','delivered','cancelled')),
  payment_status text not null default 'pending'
    check (payment_status in ('pending','submitted','paid','issue','refunded')),
  recipient_name text not null,
  recipient_phone text not null,
  shipping_address text not null,
  customer_note text,
  payment_slip_path text,
  payment_note text,
  subtotal numeric(10,2) not null check (subtotal >= 0),
  delivery_fee numeric(10,2) not null default 0 check (delivery_fee >= 0),
  total numeric(10,2) not null check (total >= 0),
  eta_minutes integer check (eta_minutes is null or eta_minutes between 1 and 240),
  accepted_at timestamptz,
  ready_at timestamptz,
  out_for_delivery_at timestamptz,
  delivered_at timestamptz,
  cancelled_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_orders_recipient_name_length check (char_length(recipient_name) between 1 and 120),
  constraint food_orders_recipient_phone_length check (char_length(recipient_phone) between 1 and 50),
  constraint food_orders_shipping_address_length check (char_length(shipping_address) between 1 and 800),
  constraint food_orders_customer_note_length check (customer_note is null or char_length(customer_note) <= 800),
  constraint food_orders_payment_note_length check (payment_note is null or char_length(payment_note) <= 800),
  constraint food_orders_total_consistency check (total = subtotal + delivery_fee)
);

create table if not exists public.food_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id) on delete cascade,
  menu_item_id uuid references public.food_menu_items(id) on delete set null,
  item_name text not null,
  unit_price numeric(10,2) not null check (unit_price >= 0),
  quantity integer not null check (quantity between 1 and 99),
  selected_options jsonb not null default '[]'::jsonb,
  item_note text,
  created_at timestamptz not null default now(),
  constraint food_order_items_options_array check (jsonb_typeof(selected_options) = 'array'),
  constraint food_order_items_note_length check (item_note is null or char_length(item_note) <= 500)
);

create table if not exists public.food_order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.food_orders(id) on delete cascade,
  event_type text not null,
  from_status text,
  to_status text,
  note text,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint food_order_events_note_length check (note is null or char_length(note) <= 1000)
);

create table if not exists public.food_delivery_proofs (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.food_orders(id) on delete cascade,
  method text not null check (method in ('direct','dropoff')),
  location_note text,
  image_path text,
  delivered_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint food_delivery_proofs_note_length check (location_note is null or char_length(location_note) <= 500),
  constraint food_delivery_proofs_dropoff_evidence check (
    method = 'direct'
    or (method = 'dropoff' and image_path is not null and location_note is not null and char_length(trim(location_note)) > 0)
  )
);

create index if not exists food_staff_user_idx on public.food_staff(user_id) where active;
create index if not exists food_menu_items_store_available_idx on public.food_menu_items(store_id, is_available, sort_order);
create index if not exists food_orders_store_created_idx on public.food_orders(store_id, created_at desc);
create index if not exists food_orders_store_status_idx on public.food_orders(store_id, status, created_at desc);
create index if not exists food_orders_buyer_created_idx on public.food_orders(buyer_id, created_at desc) where buyer_id is not null;
create index if not exists food_order_items_order_idx on public.food_order_items(order_id);
create index if not exists food_order_events_order_idx on public.food_order_events(order_id, created_at);

create or replace function public.food_touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists food_stores_touch_updated_at on public.food_stores;
create trigger food_stores_touch_updated_at
before update on public.food_stores
for each row execute function public.food_touch_updated_at();

drop trigger if exists food_menu_items_touch_updated_at on public.food_menu_items;
create trigger food_menu_items_touch_updated_at
before update on public.food_menu_items
for each row execute function public.food_touch_updated_at();

drop trigger if exists food_orders_touch_updated_at on public.food_orders;
create trigger food_orders_touch_updated_at
before update on public.food_orders
for each row execute function public.food_touch_updated_at();

insert into public.food_stores (slug, name)
values ('main', 'ร้านของฉัน')
on conflict (slug) do nothing;

insert into public.food_staff (store_id, user_id, role, active)
select s.id, d.user_id, 'owner', true
from public.food_stores s
cross join public.developer_accounts d
where s.slug = 'main'
on conflict (store_id, user_id) do update set role = excluded.role, active = true;

create or replace function public.food_has_merchant_access(p_store_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (
      exists (
        select 1
        from public.developer_accounts d
        where d.user_id = auth.uid()
      )
      or exists (
        select 1
        from public.food_staff fs
        where fs.user_id = auth.uid()
          and fs.active
          and (p_store_id is null or fs.store_id = p_store_id)
      )
    );
$$;

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
        o.buyer_id = auth.uid()
        or public.food_has_merchant_access(o.store_id)
      )
  );
$$;

create or replace function public.food_can_manage_order(p_order_id uuid)
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
      and public.food_has_merchant_access(o.store_id)
  );
$$;

alter table public.food_stores enable row level security;
alter table public.food_staff enable row level security;
alter table public.food_menu_items enable row level security;
alter table public.food_orders enable row level security;
alter table public.food_order_items enable row level security;
alter table public.food_order_events enable row level security;
alter table public.food_delivery_proofs enable row level security;

drop policy if exists "Food stores visible to customers and staff" on public.food_stores;
create policy "Food stores visible to customers and staff"
on public.food_stores for select to authenticated
using (is_published or public.food_has_merchant_access(id));

drop policy if exists "Food stores managed by staff" on public.food_stores;
create policy "Food stores managed by staff"
on public.food_stores for update to authenticated
using (public.food_has_merchant_access(id))
with check (public.food_has_merchant_access(id));

drop policy if exists "Food staff visible to merchant" on public.food_staff;
create policy "Food staff visible to merchant"
on public.food_staff for select to authenticated
using (public.food_has_merchant_access(store_id));

drop policy if exists "Food staff managed by merchant" on public.food_staff;
create policy "Food staff managed by merchant"
on public.food_staff for all to authenticated
using (public.food_has_merchant_access(store_id))
with check (public.food_has_merchant_access(store_id));

drop policy if exists "Food menu visible to customers and staff" on public.food_menu_items;
create policy "Food menu visible to customers and staff"
on public.food_menu_items for select to authenticated
using (
  public.food_has_merchant_access(store_id)
  or (
    is_available
    and exists (
      select 1 from public.food_stores s
      where s.id = food_menu_items.store_id and s.is_published
    )
  )
);

drop policy if exists "Food menu inserted by merchant" on public.food_menu_items;
create policy "Food menu inserted by merchant"
on public.food_menu_items for insert to authenticated
with check (public.food_has_merchant_access(store_id));

drop policy if exists "Food menu updated by merchant" on public.food_menu_items;
create policy "Food menu updated by merchant"
on public.food_menu_items for update to authenticated
using (public.food_has_merchant_access(store_id))
with check (public.food_has_merchant_access(store_id));

drop policy if exists "Food menu deleted by merchant" on public.food_menu_items;
create policy "Food menu deleted by merchant"
on public.food_menu_items for delete to authenticated
using (public.food_has_merchant_access(store_id));

drop policy if exists "Food orders visible to buyer and merchant" on public.food_orders;
create policy "Food orders visible to buyer and merchant"
on public.food_orders for select to authenticated
using (buyer_id = auth.uid() or public.food_has_merchant_access(store_id));

drop policy if exists "Food order items visible to buyer and merchant" on public.food_order_items;
create policy "Food order items visible to buyer and merchant"
on public.food_order_items for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food order events visible to buyer and merchant" on public.food_order_events;
create policy "Food order events visible to buyer and merchant"
on public.food_order_events for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food delivery proofs visible to buyer and merchant" on public.food_delivery_proofs;
create policy "Food delivery proofs visible to buyer and merchant"
on public.food_delivery_proofs for select to authenticated
using (public.food_can_view_order(order_id));

revoke all on table public.food_stores from anon, authenticated;
revoke all on table public.food_staff from anon, authenticated;
revoke all on table public.food_menu_items from anon, authenticated;
revoke all on table public.food_orders from anon, authenticated;
revoke all on table public.food_order_items from anon, authenticated;
revoke all on table public.food_order_events from anon, authenticated;
revoke all on table public.food_delivery_proofs from anon, authenticated;

grant select, update on table public.food_stores to authenticated;
grant select, insert, update, delete on table public.food_staff to authenticated;
grant select, insert, update, delete on table public.food_menu_items to authenticated;
grant select on table public.food_orders to authenticated;
grant select on table public.food_order_items to authenticated;
grant select on table public.food_order_events to authenticated;
grant select on table public.food_delivery_proofs to authenticated;

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
  if auth.uid() is null then
    raise exception 'authentication required';
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
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));
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

create or replace function public.food_create_manual_order(
  p_store_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text,
  p_items jsonb,
  p_payment_status text default 'paid'
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
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;
  if p_payment_status not in ('pending','paid') then
    raise exception 'invalid payment status';
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
  if not found then raise exception 'store not found'; end if;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_menu_id := (v_line->>'menu_item_id')::uuid;
    v_qty := greatest(1, least(99, coalesce((v_line->>'quantity')::integer, 1)));
    select * into v_item from public.food_menu_items where id = v_menu_id and store_id = p_store_id;
    if not found then raise exception 'menu item not found'; end if;
    v_subtotal := v_subtotal + (v_item.price * v_qty);
  end loop;
  v_total := v_subtotal + v_store.delivery_fee;

  insert into public.food_orders (
    store_id, buyer_id, created_by, source, status, payment_status,
    recipient_name, recipient_phone, shipping_address, customer_note,
    subtotal, delivery_fee, total, accepted_at, paid_at
  ) values (
    p_store_id, null, auth.uid(), 'manual', 'preparing', p_payment_status,
    trim(p_recipient_name), trim(p_recipient_phone), trim(p_shipping_address),
    nullif(trim(coalesce(p_customer_note,'')), ''),
    v_subtotal, v_store.delivery_fee, v_total, now(),
    case when p_payment_status='paid' then now() else null end
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
  values (v_order_id,'manual_created','preparing','ร้านสร้างออเดอร์เอง',auth.uid());

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
  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then
    raise exception 'order not found';
  end if;
  if v_order.status in ('delivered','cancelled') then
    raise exception 'order is closed';
  end if;
  if p_slip_path is null or p_slip_path not like auth.uid()::text || '/slips/%' then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status='submitted', payment_slip_path=p_slip_path, payment_note=null
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$$;

create or replace function public.food_set_payment_status(
  p_order_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id=p_order_id;
  if not found or not public.food_has_merchant_access(v_order.store_id) then
    raise exception 'merchant access required';
  end if;
  if p_status not in ('paid','issue','refunded') then
    raise exception 'invalid payment status';
  end if;

  update public.food_orders
  set payment_status=p_status,
      payment_note=nullif(left(trim(coalesce(p_note,'')),800),''),
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_' || p_status,nullif(left(trim(coalesce(p_note,'')),1000),''),auth.uid());
end;
$$;

create or replace function public.food_transition_order(
  p_order_id uuid,
  p_status text,
  p_eta_minutes integer default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
  v_allowed boolean := false;
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.food_has_merchant_access(v_order.store_id) then
    raise exception 'merchant access required';
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
      cancelled_at=case when p_status='cancelled' then now() else cancelled_at end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values (
    p_order_id,'status_changed',v_order.status,p_status,
    nullif(left(trim(coalesce(p_note,'')),1000),''),
    auth.uid()
  );
end;
$$;

create or replace function public.food_complete_delivery(
  p_order_id uuid,
  p_method text,
  p_location_note text default null,
  p_image_path text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.food_has_merchant_access(v_order.store_id) then
    raise exception 'merchant access required';
  end if;
  if v_order.status <> 'out_for_delivery' then
    raise exception 'order is not out for delivery';
  end if;
  if p_method not in ('direct','dropoff') then
    raise exception 'invalid delivery method';
  end if;
  if p_method='dropoff' and (
    p_image_path is null
    or coalesce(char_length(trim(p_location_note)),0)=0
    or p_image_path not like 'delivery/' || p_order_id::text || '/%'
  ) then
    raise exception 'dropoff photo and location are required';
  end if;

  insert into public.food_delivery_proofs(order_id,method,location_note,image_path,delivered_by)
  values (
    p_order_id,p_method,
    nullif(left(trim(coalesce(p_location_note,'')),500),''),
    case when p_method='dropoff' then p_image_path else null end,
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
    case when p_method='dropoff' then nullif(left(trim(coalesce(p_location_note,'')),1000),'') else 'ส่งให้ผู้รับโดยตรง' end,
    auth.uid()
  );
end;
$$;

revoke all on function public.food_next_order_number() from public, anon, authenticated;
revoke all on function public.food_has_merchant_access(uuid) from public, anon;
revoke all on function public.food_can_view_order(uuid) from public, anon;
revoke all on function public.food_can_manage_order(uuid) from public, anon;
revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon;
revoke all on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text) from public, anon;
revoke all on function public.food_submit_payment(uuid,text) from public, anon;
revoke all on function public.food_set_payment_status(uuid,text,text) from public, anon;
revoke all on function public.food_transition_order(uuid,text,integer,text) from public, anon;
revoke all on function public.food_complete_delivery(uuid,text,text,text) from public, anon;

grant execute on function public.food_has_merchant_access(uuid) to authenticated;
grant execute on function public.food_can_view_order(uuid) to authenticated;
grant execute on function public.food_can_manage_order(uuid) to authenticated;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;
grant execute on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text) to authenticated;
grant execute on function public.food_submit_payment(uuid,text) to authenticated;
grant execute on function public.food_set_payment_status(uuid,text,text) to authenticated;
grant execute on function public.food_transition_order(uuid,text,integer,text) to authenticated;
grant execute on function public.food_complete_delivery(uuid,text,text,text) to authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'food-public','food-public',true,8388608,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update
set public=excluded.public,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'food-private','food-private',false,8388608,
  array['image/jpeg','image/png','image/webp']::text[]
)
on conflict (id) do update
set public=excluded.public,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Food public media readable" on storage.objects;
create policy "Food public media readable"
on storage.objects for select
using (bucket_id='food-public');

drop policy if exists "Food public media merchant upload" on storage.objects;
create policy "Food public media merchant upload"
on storage.objects for insert to authenticated
with check (bucket_id='food-public' and public.food_has_merchant_access(null));

drop policy if exists "Food public media merchant update" on storage.objects;
create policy "Food public media merchant update"
on storage.objects for update to authenticated
using (bucket_id='food-public' and public.food_has_merchant_access(null))
with check (bucket_id='food-public' and public.food_has_merchant_access(null));

drop policy if exists "Food public media merchant delete" on storage.objects;
create policy "Food public media merchant delete"
on storage.objects for delete to authenticated
using (bucket_id='food-public' and public.food_has_merchant_access(null));

drop policy if exists "Food private media readable" on storage.objects;
create policy "Food private media readable"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (storage.foldername(name))[1] = auth.uid()::text
    or (
      (storage.foldername(name))[1] = 'delivery'
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
      (storage.foldername(name))[1] = auth.uid()::text
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
      (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
)
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      (storage.foldername(name))[1] = auth.uid()::text
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
      (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='food_orders'
  ) then
    alter publication supabase_realtime add table public.food_orders;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='food_order_events'
  ) then
    alter publication supabase_realtime add table public.food_order_events;
  end if;
end $$;
