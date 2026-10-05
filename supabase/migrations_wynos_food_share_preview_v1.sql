-- WYNOS Food share link previews (Founder approved 2026-10-05: "อนุมัติ ทำเลย").
-- LINE/Messenger fetch https://food.wynos.online/?store=<id> without signing
-- in, so the page needs a store's public profile to build its preview.
-- Returns only what a customer sees on the store card -- name, a short
-- description, logo and cover paths (already in the public food-public
-- bucket) -- and only for published, non-suspended stores. Never phone,
-- address, payment details, owner, menu or orders.
-- ROLLBACK: drop function public.food_store_share_preview(uuid);

create or replace function public.food_store_share_preview(p_store_id uuid)
returns table (
  id uuid,
  name text,
  description text,
  logo_path text,
  cover_path text
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id,
         s.name,
         left(nullif(btrim(coalesce(s.description, '')), ''), 160),
         s.logo_path,
         s.cover_path
  from public.food_stores s
  where s.id = p_store_id
    and s.is_published
    and s.admin_suspended_at is null
$$;

revoke all on function public.food_store_share_preview(uuid) from public;
grant execute on function public.food_store_share_preview(uuid) to anon, authenticated;
