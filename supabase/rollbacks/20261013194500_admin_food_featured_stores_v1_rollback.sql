-- Rollback of feature routing with data/history preserved for recovery.
update public.food_featured_stores set active=false where active;
drop function if exists public.admin_save_food_featured_store(uuid,integer,integer,boolean,timestamptz,timestamptz,text);
drop function if exists public.admin_food_featured_stores();
drop function if exists public.food_active_featured_stores();
