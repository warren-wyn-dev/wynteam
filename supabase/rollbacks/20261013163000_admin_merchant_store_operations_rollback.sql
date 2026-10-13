-- Rollback: disable only Admin-specific RPCs. Preserve store data and existing orders.
drop function if exists public.admin_update_merchant_store_operations(uuid,jsonb,boolean,timestamptz,text,integer,integer,text);
drop function if exists public.admin_merchant_store_operations();
