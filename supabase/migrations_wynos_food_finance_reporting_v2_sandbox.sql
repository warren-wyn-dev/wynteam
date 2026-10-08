-- WYNOS Food Finance Reporting v2; QA pcatuxtenluqzjzzwsvl only.
-- No real money movement, settlement, Stripe fee guesses, customer PII or new GP default.
-- Independent projection/adjustment event dates; Asia/Bangkok grouping.
-- Internal cores are INVOKER in an unexposed schema. Public definer
-- wrappers apply the same independent admin allowlist/owner checks as v1.

create or replace function wynos_finance_qa_private.food_finance_buckets_core_v2_qa(
  p_from timestamptz,p_to timestamptz,p_store_id uuid,p_granularity text
) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_buckets jsonb;v_grain text;
begin
  if p_from is null or p_to is null or p_from>=p_to
     or p_to-p_from>interval '366 days' or p_granularity is null
     or p_granularity not in ('day','month') then
    raise exception 'Invalid Finance v2 bucket range or granularity'
      using errcode='22023';
  end if;
  v_grain:=p_granularity;
  with periods as (
    select x::date as bucket from pg_catalog.generate_series(
      pg_catalog.date_trunc(v_grain,p_from at time zone 'Asia/Bangkok'),
      pg_catalog.date_trunc(v_grain,(p_to-interval '1 microsecond') at time zone 'Asia/Bangkok'),
      case when v_grain='day' then interval '1 day' else interval '1 month' end
    ) x
  ), events as (
    select pg_catalog.date_trunc(v_grain,p.created_at at time zone 'Asia/Bangkok')::date bucket,
      1::bigint projection_count,0::bigint refund_count,
      p.customer_paid_satang projected_paid,
      p.food_gross_satang food_gross,p.delivery_fee_satang delivery,
      p.estimated_platform_gp_satang gp,p.estimated_store_food_satang store_food,
      0::bigint customer_refund,0::bigint gp_reversal,
      0::bigint store_reversal
    from public.food_finance_order_projections_qa p
    where p.created_at>=p_from and p.created_at<p_to
      and (p_store_id is null or p.store_id=p_store_id)
    union all
    select pg_catalog.date_trunc(v_grain,a.created_at at time zone 'Asia/Bangkok')::date,
      0,1,0,0,0,0,0,a.customer_refund_satang,
      a.estimated_platform_gp_reversal_satang,
      a.estimated_store_food_reversal_satang
    from public.food_finance_refund_adjustments_qa a
    where a.created_at>=p_from and a.created_at<p_to
      and (p_store_id is null or a.store_id=p_store_id)
  ), sums as (
    select bucket,pg_catalog.sum(projection_count)::bigint projects,
      pg_catalog.sum(refund_count)::bigint adjustments,
      pg_catalog.sum(projected_paid)::bigint paid,
      pg_catalog.sum(food_gross)::bigint food,
      pg_catalog.sum(delivery)::bigint delivery,
      pg_catalog.sum(gp)::bigint gp,
      pg_catalog.sum(store_food)::bigint store_food,
      pg_catalog.sum(customer_refund)::bigint refunded,
      pg_catalog.sum(gp_reversal)::bigint gp_rev,
      pg_catalog.sum(store_reversal)::bigint store_rev
    from events group by bucket
  )
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'local_period_start',p.bucket,'projection_count',pg_catalog.coalesce(s.projects,0),
      'refund_event_count',pg_catalog.coalesce(s.adjustments,0),
      'projected_customer_paid_satang',pg_catalog.coalesce(s.paid,0),
      'projected_food_gross_satang',pg_catalog.coalesce(s.food,0),
      'projected_delivery_fee_satang',pg_catalog.coalesce(s.delivery,0),
      'estimated_platform_gp_satang',pg_catalog.coalesce(s.gp,0),
      'estimated_merchant_food_satang',pg_catalog.coalesce(s.store_food,0),
      'simulated_customer_refund_satang',pg_catalog.coalesce(s.refunded,0),
      'simulated_gp_reversal_satang',pg_catalog.coalesce(s.gp_rev,0),
      'simulated_merchant_food_reversal_satang',pg_catalog.coalesce(s.store_rev,0),
      'period_gp_projection_less_reversals_satang',
        pg_catalog.coalesce(s.gp,0)-pg_catalog.coalesce(s.gp_rev,0),
      'period_merchant_food_projection_less_reversals_satang',
        pg_catalog.coalesce(s.store_food,0)-pg_catalog.coalesce(s.store_rev,0)
    ) order by p.bucket),'[]'::jsonb) into v_buckets
  from periods p left join sums s using(bucket);
  return pg_catalog.jsonb_build_object(
    'mode','simulation_only','currency','thb','timezone','Asia/Bangkok',
    'granularity',v_grain,'from_inclusive',p_from,'to_exclusive',p_to,
    'selected_store_id',p_store_id,'buckets',v_buckets,
    'stripe_processing_fee_satang',null,'stripe_fee_status','unknown',
    'merchant_net_payout_satang',null,'merchant_payout_status','not_reconciled',
    'projection_date_basis','finance_projection_created_at',
    'adjustment_date_basis','refund_adjustment_created_at',
    'note','Event-date simulations only; bucket differences are NOT settled earnings'
  );
