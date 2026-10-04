-- WYNOS Maps Photon fallback v1
-- Photon public demo is used only as a temporary fallback until WYNOS self-hosted
-- geocoding is online. Keep aggregate traffic conservative and cache reverse results.

create table if not exists internal.wynos_maps_photon_throttle (
  singleton boolean primary key default true check (singleton),
  last_requested_at timestamptz
);

insert into internal.wynos_maps_photon_throttle(singleton, last_requested_at)
values (true, null)
on conflict (singleton) do nothing;

create or replace function public.reserve_wynos_maps_photon_request()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended('wynos_maps_photon_global', 0));

  select last_requested_at into v_last
  from internal.wynos_maps_photon_throttle
  where singleton = true
  for update;

  if v_last is not null and clock_timestamp() - v_last < interval '500 milliseconds' then
    return false;
  end if;

  update internal.wynos_maps_photon_throttle
  set last_requested_at = clock_timestamp()
  where singleton = true;

  return true;
end;
$$;

create or replace function public.wynos_maps_reverse_cache_put(
  p_cache_key text,
  p_latitude double precision,
  p_longitude double precision,
  p_name text,
  p_address text,
  p_external_place_id text,
  p_provider text default 'osm'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_latitude not between -90 and 90
     or p_longitude not between -180 and 180
     or coalesce(char_length(btrim(p_name)), 0) = 0 then
    raise exception 'invalid reverse geocode cache row';
  end if;

  insert into internal.wynos_maps_reverse_cache(
    cache_key, latitude, longitude, name, address,
    external_place_id, provider, expires_at, updated_at
  ) values (
    left(btrim(p_cache_key), 80),
    p_latitude,
    p_longitude,
    left(btrim(p_name), 240),
    nullif(left(btrim(coalesce(p_address, '')), 1200), ''),
    nullif(left(btrim(coalesce(p_external_place_id, '')), 160), ''),
    case when p_provider in ('osm', 'locationiq', 'photon') then p_provider else 'photon' end,
    now() + interval '30 days',
    now()
  )
  on conflict (cache_key) do update
  set latitude = excluded.latitude,
      longitude = excluded.longitude,
      name = excluded.name,
      address = excluded.address,
      external_place_id = excluded.external_place_id,
      provider = excluded.provider,
      expires_at = excluded.expires_at,
      updated_at = now();
end;
$$;

revoke all on function public.reserve_wynos_maps_photon_request() from public, anon, authenticated;
grant execute on function public.reserve_wynos_maps_photon_request() to service_role;

revoke all on function public.wynos_maps_reverse_cache_put(text,double precision,double precision,text,text,text,text)
from public, anon, authenticated;
grant execute on function public.wynos_maps_reverse_cache_put(text,double precision,double precision,text,text,text,text)
to service_role;
