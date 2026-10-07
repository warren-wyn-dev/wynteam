-- WYNOS Finance Control Center: PromptPay-via-Stripe-only for new orders.
-- Legacy orders created before finance snapshots keep the old slip path.

create or replace function public.food_submit_payment(p_order_id uuid,p_slip_path text)
returns void
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id=p_order_id;
  if not found or v_order.buyer_id<>auth.uid() then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  if v_order.payment_status not in ('pending','issue') then raise exception 'payment already submitted'; end if;

  -- New Finance Control Center orders are PromptPay-via-Stripe only.
  -- This server-side guard prevents a stale/modified frontend from reviving
  -- the legacy slip flow. Historical orders keep their original behavior.
  if v_order.finance_config_id is not null
     or exists(select 1 from public.food_order_financials f where f.order_id=v_order.id) then
    raise exception 'PromptPay via Stripe is required for this order';
  end if;

  if v_order.stripe_checkout_session_id is not null then
    raise exception 'cancel stripe checkout before submitting slip';
  end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text||'/slips/'||p_order_id::text||'/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status='submitted',
      payment_slip_path=p_slip_path,
      payment_note=null,
      payment_verification_status='manual_review',
      payment_provider=null,
      payment_provider_code=null,
      payment_transaction_ref=null,
      payment_verified_at=null,
      payment_verification_note=null
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values(p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$$;
