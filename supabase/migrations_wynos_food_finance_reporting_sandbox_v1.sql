-- WYNOS Finance Reporting v1; QA-only pcatuxtenluqzjzzwsvl.
-- Read-only simulated projections and append-only refund events. No money movement.
-- Snapshot and refund event dates are evaluated INDEPENDENTLY for the requested period.
-- No assumed Stripe fees, net payouts, GP defaults or real GP income.

create or replace function public.food_finance_report_core_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_stores jsonb; v_totals jsonb;
begin
  if p_from is null or p_to is null or p_from >= p_to
     or p_to - p_from > interval '366 days' then
    raise exception 'Invalid reporting range (max 366 days)' using errcode='22023';
  end if;
  with events as (
    select p.store_id, 1::bigint orders, 0::bigint refunds,
      p.customer_paid_satang customer, p.food_gross_satang food,
      p.delivery_fee_satang delivery, p.unallocated_discount_satang discount,
      p.estimated_platform_gp_satang gp, p.estimated_store_food_satang merchant_food,
      0::bigint customer_refund, 0::bigint gp_reversal,
      0::bigint merchant_reversal, 0::bigint delivery_refund
    from public.food_finance_order_projections_qa p
    where p.created_at >= p_from and p.created_at < p_to
      and (p_store_id is null or p.store_id = p_store_id)
    union all
    select a.store_id, 0, 1, 0, 0, 0, 0, 0, 0,
      a.customer_refund_satang, a.estimated_platform_gp_reversal_satang,
      a.estimated_store_food_reversal_satang, a.delivery_refund_satang
    from public.food_finance_refund_adjustments_qa a
    where a.created_at >= p_from and a.created_at < p_to
      and (p_store_id is null or a.store_id = p_store_id)
  ), by_store as (
    select store_id, sum(orders) orders, sum(refunds) refunds,
      sum(customer) customer, sum(food) food, sum(delivery) delivery,
      sum(discount) discount, sum(gp) gp, sum(merchant_food) merchant_food,
      sum(customer_refund) customer_refund, sum(gp_reversal) gp_reversal,
      sum(merchant_reversal) merchant_reversal, sum(delivery_refund) delivery_refund
    from events group by store_id
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'store_id', b.store_id, 'store_name', s.name,
      'projection_count', b.orders, 'refund_event_count', b.refunds,
      'projected_customer_paid_satang', b.customer,
      'projected_food_gross_satang', b.food,
      'projected_delivery_fee_satang', b.delivery,
      'unallocated_discount_satang', b.discount,
      'estimated_platform_gp_satang', b.gp,
      'estimated_merchant_food_satang', b.merchant_food,
      'simulated_customer_refund_satang', b.customer_refund,
      'simulated_gp_reversal_satang', b.gp_reversal,
      'simulated_merchant_food_reversal_satang', b.merchant_reversal,
      'simulated_delivery_refund_satang', b.delivery_refund,
      'period_gp_projection_less_reversals_satang', b.gp-b.gp_reversal,
      'period_merchant_food_projection_less_reversals_satang',
         b.merchant_food-b.merchant_reversal
    ) order by s.name,b.store_id), '[]'::jsonb),
    jsonb_build_object(
      'projection_count',coalesce(sum(b.orders),0),
      'refund_event_count',coalesce(sum(b.refunds),0),
      'projected_customer_paid_satang',coalesce(sum(b.customer),0),
      'projected_food_gross_satang',coalesce(sum(b.food),0),
      'projected_delivery_fee_satang',coalesce(sum(b.delivery),0),
      'unallocated_discount_satang',coalesce(sum(b.discount),0),
      'estimated_platform_gp_satang',coalesce(sum(b.gp),0),
      'estimated_merchant_food_satang',coalesce(sum(b.merchant_food),0),
      'simulated_customer_refund_satang',coalesce(sum(b.customer_refund),0),
      'simulated_gp_reversal_satang',coalesce(sum(b.gp_reversal),0),
      'simulated_merchant_food_reversal_satang',coalesce(sum(b.merchant_reversal),0),
      'simulated_delivery_refund_satang',coalesce(sum(b.delivery_refund),0),
      'period_gp_projection_less_reversals_satang',
        coalesce(sum(b.gp-b.gp_reversal),0),
      'period_merchant_food_projection_less_reversals_satang',
        coalesce(sum(b.merchant_food-b.merchant_reversal),0)
    )
  into v_stores, v_totals
  from by_store b join public.food_stores s on s.id = b.store_id;
  return jsonb_build_object(
    'mode','simulation_only','currency','thb',
    'from_inclusive',p_from,'to_exclusive',p_to,
    'projection_date_basis','finance_projection_created_at',
    'adjustment_date_basis','refund_adjustment_created_at',
    'selected_store_id',p_store_id,
    'totals',v_totals,'stores',v_stores,
    'stripe_processing_fee_satang',null,'stripe_fee_status','unknown',
    'merchant_net_payout_satang',null,'merchant_payout_status','not_reconciled',
    'gp_collected_status','simulation_only_not_revenue',
    'warning','Period projections and refund events are independently dated; period deltas are simulations, NOT settlements'
  );
end;
$$;

