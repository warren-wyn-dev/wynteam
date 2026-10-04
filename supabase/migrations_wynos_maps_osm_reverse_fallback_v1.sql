-- WYNOS Maps OSM reverse fallback cache + global throttle v1
-- Temporary fallback while WYNOS self-hosted Nominatim is not online.
-- Public Nominatim policy: cache results and keep total app traffic <= 1 req/s.

create table if not exists internal.wynos_maps_reverse_cache (
  cache_key text primary key,
  latitude double precision not null,
  longitude double precision not null,
  name text not null,
  address text,
  external_place_id text,
  provider text not null default 'osm',
  expires_at timestamptz not null default (now() + interval '30 days'),
  updated_at timestamptz not null default now()
);

create table if not exists internal.wynos_maps_nominatim_throttle (
  singleton boolean primary key default true check (singleton),
  last_requested_at timestamptz
);

insert into internal.wynos_maps_nominatim_throttle(singleton, last_requested_at)
values (true, null)
on conflict (singleton) do nothing;

create or replace function public.wynos_maps_reverse_cache_get(
  p_cache_key text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row internal.wynos_maps_reverse_cache%rowtype;
begin
  select * into v_row
  from internal.wynos_maps_reverse_cache
  where cache_key = left(btrim(coalesce(p_cache_key, '')), 80)
    and expires_at > now();

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'name', v_row.name,
    'address', v_row.address,
    'lat', v_row.latitude,
    'lon', v_row.longitude,
    'place_id', v_row.external_place_id,
    'provider', v_row.provider
  );
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
    case when p_provider in ('osm', 'locationiq') then p_provider else 'osm' end,
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

create or replace function public.reserve_wynos_maps_nominatim_request()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended('wynos_maps_nominatim_global', 0));

  select last_requested_at into v_last
  from internal.wynos_maps_nominatim_throttle
  where singleton = true
  for update;

  if v_last is not null and clock_timestamp() - v_last < interval '1 second' then
    return false;
  end if;

  update internal.wynos_maps_nominatim_throttle
  set last_requested_at = clock_timestamp()
  where singleton = true;

  return true;
end;
$$;

revoke all on function public.wynos_maps_reverse_cache_get(text) from public, anon, authenticated;
revoke all on function public.wynos_maps_reverse_cache_put(text,double precision,double precision,text,text,text,text) from public, anon, authenticated;
revoke all on function public.reserve_wynos_maps_nominatim_request() from public, anon, authenticated;

grant execute on function public.wynos_maps_reverse_cache_get(text) to service_role;
grant execute on function public.wynos_maps_reverse_cache_put(text,double precision,double precision,text,text,text,text) to service_role;
grant execute on function public.reserve_wynos_maps_nominatim_request() to service_role;
