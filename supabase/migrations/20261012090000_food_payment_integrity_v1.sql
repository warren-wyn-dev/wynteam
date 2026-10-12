-- WYNOS Food payment integrity v1 (P1 webhook side, P2 pin, P3)
--
-- 1. food_apply_stripe_event
--    * A Stripe payment that lands on an order that is already cancelled is
--      still recorded (the money was taken) but the order is flagged for an
--      automatic refund: refund_status='pending', event 'paid_after_cancel',
--      store members and buyer notified. stripe-webhook then issues the
--      refund (Founder decision 2026-10-11: automatic refund).
--    * A Stripe payment on an order whose slip is under review is recorded
--      and flagged 'duplicate_payment_risk' for the store to resolve.
--    * A late 'failed' event never downgrades a paid/refunded ledger row.
--    * A refund event that arrives before the payment is recorded raises,
--      so Stripe retries it instead of the event being consumed silently.
-- 2. food_set_payment_status (merchant, P3): row lock; 'paid'/'issue' are
--    refused on cancelled orders; 'refunded' needs a paid order. The Stripe
--    guard already live in production is kept.
-- 3. food_submit_payment: the live, Stripe-guarded version is pinned again
--    with search_path='' so a re-run legacy file is caught by the
--    postflight check and by supabase/tests/food_payment_integrity_test.sh.
--
-- Same signatures and grants as production (checked 2026-10-11 by
-- food-payment-integrity-readonly-check.yml). No table, column or data
-- change. Safe to re-run.
-- ROLLOUT ORDER: deploy the stripe-webhook Edge Function from the same release
-- FIRST (it does nothing extra on the old database). Applied before it, a
-- payment landing on a cancelled order would be left refund-pending without
-- the automatic refund.
-- Apply: .github/workflows/food-apply-payment-integrity.yml (Founder approval).
-- Rollback: supabase/rollbacks/20261012090000_food_payment_integrity_v1_rollback.sql

-- Preflight: stop before changing anything if production is not the shape
-- this migration was written for.
do $$
begin
  if to_regprocedure('public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)') is null
     or to_regprocedure('public.food_set_payment_status(uuid,text,text)') is null
     or to_regprocedure('public.food_submit_payment(uuid,text)') is null
     or to_regprocedure('public.merchant_has_store_role(uuid,text[])') is null then
    raise exception 'food payment integrity: expected payment functions are missing';
  end if;
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'food_create_order' and p.pronargs = 6
  ) then
    raise exception 'food payment integrity: legacy 6-argument food_create_order exists; resolve it first';
  end if;
  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'food_orders'
        and column_name in ('stripe_checkout_session_id','stripe_payment_intent_id','stripe_refund_id',
                            'refund_status','refund_note','refund_requested_at','paid_at')) <> 7 then
    raise exception 'food payment integrity: food_orders is missing payment columns';
  end if;
end;
$$;

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
  v_reason text;
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
  -- Out of order: a refund before the payment is recorded. Raising rolls back
  -- the event claim above, so Stripe delivers it again later.
  if p_state = 'refunded' and o.payment_status not in ('paid','refunded') then
    raise exception 'refund before payment recorded';
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
    -- A late failure (e.g. an earlier declined card) never downgrades money taken.
    status = case
      when excluded.status = 'failed' and public.food_stripe_payments.status in ('paid','refunded')
        then public.food_stripe_payments.status
      else excluded.status
    end,
    payment_method = coalesce(excluded.payment_method, public.food_stripe_payments.payment_method),
    paid_at = coalesce(public.food_stripe_payments.paid_at, excluded.paid_at),
    refunded_at = coalesce(excluded.refunded_at, public.food_stripe_payments.refunded_at),
    last_error = case
      when excluded.status = 'failed' and public.food_stripe_payments.status in ('paid','refunded')
        then public.food_stripe_payments.last_error
      else excluded.last_error
    end,
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
        payment_note = null,
        refund_status = case when o.status = 'cancelled' and refund_status = 'none' then 'pending' else refund_status end,
        refund_requested_at = case when o.status = 'cancelled' then coalesce(refund_requested_at, now()) else refund_requested_at end,
        refund_note = case
          when o.status = 'cancelled' and refund_status = 'none'
            then 'ชำระเงินหลังออเดอร์ถูกยกเลิก ระบบกำลังคืนเงินอัตโนมัติ'
          else refund_note
        end
    where id = o.id and payment_status in ('pending','issue','submitted','paid');

    if o.status = 'cancelled' and o.payment_status <> 'paid' then
      v_reason := 'ออเดอร์ #' || o.order_number || ' ได้รับเงินผ่าน Stripe หลังถูกยกเลิก ระบบกำลังคืนเงินอัตโนมัติ';
      insert into public.food_order_events(order_id,event_type,note,actor_id)
      values (o.id,'paid_after_cancel',v_reason,null);
    elsif o.payment_status = 'submitted' then
      v_reason := 'ออเดอร์ #' || o.order_number || ' ชำระผ่าน Stripe ขณะสลิปโอนเงินรอตรวจ กรุณาตรวจสอบการชำระซ้ำ';
      insert into public.food_order_events(order_id,event_type,note,actor_id)
      values (o.id,'duplicate_payment_risk',v_reason,null);
    end if;

    if v_reason is not null then
      insert into public.merchant_notifications(merchant_account_id, recipient_user_id, type, reason)
      select s.merchant_account_id, mm.user_id, 'payment', 'WYNOS Merchant · ' || v_reason
      from public.food_stores s
      join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id and mm.active
      where s.id = o.store_id;
      if o.status = 'cancelled' and o.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (o.buyer_id, null, 'system',
          'ออเดอร์ #' || o.order_number || ' ถูกยกเลิกแล้ว แต่ได้รับเงินของคุณ ระบบกำลังคืนเงินให้อัตโนมัติ');
      end if;
    end if;
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

-- Same as the live Stripe-guarded version, with search_path=''.
create or replace function public.food_submit_payment(p_order_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id for update;
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
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders']) then
    raise exception 'order management role required';
  end if;
  if v_order.payment_provider = 'stripe'
     or (v_order.stripe_checkout_session_id is not null and v_order.payment_slip_path is null) then
    raise exception 'stripe payment status is managed by webhook';
  end if;
  if p_status not in ('paid','issue','refunded') then raise exception 'invalid payment status'; end if;
  -- P3: a cancelled order is settled through the refund flow, not re-marked.
  if v_order.status = 'cancelled' and p_status in ('paid','issue') then
    raise exception 'order is cancelled';
  end if;
  if p_status = 'refunded' and v_order.payment_status not in ('paid','refunded') then
    raise exception 'order is not paid';
  end if;

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

-- Postflight: the guards are really in place and privileges are unchanged.
do $$
begin
  if pg_get_functiondef('public.food_submit_payment(uuid,text)'::regprocedure)
       not like '%cancel stripe checkout before submitting slip%'
     or pg_get_functiondef('public.food_set_payment_status(uuid,text,text)'::regprocedure)
       not like '%stripe payment status is managed by webhook%'
     or pg_get_functiondef('public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)'::regprocedure)
       not like '%paid_after_cancel%' then
    raise exception 'food payment integrity: guard missing after apply';
  end if;
  if has_function_privilege('anon','public.food_submit_payment(uuid,text)','execute')
     or has_function_privilege('anon','public.food_set_payment_status(uuid,text,text)','execute')
     or has_function_privilege('authenticated','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute') then
    raise exception 'food payment integrity: unexpected privilege after apply';
  end if;
end;
$$;
