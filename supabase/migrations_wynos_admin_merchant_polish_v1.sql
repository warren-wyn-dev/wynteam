-- WYN-214: WYNOS Admin Merchant polish (Founder "ทำต่อ" after the WYN-213
-- audit). Read-only changes to two admin RPCs:
-- * admin_food_store_detail also returns the store pin, delivery radius,
--   whether the pin is inside the WYNOS Food service area (WYN-211) and the
--   readiness items still missing before the store can publish.
-- * admin_food_orders gains two filters: refund_pending (refund requested
--   or failed) and payment_review (slip waiting or payment issue).
-- Same admin/moderator rules as before; no data changes.

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
    -- WYN-214: where the store is pinned and whether it may sell (WYN-211).
    'latitude', v_store.latitude,
    'longitude', v_store.longitude,
    'delivery_radius_km', v_store.delivery_radius_km,
    'in_service_area', internal.food_in_service_area(v_store.latitude, v_store.longitude),
    'readiness_missing', to_jsonb(coalesce(internal.food_store_readiness_missing(v_store.id), array[]::text[])),
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
  if p_status is not null and p_status not in ('active', 'pending_acceptance', 'preparing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled', 'refund_pending', 'payment_review') then
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
      -- WYN-214: money that still needs someone.
      or (p_status = 'refund_pending' and o.refund_status in ('pending', 'failed'))
      or (p_status = 'payment_review' and o.payment_status in ('submitted', 'issue'))
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
