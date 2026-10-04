-- WYNOS Maps Places + Saved Address v1
-- Additive core for Thailand-first Maps/Food. User home addresses remain private;
-- only public/merchant places are synced into WYNOS Places.

create table if not exists public.wynos_places (
  id text primary key default ('wynos_place_' || replace(gen_random_uuid()::text, '-', '')),
  name_th text not null,
  name_en text,
  category text not null default 'place',
  address text,
  building text,
  latitude double precision not null,
  longitude double precision not null,
  entrance_latitude double precision,
  entrance_longitude double precision,
  source text not null default 'wynos',
  source_ref text,
  verification_status text not null default 'unverified',
  merchant_store_id uuid unique references public.food_stores(id) on delete cascade,
  food_store_place_id uuid unique references public.food_store_places(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wynos_places_id_format check (id ~ '^wynos_place_[0-9a-f]{32}$'),
  constraint wynos_places_name_th_length check (char_length(btrim(name_th)) between 1 and 160),
  constraint wynos_places_name_en_length check (name_en is null or char_length(name_en) <= 160),
  constraint wynos_places_category check (category in (
    'place','restaurant','store','building','residence','pickup_point','dropoff_point','entrance','poi'
  )),
  constraint wynos_places_address_length check (address is null or char_length(address) <= 1000),
  constraint wynos_places_building_length check (building is null or char_length(building) <= 200),
  constraint wynos_places_latitude check (latitude between -90 and 90),
  constraint wynos_places_longitude check (longitude between -180 and 180),
  constraint wynos_places_entrance_pair check (
    (entrance_latitude is null and entrance_longitude is null)
    or (
      entrance_latitude between -90 and 90
      and entrance_longitude between -180 and 180
    )
  ),
  constraint wynos_places_source check (source in ('wynos','merchant','osm','overture','user_report')),
  constraint wynos_places_verification check (
    verification_status in ('unverified','merchant_verified','wynos_verified')
  )
);

create index if not exists wynos_places_active_name_th_idx
on public.wynos_places(lower(name_th))
where is_active;

create index if not exists wynos_places_active_name_en_idx
on public.wynos_places(lower(name_en))
where is_active and name_en is not null;

drop trigger if exists wynos_places_touch_updated_at on public.wynos_places;
create trigger wynos_places_touch_updated_at
before update on public.wynos_places
for each row execute function public.food_touch_updated_at();

alter table public.wynos_places enable row level security;

drop policy if exists "WYNOS places visible to authenticated" on public.wynos_places;
create policy "WYNOS places visible to authenticated"
on public.wynos_places for select to authenticated
using (is_active);

revoke all on table public.wynos_places from anon, authenticated;
grant select on table public.wynos_places to authenticated;
grant select, insert, update, delete on table public.wynos_places to service_role;

create or replace function public.wynos_sync_food_place()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_public boolean := false;
begin
  if tg_table_name = 'food_stores' then
    if new.latitude is null or new.longitude is null then
      update public.wynos_places
      set name_th = left(btrim(new.name), 160),
          address = nullif(left(btrim(coalesce(new.address, '')), 1000), ''),
          is_active = false
      where merchant_store_id = new.id;
    else
      insert into public.wynos_places (
        name_th, category, address, latitude, longitude, source, source_ref,
        verification_status, merchant_store_id, is_active
      ) values (
        left(btrim(new.name), 160),
        'restaurant',
        nullif(left(btrim(coalesce(new.address, '')), 1000), ''),
        new.latitude,
        new.longitude,
        'merchant',
        'food_store:' || new.id::text,
        'merchant_verified',
        new.id,
        new.is_published and new.admin_suspended_at is null
      )
      on conflict (merchant_store_id) do update
      set name_th = excluded.name_th,
          category = excluded.category,
          address = excluded.address,
          latitude = excluded.latitude,
          longitude = excluded.longitude,
          source = excluded.source,
          source_ref = excluded.source_ref,
          verification_status = excluded.verification_status,
          is_active = excluded.is_active;
    end if;

    update public.wynos_places wp
    set is_active = fp.is_active and new.is_published and new.admin_suspended_at is null
    from public.food_store_places fp
    where fp.store_id = new.id
      and wp.food_store_place_id = fp.id;

    return new;
  end if;

  if tg_table_name = 'food_store_places' then
    select s.is_published and s.admin_suspended_at is null
      into v_store_public
    from public.food_stores s
    where s.id = new.store_id;

    insert into public.wynos_places (
      name_th, category, address, latitude, longitude, source, source_ref,
      verification_status, food_store_place_id, is_active
    ) values (
      left(btrim(new.name), 160),
      'pickup_point',
      nullif(left(btrim(coalesce(new.detail, '')), 1000), ''),
      new.latitude,
      new.longitude,
      'merchant',
      'food_store_place:' || new.id::text,
      'merchant_verified',
      new.id,
      new.is_active and coalesce(v_store_public, false)
    )
    on conflict (food_store_place_id) do update
    set name_th = excluded.name_th,
        category = excluded.category,
        address = excluded.address,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        source = excluded.source,
        source_ref = excluded.source_ref,
        verification_status = excluded.verification_status,
        is_active = excluded.is_active;

    return new;
  end if;

  return new;
end;
$$;

revoke all on function public.wynos_sync_food_place() from public, anon, authenticated;
grant execute on function public.wynos_sync_food_place() to service_role;

drop trigger if exists wynos_sync_food_store_place on public.food_store_places;
create trigger wynos_sync_food_store_place
after insert or update of name, detail, latitude, longitude, is_active, store_id
on public.food_store_places
for each row execute function public.wynos_sync_food_place();

drop trigger if exists wynos_sync_food_store on public.food_stores;
create trigger wynos_sync_food_store
after insert or update of name, address, latitude, longitude, is_published, admin_suspended_at
on public.food_stores
for each row execute function public.wynos_sync_food_place();

insert into public.wynos_places (
  name_th, category, address, latitude, longitude, source, source_ref,
  verification_status, merchant_store_id, is_active
)
select
  left(btrim(s.name), 160),
  'restaurant',
  nullif(left(btrim(coalesce(s.address, '')), 1000), ''),
  s.latitude,
  s.longitude,
  'merchant',
  'food_store:' || s.id::text,
  'merchant_verified',
  s.id,
  s.is_published and s.admin_suspended_at is null
from public.food_stores s
where s.latitude is not null and s.longitude is not null
on conflict (merchant_store_id) do update
set name_th = excluded.name_th,
    category = excluded.category,
    address = excluded.address,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    source = excluded.source,
    source_ref = excluded.source_ref,
    verification_status = excluded.verification_status,
    is_active = excluded.is_active;

insert into public.wynos_places (
  name_th, category, address, latitude, longitude, source, source_ref,
  verification_status, food_store_place_id, is_active
)
select
  left(btrim(p.name), 160),
  'pickup_point',
  nullif(left(btrim(coalesce(p.detail, '')), 1000), ''),
  p.latitude,
  p.longitude,
  'merchant',
  'food_store_place:' || p.id::text,
  'merchant_verified',
  p.id,
  p.is_active and s.is_published and s.admin_suspended_at is null
from public.food_store_places p
join public.food_stores s on s.id = p.store_id
on conflict (food_store_place_id) do update
set name_th = excluded.name_th,
    category = excluded.category,
    address = excluded.address,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    source = excluded.source,
    source_ref = excluded.source_ref,
    verification_status = excluded.verification_status,
    is_active = excluded.is_active;

create or replace function public.wynos_search_places(
  p_query text,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns table (
  place_id text,
  name text,
  address text,
  latitude double precision,
  longitude double precision,
  category text,
  verification_status text,
  distance_km numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := left(btrim(coalesce(p_query, '')), 200);
  v_pattern text;
  v_has_location boolean := false;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if v_query = '' then
    return;
  end if;

  v_pattern := replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_');
  v_has_location := p_latitude between -90 and 90 and p_longitude between -180 and 180;

  return query
  select
    p.id,
    coalesce(nullif(p.name_th, ''), nullif(p.name_en, ''), 'สถานที่')::text,
    p.address,
    p.latitude,
    p.longitude,
    p.category,
    p.verification_status,
    case
      when v_has_location then internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude)
      else null::numeric
    end
  from public.wynos_places p
  where p.is_active
    and (
      p.name_th ilike '%' || v_pattern || '%' escape '\'
      or coalesce(p.name_en, '') ilike '%' || v_pattern || '%' escape '\'
      or coalesce(p.address, '') ilike '%' || v_pattern || '%' escape '\'
      or coalesce(p.building, '') ilike '%' || v_pattern || '%' escape '\'
    )
  order by
    (lower(p.name_th) = lower(v_query)) desc,
    (p.name_th ilike v_pattern || '%' escape '\') desc,
    (p.verification_status = 'wynos_verified') desc,
    (p.verification_status = 'merchant_verified') desc,
    case
      when v_has_location then internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude)
      else null::numeric
    end nulls last,
    p.name_th
  limit 12;
end;
$$;

revoke all on function public.wynos_search_places(text,double precision,double precision) from public, anon;
grant execute on function public.wynos_search_places(text,double precision,double precision) to authenticated;

alter table public.food_customer_addresses
  add column if not exists place_id text references public.wynos_places(id) on delete set null,
  add column if not exists place_name text,
  add column if not exists building_name text,
  add column if not exists floor text,
  add column if not exists room text,
  add column if not exists landmark text;

create index if not exists food_customer_addresses_place_idx
on public.food_customer_addresses(place_id)
where place_id is not null;

create or replace function public.food_upsert_customer_address_v2(
  p_address_id uuid,
  p_label text,
  p_recipient_name text,
  p_recipient_phone text,
  p_address text,
  p_delivery_note text default null,
  p_is_default boolean default false,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_place_id text default null,
  p_place_name text default null,
  p_building_name text default null,
  p_floor text default null,
  p_room text default null,
  p_landmark text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_place_id text := nullif(left(btrim(coalesce(p_place_id, '')), 80), '');
  v_place_name text := nullif(left(btrim(coalesce(p_place_name, '')), 160), '');
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(btrim(p_label)), 0) = 0
     or coalesce(char_length(btrim(p_recipient_name)), 0) = 0
     or coalesce(char_length(btrim(p_recipient_phone)), 0) = 0
     or coalesce(char_length(btrim(p_address)), 0) = 0 then
    raise exception 'address information is required';
  end if;

  if (p_latitude is null) <> (p_longitude is null)
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'invalid delivery location';
  end if;

  if v_place_id is not null then
    select coalesce(v_place_name, p.name_th, p.name_en)
      into v_place_name
    from public.wynos_places p
    where p.id = v_place_id and p.is_active;

    if not found then
      v_place_id := null;
    end if;
  end if;

  if p_is_default then
    update public.food_customer_addresses
    set is_default = false
    where user_id = auth.uid() and is_default;
  end if;

  if p_address_id is null then
    insert into public.food_customer_addresses (
      user_id, label, recipient_name, recipient_phone, address, delivery_note,
      is_default, latitude, longitude, place_id, place_name,
      building_name, floor, room, landmark
    ) values (
      auth.uid(),
      left(btrim(p_label), 80),
      left(btrim(p_recipient_name), 120),
      left(btrim(p_recipient_phone), 50),
      left(btrim(p_address), 800),
      nullif(left(btrim(coalesce(p_delivery_note, '')), 500), ''),
      p_is_default,
      p_latitude,
      p_longitude,
      v_place_id,
      v_place_name,
      nullif(left(btrim(coalesce(p_building_name, '')), 160), ''),
      nullif(left(btrim(coalesce(p_floor, '')), 40), ''),
      nullif(left(btrim(coalesce(p_room, '')), 40), ''),
      nullif(left(btrim(coalesce(p_landmark, '')), 240), '')
    )
    returning id into v_id;
  else
    update public.food_customer_addresses
    set label = left(btrim(p_label), 80),
        recipient_name = left(btrim(p_recipient_name), 120),
        recipient_phone = left(btrim(p_recipient_phone), 50),
        address = left(btrim(p_address), 800),
        delivery_note = nullif(left(btrim(coalesce(p_delivery_note, '')), 500), ''),
        is_default = p_is_default,
        latitude = p_latitude,
        longitude = p_longitude,
        place_id = v_place_id,
        place_name = v_place_name,
        building_name = nullif(left(btrim(coalesce(p_building_name, '')), 160), ''),
        floor = nullif(left(btrim(coalesce(p_floor, '')), 40), ''),
        room = nullif(left(btrim(coalesce(p_room, '')), 40), ''),
        landmark = nullif(left(btrim(coalesce(p_landmark, '')), 240), '')
    where id = p_address_id and user_id = auth.uid()
    returning id into v_id;

    if v_id is null then
      raise exception 'address not found';
    end if;
  end if;

  if not exists (
    select 1
    from public.food_customer_addresses
    where user_id = auth.uid() and is_default
  ) then
    update public.food_customer_addresses
    set is_default = true
    where id = v_id;
  end if;

  return v_id;
end;
$$;

revoke all on function public.food_upsert_customer_address_v2(
  uuid,text,text,text,text,text,boolean,double precision,double precision,text,text,text,text,text,text
) from public, anon;
grant execute on function public.food_upsert_customer_address_v2(
  uuid,text,text,text,text,text,boolean,double precision,double precision,text,text,text,text,text,text
) to authenticated;

create or replace function public.food_delivery_availability(
  p_store_id uuid,
  p_latitude double precision,
  p_longitude double precision
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_distance numeric;
  v_fee numeric;
  v_developer boolean := public.is_developer_account();
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select * into v_store
  from public.food_stores s
  where s.id = p_store_id;

  if not found
     or (
       not v_developer
       and (
         not public.food_public_access_enabled()
         or not v_store.is_published
         or v_store.admin_suspended_at is not null
       )
     ) then
    return jsonb_build_object(
      'can_deliver', false,
      'reason', 'store_unavailable',
      'distance_km', null,
      'delivery_fee', null,
      'delivery_radius_km', null
    );
  end if;

  begin
    select z.distance_km, z.delivery_fee
      into v_distance, v_fee
    from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;

    return jsonb_build_object(
      'can_deliver', true,
      'reason', null,
      'distance_km', v_distance,
      'delivery_fee', v_fee,
      'delivery_radius_km', case when v_store.latitude is null then null else v_store.delivery_radius_km end
    );
  exception
    when others then
      if sqlerrm = 'outside delivery area' then
        return jsonb_build_object(
          'can_deliver', false,
          'reason', 'outside_delivery_area',
          'distance_km', internal.food_distance_km(v_store.latitude, v_store.longitude, p_latitude, p_longitude),
          'delivery_fee', null,
          'delivery_radius_km', v_store.delivery_radius_km
        );
      elsif sqlerrm = 'outside service area' or sqlerrm = 'store is outside the service area' then
        return jsonb_build_object(
          'can_deliver', false,
          'reason', 'outside_service_area',
          'distance_km', null,
          'delivery_fee', null,
          'delivery_radius_km', v_store.delivery_radius_km
        );
      elsif sqlerrm = 'delivery location required' then
        return jsonb_build_object(
          'can_deliver', false,
          'reason', 'location_required',
          'distance_km', null,
          'delivery_fee', null,
          'delivery_radius_km', v_store.delivery_radius_km
        );
      else
        raise;
      end if;
  end;
end;
$$;

revoke all on function public.food_delivery_availability(uuid,double precision,double precision) from public, anon;
grant execute on function public.food_delivery_availability(uuid,double precision,double precision) to authenticated;
