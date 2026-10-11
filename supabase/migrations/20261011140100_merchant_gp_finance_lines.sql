-- GP v1, finance lines: store income now subtracts the WYNOS GP actually
-- collected (Stripe application fee) on orders that stay paid.
--
--   income = sales_net - ad_spend + platform_funded - gp
--
-- Redefines, with the same signatures and access checks:
--   * public.merchant_finance_summary (WYN-210, store's own finance page): adds `gp`
--   * public.admin_merchant_finance_overview (Admin -> การเงินร้านค้า): adds
--     `gp`, `gp_uncollected` (GP on PromptPay slip orders, paid to the store
--     directly, so not collectable) and each store's current `gp_rate_bp`.
-- Every store is at 0% until the super admin sets a rate, so no number
-- changes when this is applied.
--
-- Requires: 20261011140000_merchant_gp_v1.sql, 20261011120000_admin_merchant_finance_overview.sql
-- Test: supabase/tests/merchant_gp_v1_test.sh, supabase/tests/admin_merchant_finance_overview_test.sh
-- ROLLBACK: re-apply supabase/migrations_wynos_merchant_finance_v1.sql and
--   supabase/migrations/20261011120000_admin_merchant_finance_overview.sql
--   (the previous definitions; nothing else depends on the new fields).

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
  -- GP v1: WYNOS GP actually collected (Stripe application fee) on orders
  -- that stay paid; a refund returns the fee to the store.
  gp as (
    select p.day, round(fsp.application_fee_satang / 100.0, 2) as amount
    from paid p
    join public.food_stripe_payments fsp on fsp.order_id = p.id
    where p.payment_status = 'paid' and fsp.application_fee_satang > 0
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

-- ------------------------------------------------------------

-- Range filters for the Admin overview (review finding: avoid scanning every
-- order when one day is picked).
create index if not exists food_orders_paid_at_idx
  on public.food_orders (paid_at) where payment_status in ('paid', 'refunded');
create index if not exists food_orders_refunded_at_idx
  on public.food_orders (refunded_at) where refunded_at is not null;
create index if not exists food_stripe_payouts_created_idx
  on public.food_stripe_payouts (stripe_created_at);
create index if not exists food_platform_settlements_created_idx
  on public.food_platform_settlements (created_at);

create or replace function public.admin_merchant_finance_overview(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  -- Bangkok day bounds as timestamptz, so the range filters can use the
  -- paid_at / refunded_at indexes below instead of scanning every order.
  v_lo timestamptz;
  v_hi timestamptz;
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
  v_lo := p_from::timestamp at time zone 'Asia/Bangkok';
  v_hi := (p_to + 1)::timestamp at time zone 'Asia/Bangkok';

  with paid as (
    select o.id, o.store_id, o.subtotal, o.delivery_fee, o.total, o.status, o.payment_status
    from public.food_orders o
    where o.payment_status in ('paid', 'refunded')
      and ((o.paid_at >= v_lo and o.paid_at < v_hi)
           or (o.paid_at is null and o.created_at >= v_lo and o.created_at < v_hi))
  ),
  paid_by_store as (
    select p.store_id,
           count(*) as orders,
           sum(p.subtotal) as food,
           sum(p.delivery_fee) as delivery,
           sum(p.subtotal + p.delivery_fee - p.total) as discounts,
           sum(p.total) as paid_total
    from paid p
    group by p.store_id
  ),
  refunded_by_store as (
    select o.store_id, count(*) as refund_count, sum(o.total) as refunds
    from public.food_orders o
    where (o.payment_status = 'refunded' or o.refund_status = 'refunded')
      and ((o.refunded_at >= v_lo and o.refunded_at < v_hi)
           or (o.refunded_at is null and o.updated_at >= v_lo and o.updated_at < v_hi))
    group by o.store_id
  ),
  ads_by_store as (
    select c.store_id, sum(c.cost) as ad_spend
    from public.food_ad_clicks c
    where c.click_day between p_from and p_to
    group by c.store_id
  ),
  funded_by_store as (
    select p.store_id, sum(foc.platform_funded) as platform_funded
    from paid p
    join public.food_order_campaigns foc on foc.order_id = p.id
    where foc.platform_funded > 0
      and foc.released_at is null
      and p.status = 'delivered'
      and p.payment_status <> 'refunded'
    group by p.store_id
  ),
  -- GP v1: collected = Stripe application fees on orders that stay paid;
  -- uncollected = GP worked out for paid non-Stripe (PromptPay slip) orders,
  -- which pay the store directly so WYNOS cannot take a fee.
  gp_by_store as (
    select p.store_id,
           round(coalesce(sum(fsp.application_fee_satang) filter (where fsp.order_id is not null), 0) / 100.0, 2) as gp,
           round(coalesce(sum(g.gp_satang) filter (where fsp.order_id is null), 0) / 100.0, 2) as gp_uncollected
    from paid p
    left join public.food_stripe_payments fsp on fsp.order_id = p.id
    cross join lateral internal.food_order_gp(p.id) g
    where p.payment_status = 'paid'
    group by p.store_id
  ),
  store_rows as (
    select
      s.id as store_id,
      s.name as store_name,
      s.is_published,
      s.admin_suspended_at is not null as suspended,
      coalesce(pb.orders, 0) as orders,
      coalesce(pb.food, 0) as food,
      coalesce(pb.delivery, 0) as delivery,
      coalesce(pb.discounts, 0) as discounts,
      coalesce(pb.paid_total, 0) as paid_total,
      coalesce(rb.refund_count, 0) as refund_count,
      coalesce(rb.refunds, 0) as refunds,
      coalesce(ab.ad_spend, 0) as ad_spend,
      coalesce(fb.platform_funded, 0) as platform_funded,
      coalesce(gb.gp, 0) as gp,
      coalesce(gb.gp_uncollected, 0) as gp_uncollected,
      coalesce((select g.rate_bp from internal.merchant_gp_rate_at(s.id, now()) g), 0) as gp_rate_bp,
      coalesce((select sum(w.amount) from internal.food_platform_owed_rows(s.id) w), 0) as platform_owed,
      (select max(ps.created_at) from public.food_platform_settlements ps where ps.store_id = s.id) as last_settled_at,
      sa.status as stripe_status,
      sa.payouts_enabled as stripe_payouts_enabled,
      sa.bank_last4 as stripe_bank_last4,
      sa.payout_interval as stripe_payout_interval,
      sa.livemode as stripe_livemode
    from public.food_stores s
    left join paid_by_store pb on pb.store_id = s.id
    left join refunded_by_store rb on rb.store_id = s.id
    left join ads_by_store ab on ab.store_id = s.id
    left join funded_by_store fb on fb.store_id = s.id
    left join gp_by_store gb on gb.store_id = s.id
    left join public.food_stripe_accounts sa on sa.store_id = s.id
  ),
  shaped as (
    select r.*,
           r.paid_total - r.refunds as sales_net,
           r.paid_total - r.refunds - r.ad_spend + r.platform_funded - r.gp as income
    from store_rows r
  ),
  payouts as (
    select p.payout_id, p.store_id, s.name as store_name, p.amount_satang, p.currency, p.status,
           p.arrival_date, p.failure_code, p.stripe_created_at
    from public.food_stripe_payouts p
    join public.food_stores s on s.id = p.store_id
    where p.stripe_created_at >= v_lo and p.stripe_created_at < v_hi
  ),
  settlements as (
    select ps.id, ps.store_id, s.name as store_name, ps.amount, ps.order_count, ps.reference,
           pr.username as settled_by_username, ps.created_at
    from public.food_platform_settlements ps
    join public.food_stores s on s.id = ps.store_id
    left join public.profiles pr on pr.id = ps.settled_by
    where ps.created_at >= v_lo and ps.created_at < v_hi
  )
  select jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'totals', (
      select jsonb_build_object(
        'stores', count(*),
        'stores_with_sales', count(*) filter (where sh.orders > 0),
        'orders', coalesce(sum(sh.orders), 0),
        'food', coalesce(sum(sh.food), 0),
        'delivery', coalesce(sum(sh.delivery), 0),
        'discounts', coalesce(sum(sh.discounts), 0),
        'refund_count', coalesce(sum(sh.refund_count), 0),
        'refunds', coalesce(sum(sh.refunds), 0),
        'sales_net', coalesce(sum(sh.sales_net), 0),
        'ad_spend', coalesce(sum(sh.ad_spend), 0),
        'platform_funded', coalesce(sum(sh.platform_funded), 0),
        'gp', coalesce(sum(sh.gp), 0),
        'gp_uncollected', coalesce(sum(sh.gp_uncollected), 0),
        'income', coalesce(sum(sh.income), 0),
        'platform_owed', coalesce(sum(sh.platform_owed), 0),
        'stores_payout_ready', count(*) filter (where sh.stripe_payouts_enabled),
        'stores_without_stripe', count(*) filter (where sh.stripe_status is null)
      )
      from shaped sh
    ),
    'stores', coalesce((
      select jsonb_agg(jsonb_build_object(
        'store_id', sh.store_id,
        'store_name', sh.store_name,
        'is_published', sh.is_published,
        'suspended', sh.suspended,
        'orders', sh.orders,
        'food', sh.food,
        'delivery', sh.delivery,
        'discounts', sh.discounts,
        'refund_count', sh.refund_count,
        'refunds', sh.refunds,
        'sales_net', sh.sales_net,
        'ad_spend', sh.ad_spend,
        'platform_funded', sh.platform_funded,
        'gp', sh.gp,
        'gp_uncollected', sh.gp_uncollected,
        'gp_rate_bp', sh.gp_rate_bp,
        'income', sh.income,
        'platform_owed', sh.platform_owed,
        'last_settled_at', sh.last_settled_at,
        'stripe_status', sh.stripe_status,
        'stripe_payouts_enabled', sh.stripe_payouts_enabled,
        'stripe_bank_last4', sh.stripe_bank_last4,
        'stripe_payout_interval', sh.stripe_payout_interval,
        'stripe_livemode', sh.stripe_livemode
      ) order by sh.sales_net desc, sh.platform_owed desc, sh.store_name)
      from shaped sh
    ), '[]'::jsonb),
    'payout_status_counts', coalesce((
      select jsonb_object_agg(x.status, x.n)
      from (select p.status, count(*) as n from payouts p group by p.status) x
    ), '{}'::jsonb),
    'payouts', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.stripe_created_at desc)
      from (
        select p.payout_id, p.store_id, p.store_name, p.amount_satang, p.currency, p.status,
               p.arrival_date, p.failure_code, p.stripe_created_at
        from payouts p
        order by p.stripe_created_at desc
        limit 200
      ) x
    ), '[]'::jsonb),
    'settlements', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (
        select st.id, st.store_id, st.store_name, st.amount, st.order_count, st.reference,
               st.settled_by_username, st.created_at
        from settlements st
        order by st.created_at desc
        limit 200
      ) x
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.admin_merchant_finance_overview(date, date) from public, anon;
grant execute on function public.admin_merchant_finance_overview(date, date) to authenticated;
