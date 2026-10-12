-- Rollback for GP v1 (20261011140000 + 20261011140100).
-- Only safe while no GP rate above 0 has been used on an order: once Stripe
-- has collected an application fee, keep the history and set the rate to 0
-- through admin_set_gp_rate instead of rolling back.
-- 1. Deploy the previous food-stripe-checkout / merchant-stripe-refund first.
-- 2. Restore the previous finance definitions:
--      supabase/migrations_wynos_merchant_finance_v1.sql
--      supabase/migrations/20261011120000_admin_merchant_finance_overview.sql
-- 3. Then:
drop trigger if exists food_orders_gp_snapshot on public.food_orders;
drop function if exists internal.food_orders_gp_snapshot();
drop function if exists public.admin_cancel_gp_rate(uuid, text);
drop function if exists public.admin_set_gp_rate(uuid, integer, timestamptz, timestamptz, text, uuid);
drop function if exists public.admin_gp_history(timestamptz, integer, uuid);
drop function if exists internal.merchant_gp_next_change(uuid);
drop function if exists public.admin_gp_settings();
drop function if exists public.food_order_gp_quote(uuid);
drop function if exists internal.food_order_gp(uuid);
drop function if exists internal.merchant_gp_rate_at(uuid, timestamptz);
-- The snapshot columns, application_fee_satang, indexes and the rates table
-- are left in place (nothing reads them after the steps above; dropping data
-- columns is a destructive change that needs its own approval).
