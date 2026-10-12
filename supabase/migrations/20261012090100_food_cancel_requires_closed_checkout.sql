-- WYNOS Food: an unpaid order cannot be cancelled while its Stripe Checkout
-- is still open (P1, prevention side; Founder decision 2026-10-11: fail
-- closed when Stripe cannot be reached).
--
-- The guard applies when the BUYER cancels: the buyer's own browser holds the
-- Checkout link, and the WYNOS Food web first expires it through the existing
-- buyer-only food-stripe-cancel Edge Function (which clears
-- stripe_checkout_session_id), then cancels as before.
-- Store and admin cancels are not blocked (food-stripe-cancel stays
-- buyer-only); if a payment still lands, stripe-webhook refunds it
-- automatically (20261012090000_food_payment_integrity_v1.sql).
-- The 10-minute timeout worker runs without a user and is exempt as well.
-- Implemented as a trigger so food_cancel_order itself is not rewritten.
--
-- ROLLOUT ORDER: apply only AFTER the WYNOS Food web release that calls
-- food-stripe-cancel before cancelling is live. Applying it earlier makes
-- the buyer's cancel fail for orders with an open Checkout.
-- Apply: .github/workflows/food-apply-payment-integrity.yml (step cancel-guard).
-- Rollback: supabase/rollbacks/20261012090100_food_cancel_requires_closed_checkout_rollback.sql

create schema if not exists internal;

create or replace function internal.food_guard_cancel_open_checkout()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelled'
     and old.status is distinct from 'cancelled'
     and old.payment_status in ('pending','issue')
     and old.stripe_checkout_session_id is not null
     and old.buyer_id is not null
     and auth.uid() is not distinct from old.buyer_id then
    raise exception 'stripe checkout still open' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function internal.food_guard_cancel_open_checkout() from public, anon, authenticated;

drop trigger if exists trg_food_guard_cancel_open_checkout on public.food_orders;
create trigger trg_food_guard_cancel_open_checkout
before update of status on public.food_orders
for each row execute function internal.food_guard_cancel_open_checkout();
