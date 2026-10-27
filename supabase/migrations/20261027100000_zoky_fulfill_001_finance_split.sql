-- ZOKY-FULFILL-001: Zoky Admin finance split by fulfilment mode and payment
-- method (technical design, "Reports / GP"). Read only and additive: one new
-- function, no table, policy or existing function change.
--
-- Same money lines as admin_merchant_finance_overview, for a Bangkok date range
-- (max 366 days), grouped by fulfillment_type x payment_method:
--   orders/paid_total = orders paid in the range (payment_status paid/refunded, by paid_at)
--   refunds           = totals of orders refunded in the range (by refunded_at)
--   sales_net         = paid_total - refunds
-- GP is not split: COD orders carry no GP (they are paid to the store directly).
--
-- Access: merchant:view, checked inside the function. No customer data.
-- Test: supabase/tests/zoky_fulfill_001_test.sh
-- ROLLBACK: supabase/rollbacks/20261027100000_zoky_fulfill_001_finance_split_rollback.sql

create or replace function public.admin_food_finance_split(p_from date, p_to date)
returns table(
  fulfillment_type text,
  payment_method text,
  orders bigint,
  paid_total numeric,
  refund_count bigint,
  refunds numeric,
  sales_net numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range';
  end if;
  if p_to - p_from + 1 > 366 then
    raise exception 'date range is too long';
  end if;

  return query
  with paid as (
    select o.fulfillment_type, o.payment_method, count(*) as orders, sum(o.total) as paid_total
    from public.food_orders o
    where o.payment_status in ('paid', 'refunded')
      and (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
    group by 1, 2
  ),
  refunded as (
    select o.fulfillment_type, o.payment_method, count(*) as refund_count, sum(o.total) as refunds
    from public.food_orders o
    where (o.payment_status = 'refunded' or o.refund_status = 'refunded')
      and (coalesce(o.refunded_at, o.updated_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
    group by 1, 2
  ),
  modes as (
    select m.fulfillment_type, m.payment_method
    from (values ('delivery', 'transfer'), ('delivery', 'cod'), ('pickup', 'transfer')) as m(fulfillment_type, payment_method)
    union
    select p.fulfillment_type, p.payment_method from paid p
    union
    select r.fulfillment_type, r.payment_method from refunded r
  )
  select m.fulfillment_type,
         m.payment_method,
         coalesce(p.orders, 0)::bigint,
         coalesce(p.paid_total, 0)::numeric,
         coalesce(r.refund_count, 0)::bigint,
         coalesce(r.refunds, 0)::numeric,
         (coalesce(p.paid_total, 0) - coalesce(r.refunds, 0))::numeric
  from modes m
  left join paid p on p.fulfillment_type = m.fulfillment_type and p.payment_method = m.payment_method
  left join refunded r on r.fulfillment_type = m.fulfillment_type and r.payment_method = m.payment_method
  order by m.fulfillment_type, m.payment_method;
end;
$$;
revoke all on function public.admin_food_finance_split(date, date) from public, anon;
grant execute on function public.admin_food_finance_split(date, date) to authenticated;
