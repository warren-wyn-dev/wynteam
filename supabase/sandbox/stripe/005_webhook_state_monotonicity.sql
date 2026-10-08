-- WYNOS Stripe sandbox only. Prevent webhook ordering regression while
-- preserving event-ID idempotency and account/amount validation.
-- DO NOT MERGE into main without separate production review.
CREATE OR REPLACE FUNCTION public.food_apply_stripe_event(p_event_id text, p_event_type text, p_order_id uuid, p_stripe_account_id text, p_object_id text, p_checkout_session_id text, p_payment_intent_id text, p_amount_satang bigint, p_currency text, p_state text, p_payment_method text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_refund_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  o public.food_orders%rowtype;
  a public.food_stripe_accounts%rowtype;
  expected_satang bigint;
begin
  if p_event_id is null or length(p_event_id) < 3 then
    raise exception 'event id required';
  end if;
  if p_state not in ('paid','failed','refunded','noop') then
    raise exception 'invalid stripe event state';
  end if;

  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
  values (p_event_id,p_event_type,p_stripe_account_id,p_order_id,p_object_id)
  on conflict (event_id) do nothing;

  if not found then
    return false;
  end if;

  if p_state = 'noop' or p_order_id is null then
    return true;
  end if;

  select * into o from public.food_orders where id = p_order_id for update;
  if not found then
    raise exception 'order not found';
  end if;

  select * into a from public.food_stripe_accounts where store_id = o.store_id;
  if not found or a.stripe_account_id is distinct from p_stripe_account_id then
    raise exception 'stripe account mismatch';
  end if;

  expected_satang := round(o.total::numeric * 100)::bigint;
  if lower(coalesce(p_currency,'')) <> 'thb' then
    raise exception 'currency mismatch';
  end if;
  if p_state in ('paid','refunded') and coalesce(p_amount_satang,0) <> expected_satang then
    raise exception 'amount mismatch';
  end if;

  -- Sandbox hardening: webhook delivery is not ordered. An older failure or
  -- payment success must never regress a completed/refunded payment ledger.
  if p_state = 'failed' and o.payment_status in ('paid','refunded') then
    return true;
  end if;
  if p_state = 'paid' and o.payment_status = 'refunded' then
    return true;
  end if;
  if p_state = 'paid' and o.payment_status = 'paid'
     and o.payment_provider is distinct from 'stripe' then
    raise exception 'payment provider mismatch';
  end if;
  if p_state = 'refunded' and o.payment_status = 'refunded' then
    return true;
  end if;
  if p_state = 'refunded' then
    if o.payment_status <> 'paid' or o.payment_provider is distinct from 'stripe' then
      raise exception 'stripe refund requires paid stripe order';
    end if;
    if o.stripe_payment_intent_id is not null and p_payment_intent_id is not null
      and o.stripe_payment_intent_id <> p_payment_intent_id then
      raise exception 'stripe refund payment intent mismatch';
    end if;
  end if;

  insert into public.food_stripe_payments(
    order_id,store_id,buyer_id,stripe_account_id,checkout_session_id,payment_intent_id,
    amount_satang,currency,status,payment_method,paid_at,refunded_at,last_error
  )
  values (
    o.id,o.store_id,o.buyer_id,a.stripe_account_id,p_checkout_session_id,p_payment_intent_id,
    expected_satang,'thb',
    case when p_state='paid' then 'paid' when p_state='refunded' then 'refunded' else 'failed' end,
    p_payment_method,
    case when p_state in ('paid','refunded') then now() else null end,
    case when p_state='refunded' then now() else null end,
    case when p_state='failed' then left(coalesce(p_note,'Stripe payment failed'),500) else null end
  )
  on conflict (order_id) do update set
    checkout_session_id = coalesce(excluded.checkout_session_id, public.food_stripe_payments.checkout_session_id),
    payment_intent_id = coalesce(excluded.payment_intent_id, public.food_stripe_payments.payment_intent_id),
    status = excluded.status,
    payment_method = coalesce(excluded.payment_method, public.food_stripe_payments.payment_method),
    paid_at = coalesce(public.food_stripe_payments.paid_at, excluded.paid_at),
    refunded_at = coalesce(excluded.refunded_at, public.food_stripe_payments.refunded_at),
    last_error = excluded.last_error,
    updated_at = now();

  if p_state = 'paid' then
    update public.food_orders
    set payment_status = 'paid',
        payment_provider = 'stripe',
        payment_provider_code = p_event_type,
        payment_transaction_ref = p_payment_intent_id,
        payment_verified_at = coalesce(payment_verified_at, now()),
        payment_verification_status = 'auto_verified',
        payment_verification_note = 'Stripe webhook confirmed payment',
        stripe_checkout_session_id = coalesce(p_checkout_session_id, stripe_checkout_session_id),
        stripe_payment_intent_id = coalesce(p_payment_intent_id, stripe_payment_intent_id),
        paid_at = coalesce(paid_at, now()),
        payment_note = null
    where id = o.id and payment_status in ('pending','issue','submitted','paid');
  elsif p_state = 'failed' then
    update public.food_orders
    set payment_status = 'issue',
        payment_provider = 'stripe',
        payment_provider_code = p_event_type,
        stripe_checkout_session_id = coalesce(p_checkout_session_id, stripe_checkout_session_id),
        stripe_payment_intent_id = coalesce(p_payment_intent_id, stripe_payment_intent_id),
        payment_note = left(coalesce(p_note,'Stripe payment failed'),500)
    where id = o.id and payment_status in ('pending','issue');
  elsif p_state = 'refunded' then
    update public.food_orders
    set payment_status = 'refunded',
        refund_status = 'refunded',
        stripe_refund_id = coalesce(p_refund_id, stripe_refund_id),
        refunded_at = coalesce(refunded_at, now()),
        payment_provider_code = p_event_type,
        payment_note = null
    where id = o.id and payment_status in ('paid','refunded');
  end if;

  return true;
end;
$function$
;
