-- Disable only Admin review moderation. Preserve review visibility data/history.
drop function if exists public.admin_set_food_review_hidden(uuid,timestamptz,boolean,text);
drop function if exists public.admin_food_review_moderation_feed(integer);
