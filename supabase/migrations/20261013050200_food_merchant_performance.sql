-- Read-only operational metrics. Existing merchant_finance_summary remains the
-- sole source for sales, fees, GP and income; this RPC does not calculate money.
-- Requires 20261013045900_food_checkout_integrity.sql. Rollout starts OFF.
begin;

insert into public.food_development_features(name, enabled, developer_only)
values ('merchant_performance', false, true)
on conflict (name) do nothing;

create or replace function public.merchant_order_performance(p_store_id uuid, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_start timestamptz;
  v_end timestamptz;
begin
  -- Require actual membership as well as the helper, so an installation with
  -- a pre-WYN-213 helper cannot rely on a historical developer bypass.
  if auth.uid() is null
     or public.merchant_has_store_role(p_store_id, array['owner','admin','manager']) is not true
     or not (
       exists (select 1 from public.food_stores s
         join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
         where s.id = p_store_id and m.user_id = auth.uid() and m.active
           and m.role in ('owner','admin','manager'))
       or exists (select 1 from public.food_staff f where f.store_id = p_store_id
         and f.user_id = auth.uid() and f.active and f.role = 'owner')
     ) then raise exception 'merchant manager access required'; end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range';
  end if;
  if p_to - p_from + 1 > 366 then raise exception 'date range is too long'; end if;
  if internal.food_development_feature_enabled('merchant_performance') is not true then
    raise exception 'merchant performance is not enabled';
  end if;
  -- Half-open UTC bounds retain the existing (store_id, created_at) index and
  -- count the inclusive calendar range in Bangkok, rather than server timezone.
  v_start := p_from::timestamp at time zone 'Asia/Bangkok';
  v_end := (p_to + 1)::timestamp at time zone 'Asia/Bangkok';

  with orders as materialized (
    select o.id, o.status, o.payment_status, o.accepted_at, o.ready_at,
      (o.payment_status in ('submitted','paid','refunded') or o.paid_at is not null) as eligible,
      exists (
        select 1 from public.food_order_events e
        where e.order_id = o.id and e.to_status = 'cancelled'
          and e.event_type = 'status_changed' and e.actor_id is not null
          and e.actor_id is distinct from o.buyer_id
          and (
            exists (select 1 from public.food_stores s
              join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
              where s.id = p_store_id and m.user_id = e.actor_id and m.active
                and m.role in ('owner','admin','manager','orders','delivery'))
            or exists (select 1 from public.food_staff f
              where f.store_id = p_store_id and f.user_id = e.actor_id and f.active)
          )
      ) as merchant_cancelled
    from public.food_orders o
    where o.store_id = p_store_id and o.created_at >= v_start and o.created_at < v_end
  ), stats as (
    select count(*) as total_orders,
      count(*) filter (where status = 'delivered') as completed_orders,
      count(*) filter (where status = 'cancelled') as cancelled_orders,
      count(*) filter (where eligible) as acceptance_eligible_orders,
      count(*) filter (where eligible and accepted_at is not null) as accepted_orders,
      count(*) filter (where eligible and status = 'cancelled' and merchant_cancelled) as merchant_cancelled_orders,
      count(*) filter (where status = 'cancelled' and not merchant_cancelled) as unattributed_cancelled_orders,
      count(*) filter (where accepted_at is not null and ready_at >= accepted_at) as preparation_samples,
      round((avg(extract(epoch from (ready_at - accepted_at)) / 60.0)
        filter (where accepted_at is not null and ready_at >= accepted_at))::numeric, 2) as average_preparation_minutes
    from orders
  ), top_items as (
    -- Delivered but unpaid/refunded orders do not count as successful menu sales.
    -- Snapshot names preserve history even after a menu is renamed or deleted.
    select i.menu_item_id, i.item_name, sum(i.quantity) as quantity, count(distinct i.order_id) as orders
    from public.food_order_items i join orders o on o.id = i.order_id
    where o.status = 'delivered' and o.payment_status = 'paid'
    group by i.menu_item_id, i.item_name
    order by sum(i.quantity) desc, i.item_name, i.menu_item_id
    limit 10
  )
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'cohort', 'created_at_bangkok',
    'total_orders', s.total_orders, 'completed_orders', s.completed_orders,
    'cancelled_orders', s.cancelled_orders,
    'acceptance_eligible_orders', s.acceptance_eligible_orders, 'accepted_orders', s.accepted_orders,
    'acceptance_rate', case when s.acceptance_eligible_orders = 0 then null
      else round(100.0 * s.accepted_orders / s.acceptance_eligible_orders, 2) end,
    'acceptance_denominator', 'submitted_paid_refunded_or_paid_at',
    'merchant_cancelled_orders', s.merchant_cancelled_orders,
    'merchant_cancel_rate', case when s.acceptance_eligible_orders = 0 then null
      else round(100.0 * s.merchant_cancelled_orders / s.acceptance_eligible_orders, 2) end,
    'unattributed_cancelled_orders', s.unattributed_cancelled_orders,
    'cancellation_attribution', 'current_active_membership_status_event_excluding_buyer',
    'preparation_samples', s.preparation_samples,
    'average_preparation_minutes', s.average_preparation_minutes,
    'top_items', coalesce((select jsonb_agg(jsonb_build_object(
      'menu_item_id', t.menu_item_id, 'item_name', t.item_name, 'quantity', t.quantity, 'orders', t.orders)
      order by t.quantity desc, t.item_name, t.menu_item_id) from top_items t), '[]'::jsonb)
  ) into v_result from stats s;
  return v_result;
end;
$$;
revoke all on function public.merchant_order_performance(uuid,date,date) from public, anon;
grant execute on function public.merchant_order_performance(uuid,date,date) to authenticated;
comment on function public.merchant_order_performance(uuid,date,date) is
  'Read-only Bangkok created-order cohort; acceptance denominator excludes unsubmitted unpaid orders. Merchant cancellation attribution uses current active memberships, not historical role snapshots. Financial totals use merchant_finance_summary.';

commit;
