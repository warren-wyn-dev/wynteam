-- Rollback for migrations/20261012090000_food_payment_integrity_v1.sql
--
-- Restores the definitions from migrations_wynos_stripe_payment_core_v1.sql,
-- the only repo source of these three functions' Stripe-guarded versions.
-- BEFORE RUNNING: DevOps compares these bodies with the live definitions saved
-- by food-payment-integrity-readonly-check.yml (artifact
-- food-payment-live-function-definitions, run 38185509687) and uses the
-- artifact text if they differ. Grants below match the live ACL recorded in
-- that artifact (owner postgres; anon none).
-- Effect: re-opens P1 (paid-after-cancel is not flagged or refunded) and P3.
-- Rows already flagged (refund_status, events, notifications) stay; harmless.

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
revoke all on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text) to service_role;

create or replace function public.food_submit_payment(p_order_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  if v_order.payment_status not in ('pending','issue') then
    raise exception 'payment already submitted';
  end if;
  if v_order.stripe_checkout_session_id is not null then
    raise exception 'cancel stripe checkout before submitting slip';
  end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text || '/slips/' || p_order_id::text || '/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status = 'submitted',
      payment_slip_path = p_slip_path,
      payment_note = null,
      payment_verification_status = 'manual_review',
      payment_provider = null,
      payment_provider_code = null,
      payment_transaction_ref = null,
      payment_verified_at = null,
      payment_verification_note = null
  where id = p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$$;
revoke all on function public.food_submit_payment(uuid,text) from public, anon;
grant execute on function public.food_submit_payment(uuid,text) to authenticated, service_role;

create or replace function public.food_set_payment_status(
  p_order_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_provider = 'stripe'
     or (v_order.stripe_checkout_session_id is not null and v_order.payment_slip_path is null) then
    raise exception 'stripe payment status is managed by webhook';
  end if;
  if p_status not in ('paid','issue','refunded') then raise exception 'invalid payment status'; end if;

  update public.food_orders
  set payment_status=p_status,
      payment_note=v_note,
      payment_verification_status=case
        when p_status='paid' then 'manual_verified'
        when p_status='issue' then 'rejected'
        else payment_verification_status
      end,
      payment_provider=case when p_status in ('paid','issue') then 'merchant_manual' else payment_provider end,
      payment_verified_at=case when p_status in ('paid','issue') then now() else payment_verified_at end,
      payment_verification_note=case when p_status in ('paid','issue') then v_note else payment_verification_note end,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end,
      refund_status=case when p_status='refunded' then 'refunded' else refund_status end,
      refunded_at=case when p_status='refunded' then coalesce(refunded_at,now()) else refunded_at end,
      refund_updated_by=case when p_status='refunded' then auth.uid() else refund_updated_by end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_' || p_status,v_note,auth.uid());
end;
$$;
revoke all on function public.food_set_payment_status(uuid,text,text) from public, anon;
grant execute on function public.food_set_payment_status(uuid,text,text) to authenticated, service_role;
