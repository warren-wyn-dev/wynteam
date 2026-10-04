-- WYNOS Places Manager + import pipeline v1
-- Admin-only management for standalone/public places. Merchant-owned places
-- keep syncing through the existing WYNOS Maps merchant triggers.

create unique index if not exists wynos_places_source_ref_unique
on public.wynos_places(source, source_ref)
where source_ref is not null;

create or replace function public.admin_wynos_places(
  p_query text default null,
  p_category text default null,
  p_status text default null,
  p_limit integer default 250
)
returns table (
  id text,
  name_th text,
  name_en text,
  category text,
  address text,
  building text,
  latitude double precision,
  longitude double precision,
  entrance_latitude double precision,
  entrance_longitude double precision,
  source text,
  source_ref text,
  verification_status text,
  merchant_store_id uuid,
  food_store_place_id uuid,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(left(btrim(coalesce(p_query, '')), 200), '');
  v_category text := nullif(btrim(coalesce(p_category, '')), '');
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 250), 1), 500);
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select
    p.id, p.name_th, p.name_en, p.category, p.address, p.building,
    p.latitude, p.longitude, p.entrance_latitude, p.entrance_longitude,
    p.source, p.source_ref, p.verification_status,
    p.merchant_store_id, p.food_store_place_id, p.is_active,
    p.created_at, p.updated_at
  from public.wynos_places p
  where
    (v_query is null
      or p.name_th ilike '%' || v_query || '%'
      or coalesce(p.name_en, '') ilike '%' || v_query || '%'
      or coalesce(p.address, '') ilike '%' || v_query || '%'
      or coalesce(p.source_ref, '') ilike '%' || v_query || '%')
    and (v_category is null or p.category = v_category)
    and (
      v_status is null
      or (v_status = 'active' and p.is_active)
      or (v_status = 'inactive' and not p.is_active)
      or p.verification_status = v_status
    )
  order by p.is_active desc, p.updated_at desc, p.name_th
  limit v_limit;
end;
$$;

revoke all on function public.admin_wynos_places(text,text,text,integer) from public, anon;
grant execute on function public.admin_wynos_places(text,text,text,integer) to authenticated;