create or replace function public.food_finance_events_core_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid,
  p_limit integer, p_offset integer
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_items jsonb; v_count bigint;
begin
  if p_from is null or p_to is null or p_from >= p_to
     or p_to - p_from > interval '366 days'
     or p_limit is null or p_limit not between 1 and 100
     or p_offset is null or p_offset not between 0 and 100000 then
    raise exception 'Invalid reporting range or pagination' using errcode='22023';
  end if;
  with events as (
    select p.created_at as at, p.order_id as event_id,
      jsonb_build_object(
        'type','finance_projection','event_at',p.created_at,
        'order_id',p.order_id,'order_number',p.order_number,
        'store_id',p.store_id,'currency','thb',
        'projected_customer_paid_satang',p.customer_paid_satang,
        'projected_food_gross_satang',p.food_gross_satang,
        'projected_delivery_fee_satang',p.delivery_fee_satang,
        'unallocated_discount_satang',p.unallocated_discount_satang,
        'frozen_gp_rate_bps',p.gp_rate_bps,
        'estimated_platform_gp_satang',p.estimated_platform_gp_satang,
        'estimated_merchant_food_satang',p.estimated_store_food_satang,
        'stripe_processing_fee_satang',null,'stripe_fee_status','unknown',
        'merchant_net_payout_satang',null,'merchant_payout_status','not_reconciled',
        'mode','simulation_only') as item
    from public.food_finance_order_projections_qa p
    where p.created_at >= p_from and p.created_at < p_to
      and (p_store_id is null or p.store_id = p_store_id)
    union all
    select a.created_at, a.id,
      jsonb_build_object(
        'type','refund_adjustment','event_at',a.created_at,'id',a.id,
        'order_id',a.order_id,'store_id',a.store_id,
        'simulation_key',a.simulation_key,'reason',a.reason,
        'sequence_number',a.sequence_number,'refund_kind',a.refund_kind,
        'simulated_customer_refund_satang',a.customer_refund_satang,
        'simulated_food_refund_satang',a.food_refund_satang,
        'simulated_delivery_refund_satang',a.delivery_refund_satang,
        'simulated_gp_reversal_satang',a.estimated_platform_gp_reversal_satang,
        'simulated_merchant_food_reversal_satang',a.estimated_store_food_reversal_satang,
        'cumulative_customer_refund_satang',a.cumulative_customer_refund_satang,
        'cumulative_gp_reversal_satang',a.cumulative_gp_reversal_satang,
        'remaining_customer_paid_satang',a.remaining_customer_paid_satang,
        'stripe_fee_refund_satang',null,'stripe_fee_status','unknown',
        'merchant_net_payout_satang',null,'merchant_payout_status','not_reconciled',
        'mode','simulation_only')
    from public.food_finance_refund_adjustments_qa a
    where a.created_at >= p_from and a.created_at < p_to
      and (p_store_id is null or a.store_id = p_store_id)
  ), page as (
    select * from events order by at desc,event_id desc
    limit p_limit offset p_offset
  )
  select coalesce(jsonb_agg(item order by at desc,event_id desc),'[]'::jsonb)
    into v_items from page;
  select count(*) into v_count from (
    select p.order_id from public.food_finance_order_projections_qa p
    where p.created_at >= p_from and p.created_at < p_to
      and (p_store_id is null or p.store_id = p_store_id)
    union all
    select a.order_id from public.food_finance_refund_adjustments_qa a
    where a.created_at >= p_from and a.created_at < p_to
      and (p_store_id is null or a.store_id = p_store_id)
  ) x;
  return jsonb_build_object(
    'mode','simulation_only','currency','thb',
    'from_inclusive',p_from,'to_exclusive',p_to,
    'total_events',v_count,'limit',p_limit,'offset',p_offset,'events',v_items
  );
end;
$$;

-- Administrative access requires the independent QA GP allowlist.
create or replace function public.admin_food_finance_report_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';
  end if;
  return public.food_finance_report_core_qa(p_from,p_to,p_store_id);
end;
$$;

create or replace function public.admin_food_finance_events_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid default null,
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';
  end if;
  return public.food_finance_events_core_qa(p_from,p_to,p_store_id,p_limit,p_offset);
end;
$$;

-- Merchant reporting: store owners ONLY (not generic staff / all merchants).
-- Authorization is checked BEFORE calling the privileged report core.
create or replace function public.merchant_food_finance_report_qa(
  p_store_id uuid, p_from timestamptz, p_to timestamptz
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null
     or not public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';
  end if;
  return public.food_finance_report_core_qa(p_from,p_to,p_store_id);
end;
$$;

create or replace function public.merchant_food_finance_events_qa(
  p_store_id uuid, p_from timestamptz, p_to timestamptz,
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null
     or not public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';
  end if;
  return public.food_finance_events_core_qa(p_from,p_to,p_store_id,p_limit,p_offset);
end;
$$;

-- Core functions are not available to client JWT roles.
revoke all on function public.food_finance_report_core_qa(timestamptz,timestamptz,uuid)
  from public,anon,authenticated;
revoke all on function public.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  from public,anon,authenticated;
grant execute on function public.food_finance_report_core_qa(timestamptz,timestamptz,uuid)
  to service_role;
grant execute on function public.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  to service_role;

revoke all on function public.admin_food_finance_report_qa(timestamptz,timestamptz,uuid),
  public.admin_food_finance_events_qa(timestamptz,timestamptz,uuid,integer,integer),
  public.merchant_food_finance_report_qa(uuid,timestamptz,timestamptz),
  public.merchant_food_finance_events_qa(uuid,timestamptz,timestamptz,integer,integer)
  from public,anon;
grant execute on function public.admin_food_finance_report_qa(timestamptz,timestamptz,uuid),
  public.admin_food_finance_events_qa(timestamptz,timestamptz,uuid,integer,integer),
  public.merchant_food_finance_report_qa(uuid,timestamptz,timestamptz),
  public.merchant_food_finance_events_qa(uuid,timestamptz,timestamptz,integer,integer)
  to authenticated,service_role;