end;
$$;

create or replace function wynos_finance_qa_private.food_finance_order_core_v2_qa(
  p_order_id uuid,p_store_id uuid
) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare v_proj public.food_finance_order_projections_qa%rowtype;
  v_events jsonb;v_count bigint;v_refunded bigint;v_gp_reversed bigint;
  v_store_reversed bigint;
begin
  if p_order_id is null then
    raise exception 'order_id required' using errcode='22023';
  end if;
  select * into v_proj from public.food_finance_order_projections_qa p
   where p.order_id=p_order_id
     and (p_store_id is null or p.store_id=p_store_id);
  if not found then return pg_catalog.jsonb_build_object(
    'status','not_projected','mode','simulation_only',
    'actual_customer_refunded_satang',0
  );end if;
  select pg_catalog.coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id',a.id,'sequence_number',a.sequence_number,
        'created_at',a.created_at,'simulation_key',a.simulation_key,
        'reason',a.reason,'refund_kind',a.refund_kind,
        'food_refund_satang',a.food_refund_satang,
        'delivery_refund_satang',a.delivery_refund_satang,
        'simulated_customer_refund_satang',a.customer_refund_satang,
        'estimated_gp_reversal_satang',a.estimated_platform_gp_reversal_satang,
        'estimated_merchant_food_reversal_satang',a.estimated_store_food_reversal_satang,
        'cumulative_gp_reversal_satang',a.cumulative_gp_reversal_satang,
        'remaining_customer_paid_satang',a.remaining_customer_paid_satang,
        'mode','simulation_only'
      ) order by a.sequence_number),'[]'::jsonb),
      count(*)::bigint,pg_catalog.coalesce(sum(a.customer_refund_satang),0)::bigint,
      pg_catalog.coalesce(sum(a.estimated_platform_gp_reversal_satang),0)::bigint,
      pg_catalog.coalesce(sum(a.estimated_store_food_reversal_satang),0)::bigint
  into v_events,v_count,v_refunded,v_gp_reversed,v_store_reversed
  from public.food_finance_refund_adjustments_qa a
  where a.order_id=v_proj.order_id and a.store_id=v_proj.store_id;
  return pg_catalog.jsonb_build_object(
    'status','projected','mode','simulation_only','currency','thb',
    'order_id',v_proj.order_id,'order_number',v_proj.order_number,
    'store_id',v_proj.store_id,'projection_created_at',v_proj.created_at,
    'frozen_gp_rate_bps',v_proj.gp_rate_bps,
    'food_gross_satang',v_proj.food_gross_satang,
    'delivery_fee_satang',v_proj.delivery_fee_satang,
    'unallocated_discount_satang',v_proj.unallocated_discount_satang,
    'projected_customer_paid_satang',v_proj.customer_paid_satang,
    'estimated_platform_gp_satang',v_proj.estimated_platform_gp_satang,
    'estimated_merchant_food_satang',v_proj.estimated_store_food_satang,
    'refund_event_count',v_count,'refund_events',v_events,
    'simulated_customer_refunded_satang',v_refunded,
    'simulated_gp_reversal_satang',v_gp_reversed,
    'simulated_merchant_food_reversal_satang',v_store_reversed,
    'simulated_remaining_customer_paid_satang',v_proj.customer_paid_satang-v_refunded,
    'simulated_remaining_gp_satang',v_proj.estimated_platform_gp_satang-v_gp_reversed,
    'simulated_remaining_merchant_food_satang',v_proj.estimated_store_food_satang-v_store_reversed,
    'actual_customer_refunded_satang',0,'actually_collected_gp_satang',0,
    'stripe_processing_fee_satang',null,'stripe_fee_status','unknown',
    'merchant_net_payout_satang',null,'merchant_payout_status','not_reconciled'
  );
