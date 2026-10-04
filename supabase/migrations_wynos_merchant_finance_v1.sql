-- WYN-210: Wynos Merchant finance summary for any date range.
--
-- Founder decisions:
-- * finance page shows a summary for today, yesterday, this week, this month
--   or any range picked on a calendar;
-- * two headline numbers: ยอดขายสุทธิ (net sales) and รายได้ร้าน (store income);
-- * "เงินที่ WYNOS จะโอนให้ร้าน" (WYNOS campaign share not yet paid) shows
--   only when it is above zero.
--
-- Definitions (money in and out of the store, Bangkok days):
-- * sales: orders paid in the range (payment_status paid or refunded, by
--   paid_at). food = subtotal, delivery = delivery_fee, discounts =
--   subtotal + delivery_fee - total, so the lines always add up.
-- * refunds: totals of orders refunded in the range (by refunded_at).
-- * net sales = sum(total) - refunds.
-- * ad spend: food_ad_clicks charged in the range.
-- * WYNOS share: platform_funded of delivered, not refunded, orders paid in
--   the range (still counted after WYNOS has settled it).
-- * income = net sales - ad spend + WYNOS share.
--
-- Read only. Owner, admin and manager of the store only (legacy food_staff:
-- owner only); developer accounts get no cross-store access here.

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
           o.subtotal, o.delivery_fee, o.total, o.status, o.payment_status
    from public.food_orders o
    where o.store_id = p_store_id
      and o.payment_status in ('paid', 'refunded')
      and (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  refunded as (
    select (coalesce(o.refunded_at, o.updated_at) at time zone 'Asia/Bangkok')::date as day, o.total
    from public.food_orders o
    where o.store_id = p_store_id
      and (o.payment_status = 'refunded' or o.refund_status = 'refunded')
      and (coalesce(o.refunded_at, o.updated_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  ads as (
    select c.click_day as day, c.cost
    from public.food_ad_clicks c
    where c.store_id = p_store_id and c.click_day between v_prev_from and p_to
  ),
  funded as (
    select p.day, foc.platform_funded as amount
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
      coalesce((select sum(f.amount) from funded f where f.day = d::date), 0) as platform_funded
    from generate_series(v_prev_from, p_to, interval '1 day') as d
  ),
  shaped as (
    select day, orders, food, delivery, discounts, refund_count, refunds,
           paid_total - refunds as sales_net, ad_spend, platform_funded,
           paid_total - refunds - ad_spend + platform_funded as income
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
    'income', (select coalesce(sum(income), 0) from cur),
    'prev_sales_net', (select coalesce(sum(sales_net), 0) from prev),
    'prev_orders', (select coalesce(sum(orders), 0) from prev),
    'days', coalesce((select jsonb_agg(jsonb_build_object(
        'day', day, 'orders', orders, 'food', food, 'delivery', delivery, 'discounts', discounts,
        'refunds', refunds, 'sales_net', sales_net, 'ad_spend', ad_spend,
        'platform_funded', platform_funded, 'income', income) order by day) from cur), '[]'::jsonb),
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
