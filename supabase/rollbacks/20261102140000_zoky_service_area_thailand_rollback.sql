-- Rollback for 20261102140000_zoky_service_area_thailand.sql.
-- Turns the Thailand service area off; ordering and store publishing go back
-- to Maha Sarakham only (the Maha Sarakham row is untouched). Re-runnable.
-- Orders that were already placed are not changed.
update public.food_service_areas set active = false, updated_at = now() where code = 'thailand';
