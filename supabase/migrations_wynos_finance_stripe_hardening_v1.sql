-- Stripe event hardening for Finance Control Center.
-- Keeps webhook dedupe and webhook-as-source-of-truth behavior, but validates
-- events against the ORIGINAL payment account instead of the store's current
-- Connect mapping.

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
  p public.food_stripe_payments%rowtype;
  a public.food_stripe_accounts%rowtype;
  f public.food_order_financials%rowtype;
  expected_satang bigint;
  original_account text;
  original_livemode boolean;
begin
  if p_event_id is null or length(p_event_id)<3 then raise exception 'event id required'; end if;
  if p_state not in ('paid','failed','refunded','noop') then raise exception 'invalid stripe event state'; end if;

  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
  values(p_event_id,p_event_type,p_stripe_account_id,p_order_id,p_object_id)
  on conflict(event_id) do nothing;

  if not found then return false; end if;
  if p_state='noop' or p_order_id is null then return true; end if;

  select * into o from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;

  select * into p from public.food_stripe_payments where order_id=o.id for update;
  select * into f from public.food_order_financials where order_id=o.id;

  expected_satang:=coalesce(f.customer_total_satang,round(o.total::numeric*100)::bigint);
  if lower(coalesce(p_currency,''))<>'thb' then raise exception 'currency mismatch'; end if;
  if p_state in ('paid','refunded') and coalesce(p_amount_satang,0)<>expected_satang then
    raise exception 'amount mismatch';
  end if;

  if p.order_id is not null then
    original_account:=p.stripe_account_id;
    original_livemode:=p.livemode;
    if original_account is distinct from p_stripe_account_id then
      raise exception 'original Stripe account mismatch';
    end if;
  else
    -- Compatibility path only for the FIRST payment binding of a legacy
    -- order. Refunds never use the current mapping as a fallback.
    if p_state='refunded' then raise exception 'original Stripe payment identity missing'; end if;
    select * into a
    from public.food_stripe_accounts
    where store_id=o.store_id and stripe_account_id=p_stripe_account_id;
    if not found then raise exception 'stripe account mismatch'; end if;
    original_account:=p_stripe_account_id;
    original_livemode:=a.livemode;
  end if;

  insert into public.food_stripe_payments(
    order_id,store_id,buyer_id,stripe_account_id,checkout_session_id,payment_intent_id,
    amount_satang,gross_amount_satang,currency,status,payment_method,paid_at,refunded_at,last_error,
    livemode,platform_fee_satang,stripe_fee_policy
  )
  values(
    o.id,o.store_id,o.buyer_id,original_account,p_checkout_session_id,p_payment_intent_id,
    expected_satang,expected_satang,'thb',
    case when p_state='paid' then 'paid' when p_state='refunded' then 'refunded' else 'failed' end,
    p_payment_method,
    case when p_state in ('paid','refunded') then now() else null end,
    case when p_state='refunded' then now() else null end,
    case when p_state='failed' then left(coalesce(p_note,'Stripe payment failed'),500) else null end,
    original_livemode,
    f.gp_amount_satang,
    f.stripe_fee_policy
  )
  on conflict(order_id) do update set
    checkout_session_id=coalesce(excluded.checkout_session_id,public.food_stripe_payments.checkout_session_id),
    payment_intent_id=coalesce(excluded.payment_intent_id,public.food_stripe_payments.payment_intent_id),
    amount_satang=excluded.amount_satang,
    gross_amount_satang=coalesce(public.food_stripe_payments.gross_amount_satang,excluded.gross_amount_satang),
    status=excluded.status,
    payment_method=coalesce(excluded.payment_method,public.food_stripe_payments.payment_method),
    paid_at=coalesce(public.food_stripe_payments.paid_at,excluded.paid_at),
    refunded_at=coalesce(excluded.refunded_at,public.food_stripe_payments.refunded_at),
    last_error=excluded.last_error,
    platform_fee_satang=coalesce(public.food_stripe_payments.platform_fee_satang,excluded.platform_fee_satang),
    stripe_fee_policy=coalesce(public.food_stripe_payments.stripe_fee_policy,excluded.stripe_fee_policy),
    updated_at=now();

  if p_state='paid' then
    update public.food_orders
    set payment_status='paid',
        payment_provider='stripe',
        payment_provider_code=p_event_type,
        payment_transaction_ref=p_payment_intent_id,
        payment_verified_at=coalesce(payment_verified_at,now()),
        payment_verification_status='auto_verified',
        payment_verification_note='Stripe webhook confirmed payment',
        stripe_checkout_session_id=coalesce(p_checkout_session_id,stripe_checkout_session_id),
        stripe_payment_intent_id=coalesce(p_payment_intent_id,stripe_payment_intent_id),
        paid_at=coalesce(paid_at,now()),
        payment_note=null
    where id=o.id and payment_status in ('pending','issue','submitted','paid');

  elsif p_state='failed' then
    update public.food_orders
    set payment_status='issue',
        payment_provider='stripe',
        payment_provider_code=p_event_type,
        stripe_checkout_session_id=coalesce(p_checkout_session_id,stripe_checkout_session_id),
        stripe_payment_intent_id=coalesce(p_payment_intent_id,stripe_payment_intent_id),
        payment_note=left(coalesce(p_note,'Stripe payment failed'),500)
    where id=o.id and payment_status in ('pending','issue');

  elsif p_state='refunded' then
    update public.food_orders
    set payment_status='refunded',
        refund_status='refunded',
        stripe_refund_id=coalesce(p_refund_id,stripe_refund_id),
        refunded_at=coalesce(refunded_at,now()),
        payment_provider_code=p_event_type,
        payment_note=null
    where id=o.id and payment_status in ('paid','refunded');
  end if;

  return true;
end;
$$;

revoke all on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  from public,anon,authenticated;
grant execute on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)
  to service_role;
