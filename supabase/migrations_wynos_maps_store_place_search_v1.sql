-- WYNOS Maps: expose merchant-managed store places with their WYNOS Place ID.
create or replace function public.wynos_search_store_places(
  p_store_id uuid,
  p_query text default null
)
returns table (
  place_id text,
  name text,
  detail text,
  latitude double precision,
  longitude double precision
)
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

  select * into v_store
  from public.food_stores s
  where s.id = p_store_id;

  if not found
     or (
       not public.is_developer_account()
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
         or v_store.admin_suspended_at is not null
       )
     ) then
    raise exception 'store is not accepting orders';
  end if;

  v_query := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_');

  return query
  select
    wp.id,
    p.name,
    p.detail,
    p.latitude,
    p.longitude
  from public.food_store_places p
  left join public.wynos_places wp
    on wp.food_store_place_id = p.id
  where p.store_id = p_store_id
    and p.is_active
    and (
      v_query = ''
      or p.name ilike '%' || v_query || '%' escape '\'
      or coalesce(p.detail, '') ilike '%' || v_query || '%' escape '\'
    )
  order by
    (v_query <> '' and p.name ilike v_query || '%' escape '\') desc,
    p.name
  limit 20;
end;
$$;

revoke all on function public.wynos_search_store_places(uuid,text) from public, anon;
grant execute on function public.wynos_search_store_places(uuid,text) to authenticated;