end;
$$;

-- Privileged public wrappers: authorization BEFORE invoking private cores.
create or replace function public.admin_food_finance_buckets_v2_qa(
  p_from timestamptz,p_to timestamptz,p_granularity text default 'day',
  p_store_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';end if;
  return wynos_finance_qa_private.food_finance_buckets_core_v2_qa(
    p_from,p_to,p_store_id,p_granularity);
end;
$$;

create or replace function public.merchant_food_finance_buckets_v2_qa(
  p_store_id uuid,p_from timestamptz,p_to timestamptz,
  p_granularity text default 'day'
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null or not
    public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';end if;
  return wynos_finance_qa_private.food_finance_buckets_core_v2_qa(
    p_from,p_to,p_store_id,p_granularity);
end;
$$;

create or replace function public.admin_food_finance_order_details_v2_qa(
  p_order_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';end if;
  return wynos_finance_qa_private.food_finance_order_core_v2_qa(p_order_id,null);
end;
$$;

create or replace function public.merchant_food_finance_order_details_v2_qa(
  p_store_id uuid,p_order_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null or not
    public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';end if;
  return wynos_finance_qa_private.food_finance_order_core_v2_qa(p_order_id,p_store_id);
end;
$$;

revoke all on function
  wynos_finance_qa_private.food_finance_buckets_core_v2_qa(timestamptz,timestamptz,uuid,text),
  wynos_finance_qa_private.food_finance_order_core_v2_qa(uuid,uuid)
  from public,anon,authenticated;
grant execute on function
  wynos_finance_qa_private.food_finance_buckets_core_v2_qa(timestamptz,timestamptz,uuid,text),
  wynos_finance_qa_private.food_finance_order_core_v2_qa(uuid,uuid)
  to service_role;
revoke all on function
  public.admin_food_finance_buckets_v2_qa(timestamptz,timestamptz,text,uuid),
  public.merchant_food_finance_buckets_v2_qa(uuid,timestamptz,timestamptz,text),
  public.admin_food_finance_order_details_v2_qa(uuid),
  public.merchant_food_finance_order_details_v2_qa(uuid,uuid)
  from public,anon;
grant execute on function
  public.admin_food_finance_buckets_v2_qa(timestamptz,timestamptz,text,uuid),
  public.merchant_food_finance_buckets_v2_qa(uuid,timestamptz,timestamptz,text),
  public.admin_food_finance_order_details_v2_qa(uuid),
  public.merchant_food_finance_order_details_v2_qa(uuid,uuid)
  to authenticated,service_role;
