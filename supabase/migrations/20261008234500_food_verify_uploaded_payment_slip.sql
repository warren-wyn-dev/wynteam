-- Additive Food payment hardening. No existing order rows are changed.
-- Preserve buyer, payment state, manual fallback and Stripe guards.
-- Security definer checks actual private Storage object plus serializes updates.
-- Rollout only after disposable-PostgreSQL QA; existing QR/slip orders unaffected.
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

  -- Serialize concurrent submissions: only the first can move pending/issue to submitted.
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

  -- The customer must upload evidence into the private bucket before
  -- marking an order submitted. Merely typing a valid path is not proof.
  if not exists(
    select 1 from storage.objects object
    where object.bucket_id='food-private' and object.name=p_slip_path
  ) then
    raise exception 'payment slip file not uploaded';
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
