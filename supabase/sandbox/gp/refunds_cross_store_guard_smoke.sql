-- WYNOS Finance hardening regression: QA project pcatuxtenluqzjzzwsvl ONLY.
-- Malformed cross-store finance fixture is created and destroyed via ROLLBACK.
-- Never call Stripe, refund API, actual GP, production or Vercel.
BEGIN;
DO $$
declare
  v_order uuid; v_store uuid; v_other_store uuid; v_actor uuid;
  v_gp jsonb; v_result jsonb; v_event_count bigint;
begin
  select id,store_id into v_order,v_store
    from public.food_orders where order_number='WF000005';
  select id into v_other_store from public.food_stores
    where id<>v_store limit 1;
  select id into v_actor from auth.users order by created_at limit 1;
  if v_order is null or v_other_store is null or v_actor is null
    or exists(select 1 from public.food_gp_store_rates where store_id=v_store)
    or exists(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
    or exists(select 1 from public.food_finance_refund_adjustments_qa where order_id=v_order)
  then raise exception 'QA fixture missing or pre-populated; stop';end if;

  insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
    values(v_store,750,v_actor);
  v_gp:=public.food_gp_capture_order_qa(v_order);
  if v_gp->>'status'<>'snapshotted' then raise exception 'GP test fixture failed';end if;

  -- Deliberate direct QA service-level corruption fixture: mismatched store.
  -- This is NOT valid production application input.
  insert into public.food_finance_order_projections_qa(
    order_id,store_id,order_number,stripe_account_id,stripe_payment_intent_id,
    food_gross_satang,delivery_fee_satang,unallocated_discount_satang,
    customer_paid_satang,gp_rate_bps,
    estimated_platform_gp_satang,estimated_store_food_satang)
  select s.order_id,v_other_store,s.order_number,p.stripe_account_id,p.payment_intent_id,
    s.food_subtotal_satang,s.delivery_fee_satang,s.order_discount_satang,
    s.customer_paid_satang,s.rate_bps,
    s.estimated_gp_satang,s.estimated_store_food_satang
  from public.food_gp_order_snapshots s
  join public.food_stripe_payments p on p.order_id=s.order_id
  where s.order_id=v_order;

  v_result:=public.food_finance_append_refund_qa(
    v_order,'HARDEN-QA-CROSS-STORE',100,0,'Reject mismatched owner payment data');
  if v_result->>'status'<>'payment_state_not_eligible'
    or (v_result->>'adjustment_created')::boolean is distinct from false
  then raise exception 'Cross-store mismatch was not rejected: %',v_result;end if;

  select count(*) into v_event_count
    from public.food_finance_refund_adjustments_qa where order_id=v_order;
  if v_event_count<>0
    or (select count(*) from public.food_finance_refund_lines_qa)<>0
    or (select payment_status from public.food_orders where id=v_order)<>'paid'
    or (select refund_status from public.food_orders where id=v_order)<>'none'
    or (select status from public.food_stripe_payments where order_id=v_order)<>'paid'
  then raise exception 'Rejected corrupted projection generated events or altered payment';end if;
  raise notice 'PASS finance refund guard: cross-store projection rejected; zero simulated event writes and payment preserved';
end;$$;
ROLLBACK;