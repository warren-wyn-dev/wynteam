-- Rollback: remove Admin-only menu RPCs without changing any menu records.
drop function if exists public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text);
drop function if exists public.admin_merchant_menu_items(uuid);
