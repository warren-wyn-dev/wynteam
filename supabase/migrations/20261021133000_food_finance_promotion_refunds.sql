-- Reduce unsettled promotion subsidies by the cumulative successful returned
-- item value. Pending/rejected provider operations never alter entitlements.
create function internal.food_finance_retained_funding(p_order_id uuid)
returns numeric language sql stable set search_path='' as $$
select case when o.payment_status='refunded' or o.status='cancelled' then 0
else greatest(0,round(foc.platform_funded*100)::bigint-
 floor((least(round(o.subtotal*100)::bigint,coalesce((select sum(round(i.unit_price*100)::bigint*(x->>'quantity')::integer)
 from internal.food_finance_refunds r cross join lateral jsonb_array_elements(r.items) x
 join public.food_order_items i on i.id=(x->>'item_id')::uuid and i.order_id=r.order_id
 where r.order_id=o.id and r.state='succeeded' and r.kind='items'),0))*round(foc.platform_funded*100)::bigint
 +round(o.subtotal*100)::bigint/2)/greatest(1,round(o.subtotal*100)::bigint)))/100.0 end
from public.food_orders o join public.food_order_campaigns foc on foc.order_id=o.id where o.id=p_order_id;
$$;
revoke all on function internal.food_finance_retained_funding(uuid) from public,anon,authenticated;

create or replace function internal.food_platform_owed_rows(p_store_id uuid)
returns table(order_id uuid,platform_campaign_id uuid,amount numeric)
language sql stable set search_path='' as $$
select foc.order_id,foc.platform_campaign_id,internal.food_finance_retained_funding(o.id)
from public.food_order_campaigns foc join public.food_orders o on o.id=foc.order_id
where o.store_id=p_store_id and foc.platform_funded>0 and foc.released_at is null and foc.settlement_id is null
and o.status='delivered' and o.payment_status<>'refunded'
and internal.food_finance_retained_funding(o.id)>0;
$$;
revoke all on function internal.food_platform_owed_rows(uuid) from public,anon,authenticated;

