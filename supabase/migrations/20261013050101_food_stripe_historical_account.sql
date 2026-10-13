-- Pin settled events to the ledger's original account; keep the existing RPC signature.
-- This migration follows stripe_event_integrity. No Stripe API calls or payouts.
begin;
create or replace function public.food_apply_stripe_event(
  p_event_id text,
  p_event_type text,
  p_order_id uuid,
  p_stripe_account_id text,
  p_object_id text,
  p_checkout_session_id text,
  p_payment_intent_id text,
  p_amount_satang bigint,
  p_currency text,
  p_state text,
  p_payment_method text default null,
  p_note text default null,
  p_refund_id text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.food_orders%rowtype;
  a public.food_stripe_accounts%rowtype;
  expected_satang bigint;
  settled_account text;
  settled_payment_intent text;
begin
  if p_event_id is null or length(p_event_id) < 3 then
    raise exception 'event id required';
  end if;
  if p_state is null or p_state not in ('paid','failed','refunded','noop') then
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

  select stripe_account_id,payment_intent_id into settled_account,settled_payment_intent from public.food_stripe_payments
    where order_id=o.id and status in ('paid','refunded');
  if settled_account is not null then
    -- Historical transactions belong to their original account, even after
    -- the store reconnects and the active account mapping changes.
    if settled_account is distinct from p_stripe_account_id then raise exception 'stripe account mismatch'; end if;
    a.stripe_account_id := settled_account;
  else
    select * into a from public.food_stripe_accounts where store_id = o.store_id;
    if not found or a.stripe_account_id is distinct from p_stripe_account_id then raise exception 'stripe account mismatch'; end if;
  end if;
  if p_state = 'refunded' then
    if o.payment_status is null or o.payment_status not in ('paid','refunded') then
      -- Refund delivery can precede the paid webhook. Roll back this claim so
      -- the provider retries after payment settles instead of creating a
      -- refunded ledger alongside a still-pending order.
      raise exception 'payment not settled; retry refund webhook';
    end if;
    -- Same-account refunds can belong to a different charge with the same
    -- amount. Verify the original transaction, not the event's order metadata.
    -- Only legacy orders without a settled ledger may use the canonical order
    -- PaymentIntent; a settled ledger with missing identity needs reconciliation.
    if settled_account is null then settled_payment_intent := o.stripe_payment_intent_id; end if;
    if settled_payment_intent is null or p_payment_intent_id is distinct from settled_payment_intent then
      raise exception 'refund payment intent mismatch';
    end if;
  end if;

  expected_satang := round(o.total::numeric * 100)::bigint;
  if lower(coalesce(p_currency,'')) <> 'thb' then
    raise exception 'currency mismatch';
  end if;
  if p_state in ('paid','refunded') and coalesce(p_amount_satang,0) <> expected_satang then
    raise exception 'amount mismatch';
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
$$;

revoke all on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  from public, anon, authenticated;
grant execute on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  to service_role;
commit;
