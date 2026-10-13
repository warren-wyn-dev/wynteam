-- Rollback for 20261013161500_admin_merchant_delivery_live.sql.
-- Removes Admin-specific API only; leaves all store settings unchanged.
drop function if exists public.admin_update_merchant_delivery(uuid,jsonb,numeric,numeric,numeric,numeric,text);
drop function if exists public.admin_merchant_delivery_stores();
