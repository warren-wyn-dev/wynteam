-- WYNOS Admin: Merchant Finance overview (WYNOS Merchant -> การเงินร้านค้า).
--
-- Read only and additive: one new function, no table, policy or existing
-- function changes.
--
-- What it returns for a Bangkok date range (max 366 days):
--   * per store, the same money lines the store's own finance page shows
--     (public.merchant_finance_summary, WYN-210) so Admin and
--     merchant.wynos.online never disagree:
--       sales      = orders paid in the range (payment_status paid/refunded, by paid_at)
--       food/delivery/discounts (subtotal + delivery_fee - total)
--       refunds    = totals of orders refunded in the range (by refunded_at)
--       sales_net  = paid totals - refunds
--       ad_spend   = food_ad_clicks charged in the range
--       platform_funded = WYNOS campaign share of delivered, not refunded orders
--       income     = sales_net - ad_spend + platform_funded
--   * per store, what WYNOS still owes today (internal.food_platform_owed_rows,
--     WYN-206) and the Stripe Connect payout readiness (bank last 4 digits only);
--   * Stripe payouts and WYNOS campaign settlements created in the range.
--
-- There is no GP / commission here: WYNOS does not take one today. A GP model
-- needs Founder business decisions first (see
-- docs/engineering/WYNOS-ADMIN-MASTER-GAP-ANALYSIS.md).
--
-- Never returned: bank account numbers, PromptPay IDs, Stripe account IDs,
-- customer data.
--
-- Access: merchant:view (WYN-219), checked inside the function.
-- Test: supabase/tests/admin_merchant_finance_overview_test.sh
-- ROLLBACK: supabase/rollbacks/20261011120000_admin_merchant_finance_overview_rollback.sql

create or replace function public.admin_merchant_finance_overview(p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
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

  with paid as (
    select o.id, o.store_id, o.subtotal, o.delivery_fee, o.total, o.status, o.payment_status
    from public.food_orders o
    where o.payment_status in ('paid', 'refunded')
      and (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
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
      and (coalesce(o.refunded_at, o.updated_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
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
    left join public.food_stripe_accounts sa on sa.store_id = s.id
  ),
  shaped as (
    select r.*,
           r.paid_total - r.refunds as sales_net,
           r.paid_total - r.refunds - r.ad_spend + r.platform_funded as income
    from store_rows r
  ),
  payouts as (
    select p.payout_id, p.store_id, s.name as store_name, p.amount_satang, p.currency, p.status,
           p.arrival_date, p.failure_code, p.stripe_created_at
    from public.food_stripe_payouts p
    join public.food_stores s on s.id = p.store_id
    where (p.stripe_created_at at time zone 'Asia/Bangkok')::date between p_from and p_to
  ),
  settlements as (
    select ps.id, ps.store_id, s.name as store_name, ps.amount, ps.order_count, ps.reference,
           pr.username as settled_by_username, ps.created_at
    from public.food_platform_settlements ps
    join public.food_stores s on s.id = ps.store_id
    left join public.profiles pr on pr.id = ps.settled_by
    where (ps.created_at at time zone 'Asia/Bangkok')::date between p_from and p_to
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