create or replace function public.admin_upsert_wynos_place(
  p_place_id text,
  p_name_th text,
  p_name_en text default null,
  p_category text default 'place',
  p_address text default null,
  p_building text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_entrance_latitude double precision default null,
  p_entrance_longitude double precision default null,
  p_source text default 'wynos',
  p_source_ref text default null,
  p_verification_status text default 'unverified',
  p_is_active boolean default true
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_id text := nullif(btrim(coalesce(p_place_id, '')), '');
  v_name_th text := left(btrim(coalesce(p_name_th, '')), 160);
  v_name_en text := nullif(left(btrim(coalesce(p_name_en, '')), 160), '');
  v_address text := nullif(left(btrim(coalesce(p_address, '')), 1000), '');
  v_building text := nullif(left(btrim(coalesce(p_building, '')), 200), '');
  v_source_ref text := nullif(left(btrim(coalesce(p_source_ref, '')), 240), '');
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS Places';
  end if;
  if char_length(v_name_th) < 1 then
    raise exception 'place name is required';
  end if;
  if p_category not in ('place','restaurant','store','building','residence','pickup_point','dropoff_point','entrance','poi') then
    raise exception 'invalid place category';
  end if;
  if p_source not in ('wynos','osm','overture','user_report') then
    raise exception 'invalid place source';
  end if;
  if p_verification_status not in ('unverified','merchant_verified','wynos_verified') then
    raise exception 'invalid verification status';
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'invalid place location';
  end if;
  if (p_entrance_latitude is null) <> (p_entrance_longitude is null)
     or (p_entrance_latitude is not null and (
       p_entrance_latitude not between -90 and 90
       or p_entrance_longitude not between -180 and 180
     )) then
    raise exception 'invalid entrance location';
  end if;

  if v_id is null then
    insert into public.wynos_places (
      name_th, name_en, category, address, building, latitude, longitude,
      entrance_latitude, entrance_longitude, source, source_ref,
      verification_status, is_active
    ) values (
      v_name_th, v_name_en, p_category, v_address, v_building,
      p_latitude, p_longitude, p_entrance_latitude, p_entrance_longitude,
      p_source, v_source_ref, p_verification_status, p_is_active
    )
    returning id into v_id;
  else
    update public.wynos_places
    set name_th = v_name_th,
        name_en = v_name_en,
        category = p_category,
        address = v_address,
        building = v_building,
        latitude = p_latitude,
        longitude = p_longitude,
        entrance_latitude = p_entrance_latitude,
        entrance_longitude = p_entrance_longitude,
        source = case when merchant_store_id is not null or food_store_place_id is not null then source else p_source end,
        source_ref = case when merchant_store_id is not null or food_store_place_id is not null then source_ref else v_source_ref end,
        verification_status = p_verification_status,
        is_active = p_is_active
    where id = v_id;

    if not found then
      raise exception 'place not found';
    end if;
  end if;

  perform internal.log_audit_event(
    v_admin,
    'admin_wynos_place_saved',
    null,
    jsonb_build_object('place_id', v_id, 'name', v_name_th, 'category', p_category, 'active', p_is_active)
  );

  return v_id;
end;
$$;

revoke all on function public.admin_upsert_wynos_place(
  text,text,text,text,text,text,double precision,double precision,double precision,double precision,text,text,text,boolean
) from public, anon;
grant execute on function public.admin_upsert_wynos_place(
  text,text,text,text,text,text,double precision,double precision,double precision,double precision,text,text,text,boolean
) to authenticated;

create or replace function public.admin_set_wynos_place_active(
  p_place_id text,
  p_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_name text;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can manage WYNOS Places';
  end if;

  update public.wynos_places
  set is_active = p_active
  where id = p_place_id
  returning name_th into v_name;

  if not found then
    raise exception 'place not found';
  end if;

  perform internal.log_audit_event(
    v_admin,
    case when p_active then 'admin_wynos_place_enabled' else 'admin_wynos_place_disabled' end,
    null,
    jsonb_build_object('place_id', p_place_id, 'name', v_name)
  );
end;
$$;

revoke all on function public.admin_set_wynos_place_active(text,boolean) from public, anon;
grant execute on function public.admin_set_wynos_place_active(text,boolean) to authenticated;

create or replace function public.admin_import_wynos_places(
  p_places jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_row jsonb;
  v_count integer := 0;
  v_inserted integer := 0;
  v_updated integer := 0;
  v_existing text;
  v_source text;
  v_source_ref text;
  v_name text;
  v_category text;
  v_lat double precision;
  v_lon double precision;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can import WYNOS Places';
  end if;
  if jsonb_typeof(p_places) <> 'array' then
    raise exception 'places payload must be an array';
  end if;
  if jsonb_array_length(p_places) > 500 then
    raise exception 'maximum 500 places per import';
  end if;

  for v_row in select value from jsonb_array_elements(p_places)
  loop
    v_count := v_count + 1;
    v_source := lower(btrim(coalesce(v_row->>'source', '')));
    v_source_ref := nullif(left(btrim(coalesce(v_row->>'source_ref', '')), 240), '');
    v_name := left(btrim(coalesce(v_row->>'name_th', v_row->>'name', '')), 160);
    v_category := lower(btrim(coalesce(v_row->>'category', 'place')));
    v_lat := nullif(v_row->>'latitude', '')::double precision;
    v_lon := nullif(v_row->>'longitude', '')::double precision;

    if v_source not in ('osm','overture') then
      raise exception 'row %: source must be osm or overture', v_count;
    end if;
    if v_source_ref is null then
      raise exception 'row %: source_ref is required', v_count;
    end if;
    if v_name = '' then
      raise exception 'row %: name is required', v_count;
    end if;
    if v_category not in ('place','restaurant','store','building','residence','pickup_point','dropoff_point','entrance','poi') then
      raise exception 'row %: invalid category', v_count;
    end if;
    if v_lat is null or v_lon is null or v_lat not between -90 and 90 or v_lon not between -180 and 180 then
      raise exception 'row %: invalid location', v_count;
    end if;

    select p.id into v_existing
    from public.wynos_places p
    where p.source = v_source and p.source_ref = v_source_ref;

    insert into public.wynos_places (
      name_th, name_en, category, address, building, latitude, longitude,
      source, source_ref, verification_status, is_active
    ) values (
      v_name,
      nullif(left(btrim(coalesce(v_row->>'name_en', '')), 160), ''),
      v_category,
      nullif(left(btrim(coalesce(v_row->>'address', '')), 1000), ''),
      nullif(left(btrim(coalesce(v_row->>'building', '')), 200), ''),
      v_lat,
      v_lon,
      v_source,
      v_source_ref,
      'unverified',
      coalesce((v_row->>'is_active')::boolean, true)
    )
    on conflict (source, source_ref) where source_ref is not null do update
    set name_th = excluded.name_th,
        name_en = excluded.name_en,
        category = excluded.category,
        address = excluded.address,
        building = excluded.building,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        updated_at = now();

    if v_existing is null then
      v_inserted := v_inserted + 1;
    else
      v_updated := v_updated + 1;
    end if;
  end loop;

  perform internal.log_audit_event(
    v_admin,
    'admin_wynos_places_imported',
    null,
    jsonb_build_object('rows', v_count, 'inserted', v_inserted, 'updated', v_updated)
  );

  return jsonb_build_object(
    'rows', v_count,
    'inserted', v_inserted,
    'updated', v_updated
  );
end;
$$;

revoke all on function public.admin_import_wynos_places(jsonb) from public, anon;
grant execute on function public.admin_import_wynos_places(jsonb) to authenticated;

create or replace function public.admin_wynos_place_for_store(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_place public.wynos_places%rowtype;
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  select * into v_place
  from public.wynos_places
  where merchant_store_id = p_store_id
  limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_place.id,
    'name_th', v_place.name_th,
    'latitude', v_place.latitude,
    'longitude', v_place.longitude,
    'verification_status', v_place.verification_status,
    'is_active', v_place.is_active,
    'updated_at', v_place.updated_at
  );
end;
$$;

revoke all on function public.admin_wynos_place_for_store(uuid) from public, anon;
grant execute on function public.admin_wynos_place_for_store(uuid) to authenticated;
