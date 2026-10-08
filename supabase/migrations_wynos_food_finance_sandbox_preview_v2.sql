-- Finance QA v2: pure preflight for discounts, delivery, and hypothetical GP.
-- QA-only function: NEVER triggers a Stripe transfer or invents net payout.
-- Rate parameter is hypothetical, NOT a stored or default merchant GP rate.
create or replace function public.food_finance_preview_qa(
  p_food_gross_satang bigint,
  p_delivery_fee_satang bigint,
  p_customer_paid_satang bigint,
  p_hypothetical_rate_bps integer
)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  v_discount bigint;
  v_gp jsonb;
  v_platform bigint;
  v_store bigint;
begin
  if p_food_gross_satang is null
    or p_food_gross_satang < 0 or p_food_gross_satang > 100000000000
    or p_delivery_fee_satang is null
    or p_delivery_fee_satang < 0 or p_delivery_fee_satang > 100000000000
    or p_customer_paid_satang is null
    or p_customer_paid_satang <= 0 or p_customer_paid_satang > 100000000000
    or p_food_gross_satang + p_delivery_fee_satang < p_customer_paid_satang
  then
    raise exception 'invalid QA customer reconciliation inputs';
  end if;
  v_discount := p_food_gross_satang + p_delivery_fee_satang - p_customer_paid_satang;
  v_gp := public.food_gp_calculate_qa(p_food_gross_satang,p_hypothetical_rate_bps);
  v_platform := (v_gp->>'estimated_gp_satang')::bigint;
  v_store := (v_gp->>'estimated_store_food_satang')::bigint;

  return jsonb_build_object(
    'mode','simulation_only',
    'rate_source','hypothetical_input_only',
    'currency','thb',
    'food_gross_satang',p_food_gross_satang,
    'delivery_fee_satang',p_delivery_fee_satang,
    'customer_paid_satang',p_customer_paid_satang,
    'unallocated_discount_satang',v_discount,
    'discount_allocation_status','unallocated',
    'estimated_platform_gp_satang',v_platform,
    'estimated_store_food_satang',v_store,
    'customer_book_balance_satang',
       p_food_gross_satang + p_delivery_fee_satang - v_discount - p_customer_paid_satang,
    'food_share_book_balance_satang',
       v_platform + v_store - p_food_gross_satang,
    'stripe_processing_fee_satang',null,
    'stripe_fee_status','unknown',
    'actual_platform_gp_collected_satang',0,
    'actual_platform_transfer_satang',0,
    'merchant_net_payout_satang',null,
    'merchant_payout_status','not_reconciled'
  );
end;
$$;
revoke all on function public.food_finance_preview_qa(bigint,bigint,bigint,integer)
  from public,anon,authenticated;
grant execute on function public.food_finance_preview_qa(bigint,bigint,bigint,integer)
  to service_role;
