-- WYNOS Food rollout gate
-- Keep the customer product invisible at the database layer until Founder explicitly enables public launch.

create table if not exists public.food_rollout_settings (
  id boolean primary key default true check (id),
  public_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into public.food_rollout_settings (id, public_enabled)
values (true, false)
on conflict (id) do nothing;

drop trigger if exists food_rollout_settings_touch_updated_at on public.food_rollout_settings;
create trigger food_rollout_settings_touch_updated_at
before update on public.food_rollout_settings
for each row execute function public.food_touch_updated_at();

alter table public.food_rollout_settings enable row level security;
revoke all on table public.food_rollout_settings from anon, authenticated;

create or replace function public.food_public_access_enabled()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select public_enabled from public.food_rollout_settings where id = true),
    false
  );
$$;

revoke all on function public.food_public_access_enabled() from public, anon;
grant execute on function public.food_public_access_enabled() to authenticated;

drop policy if exists "Food stores visible to customers and staff" on public.food_stores;
create policy "Food stores visible to customers and staff"
on public.food_stores for select to authenticated
using (
  public.food_has_merchant_access(id)
  or (is_published and public.food_public_access_enabled())
);

drop policy if exists "Food menu visible to customers and staff" on public.food_menu_items;
create policy "Food menu visible to customers and staff"
on public.food_menu_items for select to authenticated
using (
  public.food_has_merchant_access(store_id)
  or (
    is_available
    and public.food_public_access_enabled()
    and exists (
      select 1
      from public.food_stores s
      where s.id = food_menu_items.store_id
        and s.is_published
    )
  )
);

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

revoke all on function public.food_create_order(uuid,text,text,text,text,jsonb) from public, anon;
grant execute on function public.food_create_order(uuid,text,text,text,text,jsonb) to authenticated;
