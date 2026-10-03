-- WYN-197: each store keeps its own list of places near the store.
--
-- Founder (2026-10-03): place search must be free, so instead of a paid
-- geocoding service the store lists the places it delivers to (dorms,
-- condos, villages) with a pin. Customers search that list when they add an
-- address; "use current location" still works when a place is not listed.
--
-- * public.food_store_places: one row per place, owned by a store.
-- * Merchants (owner/admin/manager) manage their own store's list through
--   RLS; staff of other stores see nothing.
-- * Customers search through public.food_search_store_places(), which only
--   returns active places of a store they could order from. Places are
--   landmarks the store chose to publish, not customer data.
--
-- Additive: one new table, its policies and one RPC. No existing object is
-- changed. Rollback: drop function public.food_search_store_places(uuid,text);
-- drop table public.food_store_places; (the web hides the feature when the
-- RPC is missing).

create table if not exists public.food_store_places (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id) on delete cascade,
  name text not null,
  detail text,
  latitude double precision not null,
  longitude double precision not null,
  is_active boolean not null default true,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_store_places_name_length check (char_length(btrim(name)) between 1 and 120),
  constraint food_store_places_detail_length check (detail is null or char_length(detail) <= 200),
  constraint food_store_places_location_range check (
    latitude between -90 and 90 and longitude between -180 and 180
  )
);

create index if not exists food_store_places_store_idx
  on public.food_store_places(store_id, is_active, name);

drop trigger if exists food_store_places_touch_updated_at on public.food_store_places;
create trigger food_store_places_touch_updated_at
before update on public.food_store_places
for each row execute function public.food_touch_updated_at();

alter table public.food_store_places enable row level security;
revoke all on table public.food_store_places from public, anon;
grant select, insert, update, delete on table public.food_store_places to authenticated;

drop policy if exists "Food store places visible to merchant" on public.food_store_places;
create policy "Food store places visible to merchant"
on public.food_store_places for select to authenticated
using (public.food_has_merchant_access(store_id));

drop policy if exists "Food store places inserted by merchant" on public.food_store_places;
create policy "Food store places inserted by merchant"
on public.food_store_places for insert to authenticated
with check (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

drop policy if exists "Food store places updated by merchant" on public.food_store_places;
create policy "Food store places updated by merchant"
on public.food_store_places for update to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin','manager']))
with check (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

drop policy if exists "Food store places deleted by merchant" on public.food_store_places;
create policy "Food store places deleted by merchant"
on public.food_store_places for delete to authenticated
using (public.merchant_has_store_role(store_id, array['owner','admin','manager']));

-- Customer search. Same store visibility as food_quote_order: developers see
-- every store, everyone else only published stores once Food is public.
create or replace function public.food_search_store_places(
  p_store_id uuid,
  p_query text default null
)
returns table(id uuid, name text, detail text, latitude double precision, longitude double precision)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_query text := left(btrim(coalesce(p_query, '')), 100);
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  select * into v_store from public.food_stores s where s.id = p_store_id;
  if not found
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  -- LIKE wildcards in the customer's text are matched literally.
  v_query := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_');

  return query
  select p.id, p.name, p.detail, p.latitude, p.longitude
  from public.food_store_places p
  where p.store_id = p_store_id
    and p.is_active
    and (
      v_query = ''
      or p.name ilike '%' || v_query || '%'
      or coalesce(p.detail, '') ilike '%' || v_query || '%'
    )
  order by
    (v_query <> '' and p.name ilike v_query || '%') desc,
    p.name
  limit 20;
end;
$$;

revoke all on function public.food_search_store_places(uuid,text) from public, anon;
grant execute on function public.food_search_store_places(uuid,text) to authenticated;
