-- WYNOS Merchant core completion v1
-- Staff roles, refunds, notification center support, activity log and store readiness.

alter table public.food_orders
  add column if not exists refund_status text not null default 'none',
  add column if not exists refund_note text,
  add column if not exists refund_requested_at timestamptz,
  add column if not exists refunded_at timestamptz,
  add column if not exists refund_updated_by uuid references public.profiles(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='food_orders_refund_status_check'
      and conrelid='public.food_orders'::regclass
  ) then
    alter table public.food_orders
      add constraint food_orders_refund_status_check
      check (refund_status in ('none','pending','refunded','failed'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname='food_orders_refund_note_length'
      and conrelid='public.food_orders'::regclass
  ) then
    alter table public.food_orders
      add constraint food_orders_refund_note_length
      check (refund_note is null or char_length(refund_note) <= 800);
  end if;
end;
$$;

update public.food_orders
set refund_status = case
      when payment_status='refunded' then 'refunded'
      when status='cancelled' and payment_status='paid' then 'pending'
      else refund_status
    end,
    refund_requested_at = case
      when status='cancelled' and payment_status='paid'
        then coalesce(refund_requested_at, cancelled_at, updated_at)
      else refund_requested_at
    end,
    refunded_at = case
      when payment_status='refunded'
        then coalesce(refunded_at, updated_at)
      else refunded_at
    end
where payment_status='refunded'
   or (status='cancelled' and payment_status='paid');

create table if not exists public.merchant_activity_log (
  id uuid primary key default gen_random_uuid(),
  merchant_account_id uuid not null references public.merchant_accounts(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  actor_username_snapshot text,
  action text not null,
  target_type text not null,
  target_id uuid,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint merchant_activity_action_length check (char_length(action) between 1 and 80),
  constraint merchant_activity_target_type_length check (char_length(target_type) between 1 and 80)
);

create index if not exists merchant_activity_account_created_idx
  on public.merchant_activity_log(merchant_account_id, created_at desc);

alter table public.merchant_activity_log enable row level security;

drop policy if exists "Merchant members can view activity" on public.merchant_activity_log;
create policy "Merchant members can view activity"
on public.merchant_activity_log
for select to authenticated
using (
  exists (
    select 1
    from public.merchant_memberships mm
    where mm.merchant_account_id = merchant_activity_log.merchant_account_id
      and mm.user_id = (select auth.uid())
      and mm.active
  )
);

revoke all on public.merchant_activity_log from anon, authenticated;
grant select on public.merchant_activity_log to authenticated;

create or replace function public.merchant_has_store_role(
  p_store_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.developer_accounts d
        where d.user_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.food_stores s
        join public.merchant_memberships mm
          on mm.merchant_account_id = s.merchant_account_id
        where s.id = p_store_id
          and mm.user_id = (select auth.uid())
          and mm.active
          and (p_roles is null or mm.role = any(p_roles))
      )
      or exists (
        select 1
        from public.food_staff fs
        where fs.store_id = p_store_id
          and fs.user_id = (select auth.uid())
          and fs.active
      )
    );
$$;

revoke all on function public.merchant_has_store_role(uuid,text[]) from public, anon;
grant execute on function public.merchant_has_store_role(uuid,text[]) to authenticated;

drop policy if exists "Food stores managed by staff" on public.food_stores;
create policy "Food stores managed by staff"
on public.food_stores
for update to authenticated
using (public.merchant_has_store_role(id, array['owner','admin','manager']))
with check (public.merchant_has_store_role(id, array['owner','admin','manager']));

drop policy if exists "Food menu inserted by merchant" on public.food_menu_items;
create policy "Food menu inserted by merchant"
on public.food_menu_items
for insert to authenticated
with check (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

drop policy if exists "Food menu updated by merchant" on public.food_menu_items;
create policy "Food menu updated by merchant"
on public.food_menu_items
for update to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin','manager']))
with check (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

drop policy if exists "Food menu deleted by merchant" on public.food_menu_items;
create policy "Food menu deleted by merchant"
on public.food_menu_items
for delete to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

drop policy if exists "Food staff managed by merchant" on public.food_staff;
create policy "Food staff managed by merchant"
on public.food_staff
for all to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin']))
with check (public.merchant_has_store_role(store_id, array['owner','admin']));

create or replace function internal.food_store_readiness_missing(p_store_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select array_remove(array[
    case when coalesce(char_length(trim(s.name)),0)=0 then 'name' end,
    case when coalesce(char_length(trim(s.phone)),0)=0 then 'phone' end,
    case when coalesce(char_length(trim(s.address)),0)=0 then 'address' end,
    case when coalesce(char_length(trim(s.business_hours)),0)=0 then 'business_hours' end,
    case when coalesce(char_length(trim(s.delivery_area)),0)=0 then 'delivery_area' end,
    case when not (
      (coalesce(char_length(trim(s.promptpay_name)),0)>0 and coalesce(char_length(trim(s.promptpay_id)),0)>0)
      or (coalesce(char_length(trim(s.bank_account_name)),0)>0 and coalesce(char_length(trim(s.bank_account_number)),0)>0)
      or coalesce(char_length(trim(s.payment_qr_path)),0)>0
    ) then 'payment' end,
    case when not exists (
      select 1 from public.food_menu_items m
      where m.store_id=s.id and m.is_available
    ) then 'menu' end
  ], null)
  from public.food_stores s
  where s.id=p_store_id;
$$;

revoke all on function internal.food_store_readiness_missing(uuid) from public, anon, authenticated;

create or replace function public.merchant_store_readiness(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_missing text[];
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  select internal.food_store_readiness_missing(p_store_id) into v_missing;
  if v_missing is null then
    raise exception 'store not found';
  end if;

  return jsonb_build_object(
    'ready', cardinality(v_missing)=0,
    'missing', to_jsonb(v_missing)
  );
end;
$$;

revoke all on function public.merchant_store_readiness(uuid) from public, anon;
grant execute on function public.merchant_store_readiness(uuid) to authenticated;

create or replace function internal.food_store_publish_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_missing text[];
begin
  if new.is_published and not old.is_published then
    select internal.food_store_readiness_missing(new.id) into v_missing;
    if coalesce(cardinality(v_missing),0) > 0 then
      raise exception 'store not ready: %', array_to_string(v_missing, ',');
    end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_store_publish_guard() from public, anon, authenticated;

drop trigger if exists trg_food_store_publish_guard on public.food_stores;
create trigger trg_food_store_publish_guard
before update of is_published on public.food_stores
for each row execute function internal.food_store_publish_guard();

create or replace function public.merchant_staff_members(p_store_id uuid)
returns table(
  user_id uuid,
  username text,
  display_name text,
  role text,
  active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
begin
  if not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  select s.merchant_account_id into v_account_id
  from public.food_stores s
  where s.id=p_store_id;

  if v_account_id is null then
    raise exception 'merchant account not found';
  end if;

  return query
  select
    mm.user_id,
    p.username,
    p.display_name,
    mm.role,
    mm.active,
    mm.created_at,
    mm.updated_at
  from public.merchant_memberships mm
  left join public.profiles p on p.id=mm.user_id
  where mm.merchant_account_id=v_account_id
  order by
    case mm.role when 'owner' then 0 when 'admin' then 1 when 'manager' then 2 else 3 end,
    mm.created_at;
end;
$$;

revoke all on function public.merchant_staff_members(uuid) from public, anon;
grant execute on function public.merchant_staff_members(uuid) to authenticated;

create or replace function public.merchant_add_staff_by_username(
  p_store_id uuid,
  p_username text,
  p_role text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_account_id uuid;
  v_user uuid;
  v_username text := lower(trim(coalesce(p_username,'')));
  v_actor_name text;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin']) then
    raise exception 'owner or admin role required';
  end if;
  if p_role not in ('admin','manager','orders','support','delivery') then
    raise exception 'invalid staff role';
  end if;
  if v_username='' then raise exception 'username required'; end if;

  select s.merchant_account_id into v_account_id
  from public.food_stores s where s.id=p_store_id;
  if v_account_id is null then raise exception 'merchant account not found'; end if;

  select p.id into v_user
  from public.profiles p
  where lower(p.username)=v_username
  limit 1;

  if v_user is null then raise exception 'WYNOS user not found'; end if;

  if exists (
    select 1 from public.merchant_memberships mm
    where mm.merchant_account_id=v_account_id
      and mm.user_id=v_user
      and mm.role='owner'
  ) then
    raise exception 'owner role cannot be changed';
  end if;

  insert into public.merchant_memberships(
    merchant_account_id,user_id,role,active,invited_by
  ) values (
    v_account_id,v_user,p_role,true,v_actor
  )
  on conflict (merchant_account_id,user_id)
  do update set
    role=excluded.role,
    active=true,
    invited_by=excluded.invited_by,
    updated_at=now();

  insert into public.merchant_notifications(
    merchant_account_id,recipient_user_id,type,reason
  ) values (
    v_account_id,v_user,'staff',
    'คุณได้รับสิทธิ์ ' || p_role || ' ใน WYNOS Merchant'
  );

  select p.username into v_actor_name from public.profiles p where p.id=v_actor;
  insert into public.merchant_activity_log(
    merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
  ) values (
    v_account_id,v_actor,v_actor_name,'staff_added','merchant_membership',v_user,
    jsonb_build_object('username',v_username,'role',p_role)
  );

  return v_user;
end;
$$;

revoke all on function public.merchant_add_staff_by_username(uuid,text,text) from public, anon;
grant execute on function public.merchant_add_staff_by_username(uuid,text,text) to authenticated;

create or replace function public.merchant_update_staff_member(
  p_store_id uuid,
  p_user_id uuid,
  p_role text,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_account_id uuid;
  v_actor_name text;
begin
  if not public.merchant_has_store_role(p_store_id, array['owner','admin']) then
    raise exception 'owner or admin role required';
  end if;
  if p_role not in ('admin','manager','orders','support','delivery') then
    raise exception 'invalid staff role';
  end if;

  select s.merchant_account_id into v_account_id
  from public.food_stores s where s.id=p_store_id;
  if v_account_id is null then raise exception 'merchant account not found'; end if;

  if exists (
    select 1 from public.merchant_memberships mm
    where mm.merchant_account_id=v_account_id
      and mm.user_id=p_user_id
      and mm.role='owner'
  ) then
    raise exception 'owner role cannot be changed';
  end if;

  update public.merchant_memberships
  set role=p_role, active=coalesce(p_active,false), updated_at=now()
  where merchant_account_id=v_account_id
    and user_id=p_user_id;

  if not found then raise exception 'staff member not found'; end if;

  select p.username into v_actor_name from public.profiles p where p.id=v_actor;
  insert into public.merchant_activity_log(
    merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
  ) values (
    v_account_id,v_actor,v_actor_name,
    case when p_active then 'staff_updated' else 'staff_disabled' end,
    'merchant_membership',p_user_id,
    jsonb_build_object('role',p_role,'active',p_active)
  );
end;
$$;

revoke all on function public.merchant_update_staff_member(uuid,uuid,text,boolean) from public, anon;
grant execute on function public.merchant_update_staff_member(uuid,uuid,text,boolean) to authenticated;

create or replace function public.merchant_set_refund_status(
  p_order_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.merchant_set_refund_status(uuid,text,text) from public, anon;
grant execute on function public.merchant_set_refund_status(uuid,text,text) to authenticated;

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
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
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
  v_roles text[];
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  v_roles := case
    when p_status='out_for_delivery' then array['owner','admin','manager','orders','delivery']
    else array['owner','admin','manager','orders']
  end;
  if not public.merchant_has_store_role(v_order.store_id, v_roles) then
    raise exception 'order management role required';
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
      cancelled_at=case when p_status='cancelled' then now() else cancelled_at end,
      refund_status=case
        when p_status='cancelled' and v_order.payment_status='paid' then 'pending'
        else refund_status
      end,
      refund_requested_at=case
        when p_status='cancelled' and v_order.payment_status='paid'
          then coalesce(refund_requested_at,now())
        else refund_requested_at
      end
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
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders','delivery']) then
    raise exception 'delivery role required';
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
  if not public.merchant_has_store_role(p_store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
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

revoke all on function public.food_set_payment_status(uuid,text,text) from public, anon;
grant execute on function public.food_set_payment_status(uuid,text,text) to authenticated;
revoke all on function public.food_transition_order(uuid,text,integer,text) from public, anon;
grant execute on function public.food_transition_order(uuid,text,integer,text) to authenticated;
revoke all on function public.food_complete_delivery(uuid,text,text,text) from public, anon;
grant execute on function public.food_complete_delivery(uuid,text,text,text) to authenticated;
revoke all on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text) from public, anon;
grant execute on function public.food_create_manual_order(uuid,text,text,text,text,jsonb,text) to authenticated;

create or replace function internal.merchant_capture_food_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_account_id uuid;
  v_target_id uuid;
  v_actor uuid := (select auth.uid());
  v_actor_username text;
  v_action text;
  v_target_type text := tg_table_name;
  v_detail jsonb := '{}'::jsonb;
begin
  if tg_table_name='food_stores' then
    v_store_id := new.id;
    v_target_id := new.id;
    if tg_op='UPDATE' then
      if new.is_published is distinct from old.is_published then
        v_action := 'store_publish_changed';
        v_detail := jsonb_build_object('from',old.is_published,'to',new.is_published);
      elsif new.is_open is distinct from old.is_open then
        v_action := 'store_open_changed';
        v_detail := jsonb_build_object('from',old.is_open,'to',new.is_open);
      else
        v_action := 'store_updated';
      end if;
    else
      return new;
    end if;
  elsif tg_table_name='food_menu_items' then
    if tg_op='DELETE' then
      v_store_id := old.store_id;
      v_target_id := old.id;
      v_action := 'menu_deleted';
      v_detail := jsonb_build_object('name',old.name);
    else
      v_store_id := new.store_id;
      v_target_id := new.id;
      if tg_op='INSERT' then
        v_action := 'menu_created';
        v_detail := jsonb_build_object('name',new.name,'price',new.price,'available',new.is_available);
      elsif new.price is distinct from old.price then
        v_action := 'menu_price_changed';
        v_detail := jsonb_build_object('name',new.name,'from',old.price,'to',new.price);
      elsif new.is_available is distinct from old.is_available then
        v_action := 'menu_availability_changed';
        v_detail := jsonb_build_object('name',new.name,'from',old.is_available,'to',new.is_available);
      else
        v_action := 'menu_updated';
        v_detail := jsonb_build_object('name',new.name);
      end if;
    end if;
  elsif tg_table_name='food_orders' then
    v_store_id := new.store_id;
    v_target_id := new.id;
    if tg_op <> 'UPDATE' then return new; end if;
    if new.refund_status is distinct from old.refund_status then
      v_action := 'refund_status_changed';
      v_detail := jsonb_build_object('order_number',new.order_number,'from',old.refund_status,'to',new.refund_status);
    elsif new.status is distinct from old.status then
      v_action := 'order_status_changed';
      v_detail := jsonb_build_object('order_number',new.order_number,'from',old.status,'to',new.status);
    elsif new.payment_status is distinct from old.payment_status then
      v_action := 'payment_status_changed';
      v_detail := jsonb_build_object('order_number',new.order_number,'from',old.payment_status,'to',new.payment_status);
    else
      return new;
    end if;
  else
    if tg_op='DELETE' then return old; else return new; end if;
  end if;

  select s.merchant_account_id into v_account_id
  from public.food_stores s
  where s.id=v_store_id;

  if v_account_id is not null then
    if v_actor is not null then
      select p.username into v_actor_username
      from public.profiles p where p.id=v_actor;
    end if;

    insert into public.merchant_activity_log(
      merchant_account_id,actor_id,actor_username_snapshot,action,target_type,target_id,detail
    ) values (
      v_account_id,v_actor,v_actor_username,v_action,v_target_type,v_target_id,v_detail
    );
  end if;

  if tg_op='DELETE' then return old; else return new; end if;
end;
$$;

revoke all on function internal.merchant_capture_food_activity() from public, anon, authenticated;

drop trigger if exists trg_merchant_activity_store on public.food_stores;
create trigger trg_merchant_activity_store
after update on public.food_stores
for each row execute function internal.merchant_capture_food_activity();

drop trigger if exists trg_merchant_activity_menu on public.food_menu_items;
create trigger trg_merchant_activity_menu
after insert or update or delete on public.food_menu_items
for each row execute function internal.merchant_capture_food_activity();

drop trigger if exists trg_merchant_activity_orders on public.food_orders;
create trigger trg_merchant_activity_orders
after update on public.food_orders
for each row execute function internal.merchant_capture_food_activity();

grant select on public.merchant_notifications to authenticated;
grant update (read_at) on public.merchant_notifications to authenticated;
