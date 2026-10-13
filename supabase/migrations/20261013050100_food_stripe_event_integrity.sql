-- Additive ledger ordering + explicit refund failure. No provider operations.
begin;
create or replace function internal.food_stripe_payment_monotonic()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.status in ('paid','refunded') then
    new.payment_intent_id := old.payment_intent_id;
    new.checkout_session_id := old.checkout_session_id;
    new.stripe_account_id := old.stripe_account_id;
    new.amount_satang := old.amount_satang;
    new.currency := old.currency;
    new.payment_method := old.payment_method;
  end if;
  if (old.status='refunded' and new.status<>'refunded')
     or (old.status='paid' and new.status not in ('paid','refunded')) then
    new.status:=old.status;
    new.last_error:=old.last_error;
  end if;
  new.paid_at:=coalesce(old.paid_at,new.paid_at);
  new.refunded_at:=coalesce(old.refunded_at,new.refunded_at);
  return new;
end;
$$;
revoke all on function internal.food_stripe_payment_monotonic() from public,anon,authenticated;
drop trigger if exists food_stripe_payments_monotonic on public.food_stripe_payments;
create trigger food_stripe_payments_monotonic before update on public.food_stripe_payments
for each row execute function internal.food_stripe_payment_monotonic();

create or replace function internal.food_stripe_order_payment_identity()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.payment_provider='stripe' and old.payment_status in ('paid','refunded') then
    new.stripe_payment_intent_id:=old.stripe_payment_intent_id;
    new.stripe_checkout_session_id:=old.stripe_checkout_session_id;
    new.payment_transaction_ref:=old.payment_transaction_ref;
    new.payment_provider:=old.payment_provider;
  end if;
  return new;
end;
$$;
revoke all on function internal.food_stripe_order_payment_identity() from public,anon,authenticated;
drop trigger if exists food_orders_stripe_payment_identity on public.food_orders;
create trigger food_orders_stripe_payment_identity before update on public.food_orders
for each row execute function internal.food_stripe_order_payment_identity();

create or replace function public.food_record_stripe_refund_failure(
  p_event_id text,p_event_type text,p_order_id uuid,p_stripe_account_id text,
  p_refund_id text,p_payment_intent_id text,p_amount_satang bigint,p_currency text
) returns boolean language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype; p public.food_stripe_payments%rowtype;
begin
  if p_event_id is null or length(p_event_id)<3 or p_refund_id is null
    or p_event_type not in ('refund.failed','refund.updated') then raise exception 'invalid refund event'; end if;
  select * into o from public.food_orders where id=p_order_id for update;
  if not found then raise exception 'order not found'; end if;
  select * into p from public.food_stripe_payments where order_id=p_order_id;
  if not found or p.stripe_account_id is distinct from p_stripe_account_id
    or p.payment_intent_id is distinct from p_payment_intent_id
    or p_payment_intent_id is null then raise exception 'refund account or payment mismatch'; end if;
  if lower(coalesce(p_currency,''))<>'thb' or p_amount_satang is distinct from round(o.total*100)::bigint then
    raise exception 'refund amount or currency mismatch';
  end if;
  -- A newer requested refund must not be failed by an older refund's event.
  if o.stripe_refund_id is not null and o.stripe_refund_id<>p_refund_id then
    raise exception 'refund id mismatch';
  end if;
  insert into public.food_stripe_webhook_events(event_id,event_type,stripe_account_id,order_id,object_id)
    values(p_event_id,p_event_type,p_stripe_account_id,p_order_id,p_refund_id) on conflict(event_id) do nothing;
  if not found then return false; end if;
  if o.payment_status='paid' and o.refund_status<>'refunded' then
    update public.food_orders set refund_status='failed',stripe_refund_id=p_refund_id,
      refund_note='การคืนเงินไม่สำเร็จ กรุณาตรวจสอบก่อนลองใหม่' where id=o.id;
    insert into public.food_order_events(order_id,event_type,note,actor_id)
      values(o.id,'refund_failed','Stripe confirmed refund failure',null);
  end if;
  return true;
end;
$$;
revoke all on function public.food_record_stripe_refund_failure(text,text,uuid,text,text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.food_record_stripe_refund_failure(text,text,uuid,text,text,text,bigint,text) to service_role;
commit;
