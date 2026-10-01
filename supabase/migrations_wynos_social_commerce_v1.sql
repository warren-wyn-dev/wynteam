-- WYNOS Social Commerce v1
-- Links an owned public WYNOS Drop to one Merchant menu item and lets a
-- permanent WYNOS account create a Food order directly from that social post.
-- This is intentionally separate from the broader WYNOS Food public rollout.

create table if not exists public.food_social_offers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  menu_item_id uuid not null references public.food_menu_items(id) on delete cascade,
  drop_id uuid not null references public.drops(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_social_offers_menu_item_key unique (menu_item_id),
  constraint food_social_offers_drop_key unique (drop_id)
);

create index if not exists food_social_offers_store_idx
  on public.food_social_offers(store_id);
create index if not exists food_social_offers_active_drop_idx
  on public.food_social_offers(drop_id)
  where is_active;

alter table public.food_social_offers enable row level security;
revoke all on table public.food_social_offers from public, anon, authenticated;

drop trigger if exists food_social_offers_touch_updated_at on public.food_social_offers;
create trigger food_social_offers_touch_updated_at
before update on public.food_social_offers
for each row execute function public.food_touch_updated_at();

create or replace function public.food_social_offers_for_drops(p_drop_ids uuid[])
returns table (
  drop_id uuid,
  store_id uuid,
  menu_item_id uuid,
  store_name text,
  item_name text,
  item_description text,
  price numeric,
  image_path text,
  delivery_fee numeric,
  minimum_order numeric,
  store_open boolean,
  payment_ready boolean,
  is_orderable boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
  end if;

  if p_drop_ids is null or coalesce(array_length(p_drop_ids, 1), 0) = 0 then
    return;
  end if;

  if array_length(p_drop_ids, 1) > 250 then
    raise exception 'too many drop ids';
  end if;

  return query
  select
    o.drop_id,
    o.store_id,
    o.menu_item_id,
    s.name,
    m.name,
    m.description,
    m.price,
    m.image_path,
    s.delivery_fee,
    s.minimum_order,
    s.is_open,
    (s.promptpay_id is not null and btrim(s.promptpay_id) <> '') as payment_ready,
    (
      o.is_active
      and s.is_published
      and s.is_open
      and m.is_available
      and s.promptpay_id is not null
      and btrim(s.promptpay_id) <> ''
    ) as is_orderable
  from public.food_social_offers o
  join public.food_stores s on s.id = o.store_id
  join public.food_menu_items m on m.id = o.menu_item_id and m.store_id = o.store_id
  join public.drops d on d.id = o.drop_id
  where o.drop_id = any(p_drop_ids)
    and o.is_active
    and s.is_published
    and m.is_available
    and d.deleted_at is null
    and d.audience = 'everyone';
end;
$$;

revoke all on function public.food_social_offers_for_drops(uuid[]) from public;
grant execute on function public.food_social_offers_for_drops(uuid[]) to authenticated;

create or replace function public.food_merchant_social_offers(p_store_id uuid)
returns table (
  menu_item_id uuid,
  drop_id uuid,
  is_active boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_store_id is null or not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  return query
  select o.menu_item_id, o.drop_id, o.is_active
  from public.food_social_offers o
  where o.store_id = p_store_id
  order by o.updated_at desc;
end;
$$;

revoke all on function public.food_merchant_social_offers(uuid) from public;
grant execute on function public.food_merchant_social_offers(uuid) to authenticated;

create or replace function public.food_set_social_offer(
  p_menu_item_id uuid,
  p_drop_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.food_menu_items%rowtype;
  v_drop public.drops%rowtype;
  v_offer_id uuid;
begin
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
  end if;

  select * into v_item
  from public.food_menu_items
  where id = p_menu_item_id;

  if not found or not public.food_has_merchant_access(v_item.store_id) then
    raise exception 'merchant access required';
  end if;

  if p_drop_id is null then
    delete from public.food_social_offers
    where menu_item_id = p_menu_item_id;
    return null;
  end if;

  select * into v_drop
  from public.drops
  where id = p_drop_id
    and author_id = auth.uid()
    and deleted_at is null
    and audience = 'everyone';

  if not found then
    raise exception 'post must be your public WYNOS post';
  end if;

  -- One active social-sales post per menu item in v1. Re-linking is atomic.
  delete from public.food_social_offers
  where menu_item_id = p_menu_item_id
     or drop_id = p_drop_id;

  insert into public.food_social_offers(
    store_id, menu_item_id, drop_id, created_by, is_active
  ) values (
    v_item.store_id, v_item.id, v_drop.id, auth.uid(), true
  )
  returning id into v_offer_id;

  return v_offer_id;
end;
$$;

revoke all on function public.food_set_social_offer(uuid,uuid) from public;
grant execute on function public.food_set_social_offer(uuid,uuid) to authenticated;

create or replace function public.food_create_social_order(
  p_drop_id uuid,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_customer_note text default null,
  p_quantity integer default 1
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.food_social_offers%rowtype;
  v_store public.food_stores%rowtype;
  v_item public.food_menu_items%rowtype;
  v_order_id uuid;
  v_qty integer;
  v_subtotal numeric(10,2);
  v_total numeric(10,2);
begin
  if not public.food_is_permanent_account() then
    raise exception 'permanent account required';
  end if;

  if coalesce(char_length(trim(p_recipient_name)),0) = 0
     or coalesce(char_length(trim(p_recipient_phone)),0) = 0
     or coalesce(char_length(trim(p_shipping_address)),0) = 0 then
    raise exception 'recipient information is required';
  end if;

  v_qty := greatest(1, least(99, coalesce(p_quantity, 1)));

  select o.* into v_offer
  from public.food_social_offers o
  join public.drops d on d.id = o.drop_id
  where o.drop_id = p_drop_id
    and o.is_active
    and d.deleted_at is null
    and d.audience = 'everyone';

  if not found then
    raise exception 'social offer not found';
  end if;

  select * into v_store
  from public.food_stores
  where id = v_offer.store_id;

  select * into v_item
  from public.food_menu_items
  where id = v_offer.menu_item_id
    and store_id = v_offer.store_id;

  if v_store.id is null
     or not v_store.is_published
     or not v_store.is_open
     or v_item.id is null
     or not v_item.is_available then
    raise exception 'social offer is not accepting orders';
  end if;

  if v_store.promptpay_id is null or btrim(v_store.promptpay_id) = '' then
    raise exception 'merchant payment is not configured';
  end if;

  v_subtotal := v_item.price * v_qty;
  if v_subtotal < v_store.minimum_order then
    raise exception 'minimum order not met';
  end if;

  v_total := v_subtotal + v_store.delivery_fee;

  insert into public.food_orders(
    store_id, buyer_id, created_by, source, source_drop_id,
    status, payment_status,
    recipient_name, recipient_phone, shipping_address, customer_note,
    subtotal, delivery_fee, total
  ) values (
    v_store.id,
    auth.uid(),
    auth.uid(),
    'social',
    p_drop_id,
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

  insert into public.food_order_items(
    order_id, menu_item_id, item_name, unit_price, quantity,
    selected_options, item_note
  ) values (
    v_order_id,
    v_item.id,
    v_item.name,
    v_item.price,
    v_qty,
    '[]'::jsonb,
    null
  );

  insert into public.food_order_events(
    order_id, event_type, to_status, note, actor_id
  ) values (
    v_order_id,
    'created',
    'pending_acceptance',
    'สร้างคำสั่งซื้อจากโพสต์ WYNOS',
    auth.uid()
  );

  return v_order_id;
end;
$$;

revoke all on function public.food_create_social_order(uuid,text,text,text,text,integer) from public;
grant execute on function public.food_create_social_order(uuid,text,text,text,text,integer) to authenticated;

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
          and (
            public.food_customer_access_enabled()
            or (
              o.source = 'social'
              and public.food_is_permanent_account()
            )
          )
        )
      )
  );
$$;

drop policy if exists "Food orders visible by rollout gate" on public.food_orders;
create policy "Food orders visible by rollout gate"
on public.food_orders
for select
to authenticated
using (
  public.food_has_merchant_access(store_id)
  or (
    buyer_id = auth.uid()
    and (
      public.food_customer_access_enabled()
      or (
        source = 'social'
        and public.food_is_permanent_account()
      )
    )
  )
);

create or replace function public.food_social_payment_path_allowed(p_name text)
returns boolean
language sql
stable
security definer
set search_path = public, storage
as $$
  select
    public.food_is_permanent_account()
    and (storage.foldername(p_name))[1] = auth.uid()::text
    and (storage.foldername(p_name))[2] = 'slips'
    and exists (
      select 1
      from public.food_orders o
      where o.id::text = (storage.foldername(p_name))[3]
        and o.buyer_id = auth.uid()
        and o.source = 'social'
    );
$$;

revoke all on function public.food_social_payment_path_allowed(text) from public;
grant execute on function public.food_social_payment_path_allowed(text) to authenticated;

drop policy if exists "Food private upload by rollout gate" on storage.objects;
create policy "Food private upload by rollout gate"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'food-private'
  and (
    public.food_has_merchant_access(null::uuid)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or public.food_social_payment_path_allowed(name)
  )
);

drop policy if exists "Food private media readable by rollout gate" on storage.objects;
create policy "Food private media readable by rollout gate"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'food-private'
  and (
    public.food_has_merchant_access(null::uuid)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or public.food_social_payment_path_allowed(name)
    or (
      public.food_is_permanent_account()
      and (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(objects.name))[2]
          and o.buyer_id = auth.uid()
          and o.source = 'social'
      )
    )
  )
);

drop policy if exists "Food private update by rollout gate" on storage.objects;
create policy "Food private update by rollout gate"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'food-private'
  and (
    public.food_has_merchant_access(null::uuid)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or public.food_social_payment_path_allowed(name)
  )
)
with check (
  bucket_id = 'food-private'
  and (
    public.food_has_merchant_access(null::uuid)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or public.food_social_payment_path_allowed(name)
  )
);

drop policy if exists "Food private delete by rollout gate" on storage.objects;
create policy "Food private delete by rollout gate"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'food-private'
  and (
    public.food_has_merchant_access(null::uuid)
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or public.food_social_payment_path_allowed(name)
  )
);

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

  if v_order.source <> 'social' and not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if v_order.status <> 'pending_acceptance'
     or v_order.payment_status not in ('pending','issue') then
    raise exception 'order cannot be cancelled by customer';
  end if;

  update public.food_orders
  set status = 'cancelled',
      cancelled_at = now()
  where id = p_order_id;

  insert into public.food_order_events(
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

revoke all on function public.food_cancel_order(uuid,text) from public;
grant execute on function public.food_cancel_order(uuid,text) to authenticated;
