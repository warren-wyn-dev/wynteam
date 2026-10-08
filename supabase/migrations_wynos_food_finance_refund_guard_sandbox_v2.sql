-- WYNOS Finance QA Refund Guard v2: pcatuxtenluqzjzzwsvl ONLY.
-- Harden only the isolated refund SIMULATION RPC. No checkout, webhook,
-- Stripe API, production, GP rate defaults or actual money movement.
-- Regression found malformed QA projections with a different store_id
-- could still append a simulated refund. Fail closed on cross-linked data.
-- Keeps the immutable ledger, idempotency, cumulative math and per-order lock.
create or replace function public.food_finance_append_refund_qa(
  p_order_id uuid,
  p_simulation_key text,
  p_food_refund_satang bigint,
  p_delivery_refund_satang bigint,
  p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_proj public.food_finance_order_projections_qa%rowtype;
  v_existing public.food_finance_refund_adjustments_qa%rowtype;
  v_order public.food_orders%rowtype;
  v_payment public.food_stripe_payments%rowtype;
  v_key text := btrim(coalesce(p_simulation_key,''));
  v_reason text := btrim(coalesce(p_reason,''));
  v_prev_food bigint;
  v_prev_delivery bigint;
  v_prev_customer bigint;
  v_seq integer;
  v_math jsonb;
  v_event_gp bigint;
  v_event_store bigint;
  v_customer_refund bigint;
  v_refund_id uuid;
  v_balance_customer bigint;
  v_balance_share bigint;
begin
  if p_order_id is null then raise exception 'order id required'; end if;
  if v_key !~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{2,79}$' then
    raise exception 'QA simulation key must be 3-80 safe characters';
  end if;
  if char_length(v_reason) not between 3 and 500 then
    raise exception 'refund reason must be between 3 and 500 chars';
  end if;
  if p_food_refund_satang is null or p_delivery_refund_satang is null
     or p_food_refund_satang < 0 or p_delivery_refund_satang < 0
     or p_food_refund_satang+p_delivery_refund_satang <= 0 then
    raise exception 'invalid refund amount';
  end if;

  select * into v_proj from public.food_finance_order_projections_qa
    where order_id=p_order_id for update;
  if not found then return jsonb_build_object('status','finance_projection_not_available',
    'order_id',p_order_id,'simulation_only',true,'actual_customer_refunded_satang',0); end if;

  select * into v_existing from public.food_finance_refund_adjustments_qa
    where order_id=p_order_id and simulation_key=v_key;
  if found then
    if v_existing.food_refund_satang is distinct from p_food_refund_satang
      or v_existing.delivery_refund_satang is distinct from p_delivery_refund_satang
      or v_existing.reason is distinct from v_reason then
      raise exception 'simulation key replay payload mismatch';
    end if;
    return jsonb_build_object('status','already_adjusted',
      'adjustment',to_jsonb(v_existing),'mode','simulation_only');
  end if;

  -- Never simulate unapproved discount payer rules by claiming a net refund
  -- or applying a false GP reversal. Delay until policy is approved.
  if v_proj.unallocated_discount_satang <> 0 then
    return jsonb_build_object('status','discount_allocation_unresolved',
      'order_id',p_order_id,'simulation_only',true,'adjustment_created',false,
      'actual_customer_refunded_satang',0);
  end if;

  select * into v_order from public.food_orders where id=p_order_id;
  select * into v_payment from public.food_stripe_payments where order_id=p_order_id;
  -- Fail closed on malformed/stale cross-store payment or projection links.
  -- Protects the simulation ledger even if a trusted QA writer inserts
  -- inconsistent projection data; does not touch the Stripe payment path.
  if v_order.store_id is distinct from v_proj.store_id
    or v_order.payment_provider is distinct from 'stripe'
    or v_order.stripe_payment_intent_id is distinct from v_proj.stripe_payment_intent_id
    or v_payment.order_id is distinct from v_proj.order_id
    or v_payment.store_id is distinct from v_proj.store_id
    or v_proj.payment_method is distinct from 'promptpay'
    or v_proj.charge_model is distinct from 'direct_charge_connected_account'
    or v_order.payment_status is distinct from 'paid'
    or v_order.refund_status is distinct from 'none'
    or v_order.status is distinct from 'pending_acceptance'
       and v_order.status is distinct from 'preparing'
       and v_order.status is distinct from 'ready_for_delivery'
       and v_order.status is distinct from 'out_for_delivery'
       and v_order.status is distinct from 'delivered'
    or v_payment.status is distinct from 'paid'
    or v_payment.payment_method is distinct from 'promptpay'
    or v_payment.livemode is distinct from false
    or v_payment.currency is distinct from 'thb'
    or v_payment.stripe_account_id is distinct from v_proj.stripe_account_id
    or v_payment.payment_intent_id is distinct from v_proj.stripe_payment_intent_id
    or v_payment.amount_satang is distinct from v_proj.customer_paid_satang
    or v_proj.mode is distinct from 'simulation_only'
  then return jsonb_build_object('status','payment_state_not_eligible',
    'order_id',p_order_id,'adjustment_created',false,
    'actual_customer_refunded_satang',0,'mode','simulation_only'); end if;

  select coalesce(sum(food_refund_satang),0),
    coalesce(sum(delivery_refund_satang),0),
    coalesce(sum(customer_refund_satang),0),
    count(*)::integer
  into v_prev_food,v_prev_delivery,v_prev_customer,v_seq
  from public.food_finance_refund_adjustments_qa where order_id=p_order_id;

  -- Discount=0: customer refund = food refund + delivery refund.
  -- No cross-category overspending even when multiple refunds are submitted.
  v_math := public.food_finance_refund_math_qa(
    v_proj.food_gross_satang,
    v_proj.delivery_fee_satang,
    v_proj.gp_rate_bps,
    v_prev_food,v_prev_delivery,
    p_food_refund_satang,p_delivery_refund_satang
  );
  v_customer_refund := (v_math->>'customer_refund_satang')::bigint;
  if v_prev_customer + v_customer_refund > v_proj.customer_paid_satang then
    raise exception 'cumulative refund exceeds customer payment';
  end if;
  v_event_gp := (v_math->>'estimated_platform_gp_reversal_satang')::bigint;
  v_event_store := (v_math->>'estimated_store_food_reversal_satang')::bigint;

  insert into public.food_finance_refund_adjustments_qa(
    order_id,store_id,simulation_key,sequence_number,reason,refund_kind,
    food_refund_satang,delivery_refund_satang,customer_refund_satang,
    estimated_platform_gp_reversal_satang,
    estimated_store_food_reversal_satang,
    cumulative_food_refund_satang,cumulative_delivery_refund_satang,
    cumulative_customer_refund_satang,cumulative_gp_reversal_satang,
    remaining_customer_paid_satang,remaining_estimated_gp_satang,
    remaining_estimated_store_food_satang
  ) values (
    p_order_id,v_proj.store_id,v_key,v_seq+1,v_reason,
    case when (v_math->>'remaining_customer_paid_satang')::bigint=0
      then 'full' else 'partial' end,
    p_food_refund_satang,p_delivery_refund_satang,v_customer_refund,
    v_event_gp,v_event_store,
    (v_math->>'cumulative_food_refund_satang')::bigint,
    (v_math->>'cumulative_delivery_refund_satang')::bigint,
    (v_math->>'cumulative_customer_refund_satang')::bigint,
    (v_math->>'cumulative_gp_reversal_satang')::bigint,
    (v_math->>'remaining_customer_paid_satang')::bigint,
    (v_math->>'remaining_estimated_gp_satang')::bigint,
    (v_math->>'remaining_estimated_store_food_satang')::bigint
  ) returning id into v_refund_id;

  insert into public.food_finance_refund_lines_qa(
    adjustment_id,book,line_type,signed_amount_satang
  ) values
   (v_refund_id,'customer_refund_reversal','customer_refund',v_customer_refund),
   (v_refund_id,'customer_refund_reversal','food_refund',-p_food_refund_satang),
   (v_refund_id,'customer_refund_reversal','delivery_refund',-p_delivery_refund_satang),
   (v_refund_id,'food_share_refund_reversal','gp_reversal',-v_event_gp),
   (v_refund_id,'food_share_refund_reversal','store_food_reversal',-v_event_store),
   (v_refund_id,'food_share_refund_reversal','food_basis_restore',p_food_refund_satang);

  select sum(signed_amount_satang) into v_balance_customer
   from public.food_finance_refund_lines_qa
   where adjustment_id=v_refund_id and book='customer_refund_reversal';
  select sum(signed_amount_satang) into v_balance_share
   from public.food_finance_refund_lines_qa
   where adjustment_id=v_refund_id and book='food_share_refund_reversal';
  if v_balance_customer is distinct from 0 or v_balance_share is distinct from 0 then
    raise exception 'simulated refund reconciliation books not balanced';
  end if;

  select * into v_existing from public.food_finance_refund_adjustments_qa
   where id=v_refund_id;
  return jsonb_build_object('status','adjusted','adjustment_created',true,
    'adjustment',to_jsonb(v_existing),'customer_book_balance_satang',v_balance_customer,
    'food_share_book_balance_satang',v_balance_share,'mode','simulation_only');
end;
$$;


revoke all on function public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)
  from public,anon,authenticated;
grant execute on function public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)
  to service_role;
