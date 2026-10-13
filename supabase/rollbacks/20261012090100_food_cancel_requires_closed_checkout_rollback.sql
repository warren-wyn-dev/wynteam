-- Rollback for migrations/20261012090100_food_cancel_requires_closed_checkout.sql
-- Removes the open-Checkout cancel guard. Effect: cancel works again while a
-- Stripe Checkout is open (P1 prevention off); the webhook-side refund from
-- 20261012090000_food_payment_integrity_v1.sql still catches late payments.
drop trigger if exists trg_food_guard_cancel_open_checkout on public.food_orders;
drop function if exists internal.food_guard_cancel_open_checkout();
