-- Reconcile actual application-fee returns, never initiate refunds or enable GP.
-- Requires the platform webhook subscription to application_fee.refunded and
-- separate Stripe sandbox acceptance before enabling a nonzero GP rate.
create or replace function public.food_record_stripe_fee_refund_event(
  p_event_id text, p_stripe_account_id text, p_payment_intent_id text, p_fee_id text,
  p_fee_amount_satang bigint, p_refunded_satang bigint, p_currency text,
  p_livemode boolean, p_refunded_at timestamptz
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_order_id uuid;
  v_payment public.food_stripe_payments%rowtype;
begin
  if p_event_id is null or char_length(p_event_id) not between 3 and 255
    or p_stripe_account_id is null or char_length(p_stripe_account_id) not between 3 and 255
    or p_payment_intent_id is null or char_length(p_payment_intent_id) not between 3 and 255
    or p_fee_id is null or char_length(p_fee_id) not between 3 and 255
    or p_fee_amount_satang is null or p_fee_amount_satang not between 1 and 9007199254740991
    or p_refunded_satang is null or p_refunded_satang not between 0 and p_fee_amount_satang
    or p_currency is distinct from 'thb' or p_livemode is null
    or p_refunded_at is null or not isfinite(p_refunded_at) then
    raise exception 'Invalid application fee event' using errcode='22023';
  end if;
  -- Match food_apply_stripe_event's order-before-payment lock order. The event
  -- receipt's order FK also takes a parent lock, so locking the payment first
  -- can deadlock a concurrent customer-refund webhook at its payment upsert.
  select order_id into v_order_id from public.food_stripe_payments
    where payment_intent_id=p_payment_intent_id;
  if not found then return jsonb_build_object('recorded',false,'reason','unmapped'); end if;
  perform 1 from public.food_orders where id=v_order_id for update;
  if not found then return jsonb_build_object('recorded',false,'reason','unmapped'); end if;
  -- Re-read the original mapping after waiting for the parent. Keep the
  -- account/environment pinned to the actual payment even after reconnection;
  -- never resolve order metadata or trust the earlier nonlocking lookup.
  select * into v_payment from public.food_stripe_payments
    where order_id=v_order_id and payment_intent_id=p_payment_intent_id for update;
  if not found then return jsonb_build_object('recorded',false,'reason','unmapped'); end if;
  if v_payment.stripe_account_id is distinct from p_stripe_account_id
    or v_payment.livemode is distinct from p_livemode
    or v_payment.currency is distinct from p_currency
    or v_payment.application_fee_satang is distinct from p_fee_amount_satang then
    raise exception 'Application fee payment mismatch' using errcode='22023';
  end if;
  -- Do not claim separately: receipt insertion and the financial projection
  -- must roll back together so provider retries can recover a failed write.
  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
    values(p_event_id,'application_fee.refunded',p_stripe_account_id,v_payment.order_id,p_fee_id)
    on conflict(event_id) do nothing;
  if not found then return jsonb_build_object('recorded',false,'reason','duplicate'); end if;
  -- The existing GP report stores one full-fee reversal/date per payment.
  -- Partial returns need a separate dated ledger before they can be reported
  -- accurately. Keep their receipt for review without fabricating a reversal.
  if p_refunded_satang<>p_fee_amount_satang then
    return jsonb_build_object('recorded',false,'reason','partial_fee_reconciliation_required');
  end if;
  update public.food_stripe_payments set
    application_fee_refunded_satang=p_fee_amount_satang,
    application_fee_refunded_at=case
      when application_fee_refunded_satang=p_fee_amount_satang
        then least(coalesce(application_fee_refunded_at,p_refunded_at),p_refunded_at)
      else p_refunded_at end
    where order_id=v_payment.order_id;
  return jsonb_build_object('recorded',true,'reason','full_fee_returned');
end $$;
revoke all on function public.food_record_stripe_fee_refund_event(text,text,text,text,bigint,bigint,text,boolean,timestamptz)
  from public,anon,authenticated;
grant execute on function public.food_record_stripe_fee_refund_event(text,text,text,text,bigint,bigint,text,boolean,timestamptz)
  to service_role;
notify pgrst, 'reload schema';
