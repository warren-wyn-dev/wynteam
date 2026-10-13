-- Emergency rollback: disable active banners, remove public/admin APIs and storage upload access.
-- Existing files, banner drafts and audit history are deliberately preserved.
update public.food_home_banners set is_active=false where is_active;
drop policy if exists "Food banner Admin upload" on storage.objects;
drop function if exists public.admin_food_banner_history(uuid);
drop function if exists public.admin_save_food_home_banner(uuid,integer,text,text,text,uuid,integer,timestamptz,timestamptz,boolean,text);
drop function if exists public.admin_food_home_banners();
drop function if exists public.food_active_home_banners();
drop function if exists public.food_banner_admin_can_edit();
