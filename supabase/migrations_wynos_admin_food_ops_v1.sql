-- WYN-203: WYNOS Admin operations for WYNOS Food / Merchant stores.
--
-- Founder (2026-10-04): "เพิ่มระบบที่ยังไม่มี" — on top of the existing
-- merchant application review, WYN Admin gets:
--   1. a list of every store with status and sales,
--   2. store suspension (admin only),
--   3. cross-store orders for complaints, with slip / delivery photo (admin only),
--   4. each store's team, with deactivate / reactivate (admin only),
--   5. an overview of stores, orders and sales.
--
-- Access model (unchanged roles, deny by default):
--   * admin + moderator: overview, store list, store detail (business data,
--     no customer data).
--   * admin only: orders and order detail (customer name / phone / address,
--     slip and delivery photo), suspension, team changes.
--   * every RPC is SECURITY DEFINER, checks internal.current_platform_role()
--     first, and is granted to authenticated only. Opening an order's detail
--     and every change is written to the audit log.
--
-- Suspension: food_stores gets admin_suspended_* columns. A trigger keeps a
-- suspended store unpublished and closed and lets only a WYNOS admin change
-- the suspension fields (store staff can update food_stores through RLS, so
-- this must be enforced in the database). Another trigger rejects new orders
-- for a suspended store on every path. Orders already placed can still be
-- fulfilled and refunded by the store.
--
-- Additive: new nullable columns, helpers, triggers, RPCs, one storage read
-- policy for platform admins, and new audit event types. Rollback: see the
-- header of .github/workflows/food-apply-wyn203.yml.

-- suspension columns ------------------------------------------------------

alter table public.food_stores
  add column if not exists admin_suspended_at timestamptz,
  add column if not exists admin_suspended_reason text,
  add column if not exists admin_suspended_by uuid references auth.users(id) on delete set null;

alter table public.food_stores drop constraint if exists food_stores_admin_suspension_reason;
alter table public.food_stores add constraint food_stores_admin_suspension_reason check (
  admin_suspended_reason is null or char_length(admin_suspended_reason) <= 500
);

-- helpers -------------------------------------------------------------------

-- True for a WYNOS platform admin (not moderator). Used by the suspension
-- guard and the storage read policy.
create or replace function public.food_is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.platform_role = 'admin'
  );
$$;

revoke all on function public.food_is_platform_admin() from public, anon;
grant execute on function public.food_is_platform_admin() to authenticated;

-- SECURITY INVOKER on purpose: current_user is the API role (authenticated /
-- anon) for a direct PATCH, and the function owner inside the SECURITY DEFINER
-- admin RPC. So the suspension fields only change through that RPC, which
-- requires a reason, notifies the store and writes the audit log — even a
-- platform admin who is also on the store team cannot PATCH them directly.
create or replace function internal.food_store_guard_suspension()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.admin_suspended_at is distinct from old.admin_suspended_at
      or new.admin_suspended_reason is distinct from old.admin_suspended_reason
      or new.admin_suspended_by is distinct from old.admin_suspended_by)
     and current_user in ('authenticated', 'anon') then
    raise exception 'store suspension can only be changed by WYNOS admin';
  end if;
  if new.admin_suspended_at is not null then
    if (new.is_published and not old.is_published) or (new.is_open and not old.is_open) then
      raise exception 'store is suspended';
    end if;
    new.is_published := false;
    new.is_open := false;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_store_guard_suspension() from public, anon, authenticated;

drop trigger if exists food_stores_guard_suspension on public.food_stores;
create trigger food_stores_guard_suspension
before update on public.food_stores
for each row execute function internal.food_store_guard_suspension();

create or replace function internal.food_order_block_suspended_store()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.food_stores s
    where s.id = new.store_id and s.admin_suspended_at is not null
  ) then
    raise exception 'store is not accepting orders';
  end if;
  return new;
end;
$$;

revoke all on function internal.food_order_block_suspended_store() from public, anon, authenticated;

drop trigger if exists food_orders_block_suspended_store on public.food_orders;
create trigger food_orders_block_suspended_store
before insert on public.food_orders
for each row execute function internal.food_order_block_suspended_store();

-- Platform admins can open slips and delivery photos for complaints.
drop policy if exists "Food private readable by WYNOS admin" on storage.objects;
create policy "Food private readable by WYNOS admin"
on storage.objects for select to authenticated
using (bucket_id = 'food-private' and public.food_is_platform_admin());

-- audit event types (keep every existing type) -------------------------------