create or replace function public.merchant_finance_summary(p_store_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer;
  v_prev_from date;
  v_prev_to date;
  v_result jsonb;
begin
  -- Checked here, not with merchant_has_store_role(): that helper also lets
  -- every developer account into any store and ignores roles for legacy
  -- food_staff rows. Money is for this store's managers only.
  if (select auth.uid()) is null or not (
    exists (
      select 1
      from public.food_stores s
      join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
      where s.id = p_store_id
        and mm.user_id = (select auth.uid())
        and mm.active
        and mm.role in ('owner', 'admin', 'manager')
    )
    or exists (
      select 1
      from public.food_staff fs
      where fs.store_id = p_store_id
        and fs.user_id = (select auth.uid())
        and fs.active
        and fs.role = 'owner'
    )
  ) then
    raise exception 'merchant manager access required';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range';
  end if;
  v_days := p_to - p_from + 1;
  if v_days > 366 then
    raise exception 'date range is too long';
  end if;
  v_prev_to := p_from - 1;
  v_prev_from := p_from - v_days;

  with paid as (
    select o.id, (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date as day,
           o.subtotal, o.delivery_fee, o.total, o.status, o.payment_status, o.payment_provider
    from public.food_orders o
    where o.store_id = p_store_id
      and o.payment_status in ('paid', 'refunded')
      and (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  refunded as (
    select (r.completed_at at time zone 'Asia/Bangkok')::date as day,
      (r.food_satang+r.delivery_satang)/100.0 as total
    from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id
    where o.store_id=p_store_id and r.state='succeeded'
      and (r.completed_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
    union all
    select (coalesce(o.refunded_at,o.updated_at) at time zone 'Asia/Bangkok')::date,o.total
    from public.food_orders o where o.store_id=p_store_id
      and (o.payment_status='refunded' or o.refund_status='refunded')
      and not exists(select 1 from internal.food_finance_refunds r where r.order_id=o.id and r.state='succeeded')
      and (coalesce(o.refunded_at,o.updated_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  ads as (
    select c.click_day as day, c.cost
    from public.food_ad_clicks c
    where c.store_id = p_store_id and c.click_day between v_prev_from and p_to
  ),
  -- GP v1, booked like sales and refunds. Collected: the application fee of
  -- an order that was really paid through Stripe (payment_provider 'stripe'),
  -- on the day it was paid. Returned: only the fee WYNOS actually refunded
  -- (merchant-stripe-refund with refund_application_fee), on the day it was
  -- refunded. Neither reads the Stripe ledger status, which a late webhook
  -- from an older checkout attempt can rewrite, and a refund made outside
  -- WYNOS (e.g. the Stripe Dashboard) does not return the fee.
  gp as (
    select p.day,round(fsp.application_fee_satang/100.0,2) as amount
    from paid p join public.food_stripe_payments fsp on fsp.order_id=p.id
    where p.payment_provider='stripe' and fsp.application_fee_satang>0
    union all
    select (r.completed_at at time zone 'Asia/Bangkok')::date,-r.gp_satang/100.0
    from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id
    where o.store_id=p_store_id and r.state='succeeded'
      and (r.completed_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
    union all
    select (fsp.application_fee_refunded_at at time zone 'Asia/Bangkok')::date,-fsp.application_fee_refunded_satang/100.0
    from public.food_stripe_payments fsp join public.food_orders o on o.id=fsp.order_id
    where o.store_id=p_store_id and fsp.application_fee_refunded_satang>0
      and not exists(select 1 from internal.food_finance_refunds r where r.order_id=o.id and r.state='succeeded')
      and (fsp.application_fee_refunded_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  funded as (
    select p.day, internal.food_finance_retained_funding(p.id) as amount
    from paid p
    join public.food_order_campaigns foc on foc.order_id = p.id
    where foc.platform_funded > 0
      and foc.released_at is null
      and p.status = 'delivered'
      and p.payment_status <> 'refunded'
  ),
  days as (
    select d::date as day,
      (select count(*) from paid p where p.day = d::date) as orders,
      coalesce((select sum(p.subtotal) from paid p where p.day = d::date), 0) as food,
      coalesce((select sum(p.delivery_fee) from paid p where p.day = d::date), 0) as delivery,
      coalesce((select sum(p.subtotal + p.delivery_fee - p.total) from paid p where p.day = d::date), 0) as discounts,
      coalesce((select sum(p.total) from paid p where p.day = d::date), 0) as paid_total,
      (select count(*) from refunded r where r.day = d::date) as refund_count,
      coalesce((select sum(r.total) from refunded r where r.day = d::date), 0) as refunds,
      coalesce((select sum(a.cost) from ads a where a.day = d::date), 0) as ad_spend,
      coalesce((select sum(f.amount) from funded f where f.day = d::date), 0) as platform_funded,
      coalesce((select sum(g.amount) from gp g where g.day = d::date), 0) as gp
    from generate_series(v_prev_from, p_to, interval '1 day') as d
  ),
  shaped as (
    select day, orders, food, delivery, discounts, refund_count, refunds,
           paid_total - refunds as sales_net, ad_spend, platform_funded, gp,
           paid_total - refunds - ad_spend + platform_funded - gp as income
    from days
  ),
  cur as (select * from shaped where day between p_from and p_to),
  prev as (select * from shaped where day between v_prev_from and v_prev_to)
  select jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'orders', (select coalesce(sum(orders), 0) from cur),
    'food', (select coalesce(sum(food), 0) from cur),
    'delivery', (select coalesce(sum(delivery), 0) from cur),
    'discounts', (select coalesce(sum(discounts), 0) from cur),
    'refund_count', (select coalesce(sum(refund_count), 0) from cur),
    'refunds', (select coalesce(sum(refunds), 0) from cur),
    'sales_net', (select coalesce(sum(sales_net), 0) from cur),
    'ad_spend', (select coalesce(sum(ad_spend), 0) from cur),
    'platform_funded', (select coalesce(sum(platform_funded), 0) from cur),
    'gp', (select coalesce(sum(gp), 0) from cur),
    'income', (select coalesce(sum(income), 0) from cur),
    'prev_sales_net', (select coalesce(sum(sales_net), 0) from prev),
    'prev_orders', (select coalesce(sum(orders), 0) from prev),
    'days', coalesce((select jsonb_agg(jsonb_build_object(
        'day', day, 'orders', orders, 'food', food, 'delivery', delivery, 'discounts', discounts,
        'refunds', refunds, 'sales_net', sales_net, 'ad_spend', ad_spend,
        'platform_funded', platform_funded, 'gp', gp, 'income', income) order by day) from cur), '[]'::jsonb),
    'pending_slip_count', (select count(*) from public.food_orders o
      where o.store_id = p_store_id and o.payment_status = 'submitted' and o.status <> 'cancelled'),
    'pending_slip_total', coalesce((select sum(o.total) from public.food_orders o
      where o.store_id = p_store_id and o.payment_status = 'submitted' and o.status <> 'cancelled'), 0),
    'platform_owed', coalesce((select sum(w.amount) from internal.food_platform_owed_rows(p_store_id) w), 0)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.merchant_finance_summary(uuid, date, date) from public, anon;
grant execute on function public.merchant_finance_summary(uuid, date, date) to authenticated;
