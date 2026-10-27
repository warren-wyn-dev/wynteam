-- ZOKY-FULFILL-001 follow-up: a refund needs the store's refund slip on every
-- path. Closes the Founder risk acceptance of 2026-10-26 (APPROVALS.md, "ก"):
-- the legacy RPCs merchant_set_refund_status('refunded') and
-- food_set_payment_status('refunded') let store staff mark a transfer/COD
-- refund as done without a slip. The ZOKY-FULFILL-001 Merchant app (round 5,
-- live 2026-10-27) records refunds through food_store_mark_refunded only, and
-- the legacy web refund panel is shown for Stripe orders only.
--
-- * food_store_mark_refunded saves the slip before it marks the refund, so the
--   guard below sees it. Checks are unchanged.
-- * A guard on food_orders refuses any signed-in caller turning refund_status
--   or payment_status into 'refunded' while refund_slip_path is null.
--   Stripe orders (webhook-managed) and service-role jobs (no auth.uid()) are
--   not affected; 'pending' and 'failed' refund updates are not affected.
-- Rollback: supabase/rollbacks/20261027090000_zoky_fulfill_001_refund_slip_rollback.sql
-- (run it before the main ZOKY-FULFILL-001 rollback).

create or replace function public.food_store_mark_refunded(
  p_order_id uuid, p_refund_slip_path text, p_note text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.food_orders%rowtype;
begin
  select * into v_order from public.food_orders where id = p_order_id for update;
  if not found or not public.merchant_has_store_role(v_order.store_id, array['owner','admin','manager']) then
    raise exception 'refund role required';
  end if;
  if v_order.refund_status <> 'pending' then raise exception 'no refund pending'; end if;
  if p_refund_slip_path is null
     or p_refund_slip_path not like 'refunds/' || p_order_id::text || '/%'
     or position('..' in p_refund_slip_path) > 0
     or not exists (select 1 from storage.objects o where o.bucket_id = 'food-private' and o.name = p_refund_slip_path) then
    raise exception 'refund slip is required';
  end if;
  update public.food_orders
  set refund_slip_path = p_refund_slip_path, refunded_by_store_at = now()
  where id = p_order_id;
  perform public.merchant_set_refund_status(p_order_id, 'refunded', p_note);
end;
$$;
revoke all on function public.food_store_mark_refunded(uuid, text, text) from public, anon;
grant execute on function public.food_store_mark_refunded(uuid, text, text) to authenticated;

create or replace function internal.food_orders_refund_slip_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and new.refund_slip_path is null
     and coalesce(new.payment_provider, '') <> 'stripe'
     and ((new.refund_status = 'refunded' and old.refund_status is distinct from 'refunded')
       or (new.payment_status = 'refunded' and old.payment_status is distinct from 'refunded')) then
    raise exception 'refund slip is required';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_orders_refund_slip_guard() from public, anon, authenticated;
drop trigger if exists food_orders_refund_slip_guard on public.food_orders;
create trigger food_orders_refund_slip_guard
before update of refund_status, payment_status on public.food_orders
for each row execute function internal.food_orders_refund_slip_guard();