do $$
declare
  v_def text;
  v_types text[];
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conname = 'audit_log_event_type_check'
    and c.conrelid = 'public.audit_log'::regclass;

  -- Each quoted literal is either 'a' (ARRAY['a'::text, ...]) or '{a,b}'
  -- (= any ('{a,b}'::text[]), the form this migration writes on a re-run).
  select coalesce(array_agg(distinct t), '{}') into v_types
  from regexp_matches(coalesce(v_def, ''), '''([^'']*)''', 'g') as m,
       unnest(string_to_array(btrim(m[1], '{}'), ',')) as raw,
       btrim(raw, ' "') as t
  where t ~ '^[a-z0-9_]+$';

  select array_agg(distinct t order by t) into v_types
  from unnest(v_types || array[
    'admin_food_store_suspended',
    'admin_food_store_unsuspended',
    'admin_food_staff_updated',
    'admin_food_order_viewed'
  ]) as t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end;
$$;

-- read RPCs (admin + moderator) ---------------------------------------------

create or replace function public.admin_food_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
  v_result jsonb;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  select jsonb_build_object(
    'stores_total', (select count(*) from public.food_stores),
    'stores_published', (select count(*) from public.food_stores where is_published),
    'stores_open', (select count(*) from public.food_stores where is_open),
    'stores_suspended', (select count(*) from public.food_stores where admin_suspended_at is not null),
    'orders_today', (
      select count(*) from public.food_orders
      where (created_at at time zone 'Asia/Bangkok')::date = v_today
    ),
    'sales_today', (
      select coalesce(sum(total), 0) from public.food_orders
      where status = 'delivered' and (delivered_at at time zone 'Asia/Bangkok')::date = v_today
    ),
    'active_orders', (
      select count(*) from public.food_orders
      where status not in ('delivered', 'cancelled')
    ),
    'days', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', d.day,
        'orders', (
          select count(*) from public.food_orders o
          where (o.created_at at time zone 'Asia/Bangkok')::date = d.day
        ),
        'sales', (
          select coalesce(sum(o.total), 0) from public.food_orders o
          where o.status = 'delivered' and (o.delivered_at at time zone 'Asia/Bangkok')::date = d.day
        )
      ) order by d.day), '[]'::jsonb)
      from generate_series(v_today - 6, v_today, interval '1 day') as g(day_ts),
      lateral (select g.day_ts::date as day) d
    )
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.admin_food_overview() from public, anon;
grant execute on function public.admin_food_overview() to authenticated;

create or replace function public.admin_food_stores(p_query text default null)
returns table(
  id uuid,
  name text,
  slug text,
  phone text,
  is_open boolean,
  is_published boolean,
  admin_suspended_at timestamptz,
  admin_suspended_reason text,
  owner_username text,
  staff_count integer,
  orders_total integer,
  orders_30d integer,
  sales_30d numeric,
  active_orders integer,
  last_order_at timestamptz,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select
    s.id,
    s.name,
    s.slug,
    s.phone,
    s.is_open,
    s.is_published,
    s.admin_suspended_at,
    s.admin_suspended_reason,
    (
      select p.username
      from public.merchant_memberships mm
      join public.profiles p on p.id = mm.user_id
      where mm.merchant_account_id = s.merchant_account_id and mm.role = 'owner'
      order by mm.active desc, mm.created_at
      limit 1
    ),
    (
      select count(*)::integer
      from public.merchant_memberships mm
      where mm.merchant_account_id = s.merchant_account_id and mm.active
    ),
    (select count(*)::integer from public.food_orders o where o.store_id = s.id),
    (
      select count(*)::integer from public.food_orders o
      where o.store_id = s.id and o.created_at >= now() - interval '30 days'
    ),
    (
      select coalesce(sum(o.total), 0) from public.food_orders o
      where o.store_id = s.id and o.status = 'delivered' and o.delivered_at >= now() - interval '30 days'
    ),
    (
      select count(*)::integer from public.food_orders o
      where o.store_id = s.id and o.status not in ('delivered', 'cancelled')
    ),
    (select max(o.created_at) from public.food_orders o where o.store_id = s.id),
    s.created_at
  from public.food_stores s
  where v_query is null
     or s.name ilike '%' || v_query || '%'
     or s.slug ilike '%' || v_query || '%'
     or coalesce(s.phone, '') ilike '%' || v_query || '%'
  order by (s.admin_suspended_at is not null) desc, s.created_at desc
  limit 500;
end;
$$;

revoke all on function public.admin_food_stores(text) from public, anon;
grant execute on function public.admin_food_stores(text) to authenticated;

create or replace function public.admin_food_store_detail(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then
    raise exception 'store not found';
  end if;

  return jsonb_build_object(
    'id', v_store.id,
    'name', v_store.name,
    'slug', v_store.slug,
    'phone', v_store.phone,
    'address', v_store.address,
    'business_hours', v_store.business_hours,
    'is_open', v_store.is_open,
    'is_published', v_store.is_published,
    'admin_suspended_at', v_store.admin_suspended_at,
    'admin_suspended_reason', v_store.admin_suspended_reason,
    'admin_suspended_by_username', (select p.username from public.profiles p where p.id = v_store.admin_suspended_by),
    'created_at', v_store.created_at,
    'orders_total', (select count(*) from public.food_orders o where o.store_id = v_store.id),
    'orders_30d', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.created_at >= now() - interval '30 days'
    ),
    'sales_30d', (
      select coalesce(sum(o.total), 0) from public.food_orders o
      where o.store_id = v_store.id and o.status = 'delivered' and o.delivered_at >= now() - interval '30 days'
    ),
    'cancelled_30d', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.status = 'cancelled' and o.created_at >= now() - interval '30 days'
    ),
    'active_orders', (
      select count(*) from public.food_orders o
      where o.store_id = v_store.id and o.status not in ('delivered', 'cancelled')
    ),
    'team', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', mm.user_id,
        'username', p.username,
        'display_name', p.display_name,
        'role', mm.role,
        'active', mm.active,
        'created_at', mm.created_at
      ) order by mm.active desc, case mm.role when 'owner' then 0 when 'admin' then 1 when 'manager' then 2 else 3 end, mm.created_at), '[]'::jsonb)
      from public.merchant_memberships mm
      left join public.profiles p on p.id = mm.user_id
      where mm.merchant_account_id = v_store.merchant_account_id
    )
  );
