-- ZOKY-FULFILL-001: Zoky Admin order list with fulfilment and payment method.
-- Founder approval 2026-10-26 (.wyn/company/APPROVALS.md). Needs
-- 20261026120000_zoky_fulfill_001.sql (the new food_orders columns).
--
-- Additive: admin_food_orders (v1) is unchanged; v2 returns the same rows
-- plus fulfillment_type, payment_method, pickup_at, pickup_code and
-- cancel_requested_at, and accepts three more filters: pickup, cod and
-- cancel_request. The admin app falls back to v1 while v2 is missing.
-- admin_food_order_detail already returns to_jsonb(order), so the new columns
-- reach the detail page without a change.
-- ROLLBACK: supabase/rollbacks/20261026130000_zoky_fulfill_001_admin_rollback.sql

create or replace function public.admin_food_orders_v2(
  p_store_id uuid default null, p_status text default null, p_query text default null, p_limit integer default 100
) returns table(
  id uuid, order_number text, store_id uuid, store_name text, status text, payment_status text, refund_status text,
  recipient_name text, recipient_phone text, total numeric, created_at timestamptz, delivered_at timestamptz,
  fulfillment_type text, payment_method text, pickup_at timestamptz, pickup_code text, cancel_requested_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if not internal.has_admin_permission('food', 'edit') then
    raise exception 'Only admins can view Food orders';
  end if;
  if p_status is not null and p_status not in (
    'active', 'pending_acceptance', 'preparing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled',
    'refund_pending', 'payment_review', 'pickup', 'cod', 'cancel_request'
  ) then
    raise exception 'Invalid order status: %', p_status;
  end if;

  return query
  select
    o.id, o.order_number::text, o.store_id, s.name, o.status, o.payment_status, o.refund_status,
    o.recipient_name, o.recipient_phone, o.total, o.created_at, o.delivered_at,
    o.fulfillment_type, o.payment_method, o.pickup_at, o.pickup_code, o.cancel_requested_at
  from public.food_orders o
  join public.food_stores s on s.id = o.store_id
  where (p_store_id is null or o.store_id = p_store_id)
    and (
      p_status is null
      or (p_status = 'active' and o.status not in ('delivered', 'cancelled'))
      or (p_status = 'refund_pending' and o.refund_status in ('pending', 'failed'))
      or (p_status = 'payment_review' and o.payment_status in ('submitted', 'issue'))
      or (p_status = 'pickup' and o.fulfillment_type = 'pickup')
      or (p_status = 'cod' and o.payment_method = 'cod')
      or (p_status = 'cancel_request' and o.cancel_requested_at is not null and o.status <> 'cancelled')
      or o.status = p_status
    )
    and (
      v_query is null
      or o.order_number::text ilike '%' || v_query || '%'
      or o.recipient_name ilike '%' || v_query || '%'
      or o.recipient_phone ilike '%' || v_query || '%'
      or o.pickup_code ilike v_query
    )
  order by o.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
end;
$$;
revoke all on function public.admin_food_orders_v2(uuid, text, text, integer) from public, anon;
grant execute on function public.admin_food_orders_v2(uuid, text, text, integer) to authenticated;
