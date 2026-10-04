-- WYNOS Maps nearby public places v1
-- Public callers only see active places. Developer accounts may also preview
-- their WYNOS Food merchant places before public rollout.

create or replace function public.wynos_nearby_places(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km double precision default 25,
  p_limit integer default 60
)
returns table (
  place_id text,
  name text,
  address text,
  latitude double precision,
  longitude double precision,
  category text,
  verification_status text,
  merchant_store_id uuid,
  store_slug text,
  is_open boolean,
  delivery_radius_km numeric,
  distance_km numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_developer boolean := coalesce(public.is_developer_account(), false);
  v_radius double precision := least(greatest(coalesce(p_radius_km, 25), 1), 50);
  v_limit integer := least(greatest(coalesce(p_limit, 60), 1), 100);
begin
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid location';
  end if;

  return query
  select
    p.id,
    coalesce(nullif(p.name_th, ''), nullif(p.name_en, ''), 'สถานที่')::text,
    p.address,
    p.latitude,
    p.longitude,
    p.category,
    p.verification_status,
    s.id,
    s.slug,
    s.is_open,
    s.delivery_radius_km,
    internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude)
  from public.wynos_places p
  left join public.food_store_places fsp
    on fsp.id = p.food_store_place_id
  left join public.food_stores s
    on s.id = coalesce(p.merchant_store_id, fsp.store_id)
  where
    (
      p.is_active
      or (
        v_developer
        and s.id is not null
        and s.admin_suspended_at is null
      )
    )
    and internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude) <= v_radius
  order by
    case
      when p.category = 'restaurant' then 0
      when p.category = 'pickup_point' then 1
      else 2
    end,
    (p.verification_status = 'wynos_verified') desc,
    (p.verification_status = 'merchant_verified') desc,
    internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude),
    p.name_th
  limit v_limit;
end;
$$;

revoke all on function public.wynos_nearby_places(double precision,double precision,double precision,integer)
from public;
grant execute on function public.wynos_nearby_places(double precision,double precision,double precision,integer)
to anon, authenticated;