end;
$$;

revoke all on function public.admin_food_store_detail(uuid) from public, anon;
grant execute on function public.admin_food_store_detail(uuid) to authenticated;

-- customer data (admin only) -------------------------------------------------

create or replace function public.admin_food_orders(
  p_store_id uuid default null,
  p_status text default null,
  p_query text default null,
  p_limit integer default 100
)
returns table(
  id uuid,
  order_number text,
  store_id uuid,
  store_name text,
  status text,
  payment_status text,
  refund_status text,
  recipient_name text,
  recipient_phone text,
  total numeric,
  created_at timestamptz,
  delivered_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view Food orders';
  end if;
  if p_status is not null and p_status not in ('active', 'pending_acceptance', 'preparing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled') then
    raise exception 'Invalid order status: %', p_status;
  end if;

  return query
  select
    o.id,
    o.order_number::text,
    o.store_id,
    s.name,
    o.status,
    o.payment_status,
    o.refund_status,
    o.recipient_name,
    o.recipient_phone,
    o.total,
    o.created_at,
    o.delivered_at
  from public.food_orders o
  join public.food_stores s on s.id = o.store_id
  where (p_store_id is null or o.store_id = p_store_id)
    and (
      p_status is null
      or (p_status = 'active' and o.status not in ('delivered', 'cancelled'))
      or o.status = p_status
    )
    and (
      v_query is null
      or o.order_number::text ilike '%' || v_query || '%'
      or o.recipient_name ilike '%' || v_query || '%'
      or o.recipient_phone ilike '%' || v_query || '%'
    )
  order by o.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
end;
$$;

revoke all on function public.admin_food_orders(uuid, text, text, integer) from public, anon;
grant execute on function public.admin_food_orders(uuid, text, text, integer) to authenticated;

-- Opening an order's detail is logged: it shows customer data and evidence.
create or replace function public.admin_food_order_detail(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_order public.food_orders%rowtype;
  v_result jsonb;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can view Food orders';
  end if;
  select * into v_order from public.food_orders where id = p_order_id;
  if not found then
    raise exception 'order not found';
  end if;

  select jsonb_build_object(
    'order', to_jsonb(v_order),
    'store_name', (select s.name from public.food_stores s where s.id = v_order.store_id),
    'buyer_username', (select p.username from public.profiles p where p.id = v_order.buyer_id),
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_name', i.item_name,
        'quantity', i.quantity,
        'unit_price', i.unit_price,
        'item_note', i.item_note
      ) order by i.created_at), '[]'::jsonb)
      from public.food_order_items i where i.order_id = v_order.id
    ),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'event_type', e.event_type,
        'from_status', e.from_status,
        'to_status', e.to_status,
        'note', e.note,
        'actor_username', p.username,
        'created_at', e.created_at
      ) order by e.created_at), '[]'::jsonb)
      from public.food_order_events e
      left join public.profiles p on p.id = e.actor_id
      where e.order_id = v_order.id
    ),
    'proof', (
      select jsonb_build_object(
        'method', d.method,
        'location_note', d.location_note,
        'image_path', d.image_path,
        'created_at', d.created_at
      )
      from public.food_delivery_proofs d where d.order_id = v_order.id
    )
  ) into v_result;

  perform internal.log_audit_event(
    v_admin,
    'admin_food_order_viewed',
    v_order.buyer_id,
    jsonb_build_object('order_id', v_order.id, 'order_number', v_order.order_number, 'store_id', v_order.store_id)
  );
  return v_result;
