-- Rollback for 20261026130000_zoky_fulfill_001_admin.sql. Run it before the
-- 20261026120000 rollback. The admin app falls back to admin_food_orders.
drop function if exists public.admin_food_orders_v2(uuid, text, text, integer);
