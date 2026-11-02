-- Rollback for 20261103100000_zoky_service_area_admin.sql. Re-runnable.
-- Removes the admin and map RPCs and the 76 province rows, and puts the two
-- original areas back on (whole country + Maha Sarakham), so ordering works
-- exactly as after 20261102140000_zoky_service_area_thailand.sql.
-- The extra columns stay (harmless); audit rows are kept.
drop function if exists public.admin_zoky_set_service_area(text, boolean);
drop function if exists public.admin_zoky_service_areas();
drop function if exists public.food_service_area_overview();
drop function if exists public.food_service_area_boundaries();
update public.food_service_areas set active = true, updated_at = now() where code in ('thailand', 'maha_sarakham');
delete from public.food_service_areas where kind = 'province' and code <> 'maha_sarakham';