end;
$$;

revoke all on function public.admin_food_order_detail(uuid) from public, anon;
grant execute on function public.admin_food_order_detail(uuid) to authenticated;

-- changes (admin only) ------------------------------------------------------

create or replace function public.admin_set_food_store_suspension(
  p_store_id uuid,
  p_suspend boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_store public.food_stores%rowtype;
  v_reason text := nullif(left(btrim(coalesce(p_reason, '')), 500), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can suspend stores';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'store not found';
  end if;
  if p_suspend and v_reason is null then
    raise exception 'suspension reason is required';
  end if;

  if p_suspend then
    update public.food_stores
    set admin_suspended_at = now(),
        admin_suspended_reason = v_reason,
        admin_suspended_by = v_admin,
        is_published = false,
        is_open = false
    where id = v_store.id;
  else
    -- The store stays unpublished and closed; its owner publishes again.
    update public.food_stores
    set admin_suspended_at = null,
        admin_suspended_reason = null,
        admin_suspended_by = null
    where id = v_store.id;
  end if;

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    case when p_suspend
      then 'ร้าน ' || v_store.name || ' ถูกระงับชั่วคราวโดยทีม WYNOS: ' || v_reason
      else 'ร้าน ' || v_store.name || ' ยกเลิกการระงับแล้ว เปิดร้านและเผยแพร่ได้อีกครั้งใน Wynos Merchant'
    end
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id
    and mm.active
    and mm.role in ('owner', 'admin');

  perform internal.log_audit_event(
    v_admin,
    case when p_suspend then 'admin_food_store_suspended' else 'admin_food_store_unsuspended' end,
    null,
    jsonb_build_object('store_id', v_store.id, 'store_name', v_store.name, 'reason', v_reason)
  );
end;
$$;

revoke all on function public.admin_set_food_store_suspension(uuid, boolean, text) from public, anon;
grant execute on function public.admin_set_food_store_suspension(uuid, boolean, text) to authenticated;

create or replace function public.admin_set_food_store_member_active(
  p_store_id uuid,
  p_user_id uuid,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_store public.food_stores%rowtype;
  v_member public.merchant_memberships%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can change store teams';
  end if;
  select * into v_store from public.food_stores where id = p_store_id;
  if not found or v_store.merchant_account_id is null then
    raise exception 'store not found';
  end if;
  -- One team change per merchant account at a time, so two concurrent
  -- requests cannot each switch off a different owner and leave none.
  perform 1 from public.merchant_accounts where id = v_store.merchant_account_id for update;
  select * into v_member from public.merchant_memberships
  where merchant_account_id = v_store.merchant_account_id and user_id = p_user_id
  for update;
  if not found then
    raise exception 'team member not found';
  end if;
  if not p_active and v_member.role = 'owner' and not exists (
    select 1 from public.merchant_memberships mm
    where mm.merchant_account_id = v_store.merchant_account_id
      and mm.role = 'owner' and mm.active and mm.user_id <> p_user_id
  ) then
    raise exception 'cannot deactivate the only owner';
  end if;

  update public.merchant_memberships
  set active = p_active, updated_at = now()
  where merchant_account_id = v_store.merchant_account_id and user_id = p_user_id;

  -- Keep the legacy per-store staff row in step.
  update public.food_staff
  set active = p_active
  where store_id = v_store.id and user_id = p_user_id;

  perform internal.log_audit_event(
    v_admin,
    'admin_food_staff_updated',
    p_user_id,
    jsonb_build_object('store_id', v_store.id, 'store_name', v_store.name, 'role', v_member.role, 'active', p_active)
  );
end;
$$;

revoke all on function public.admin_set_food_store_member_active(uuid, uuid, boolean) from public, anon;
grant execute on function public.admin_set_food_store_member_active(uuid, uuid, boolean) to authenticated;
