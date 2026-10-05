-- WYNOS Food store pickup point + Maps store details v1
-- Additive: separate the storefront pin from the rider pickup/entrance pin.
-- Existing store latitude/longitude remains the storefront/delivery-origin pin.
-- The pickup pin is mirrored into wynos_places.entrance_latitude/longitude.
--
-- Rollback (data-preserving first):
--   drop function if exists public.wynos_place_details(text);
--   alter table public.food_stores drop constraint if exists food_stores_pickup_pair;
--   alter table public.food_stores drop constraint if exists food_stores_pickup_note_length;
--   alter table public.food_stores drop column if exists pickup_latitude;
--   alter table public.food_stores drop column if exists pickup_longitude;
--   alter table public.food_stores drop column if exists pickup_note;
-- Recreate public.wynos_sync_food_place() from the previous migration before
-- dropping columns if a full rollback is required.

alter table public.food_stores
  add column if not exists pickup_latitude double precision,
  add column if not exists pickup_longitude double precision,
  add column if not exists pickup_note text;

alter table public.food_stores
  drop constraint if exists food_stores_pickup_pair;
alter table public.food_stores
  add constraint food_stores_pickup_pair check (
    (pickup_latitude is null and pickup_longitude is null)
    or (
      pickup_latitude between -90 and 90
      and pickup_longitude between -180 and 180
    )
  );

alter table public.food_stores
  drop constraint if exists food_stores_pickup_note_length;
alter table public.food_stores
  add constraint food_stores_pickup_note_length check (
    pickup_note is null or char_length(pickup_note) <= 500
  );

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
          entrance_latitude = new.pickup_latitude,
          entrance_longitude = new.pickup_longitude,
          is_active = false
      where merchant_store_id = new.id;
    else
      insert into public.wynos_places (
        name_th, category, address, latitude, longitude,
        entrance_latitude, entrance_longitude,
        source, source_ref, verification_status, merchant_store_id, is_active
      ) values (
        left(btrim(new.name), 160),
        'restaurant',
        nullif(left(btrim(coalesce(new.address, '')), 1000), ''),
        new.latitude,
        new.longitude,
        new.pickup_latitude,
        new.pickup_longitude,
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
          entrance_latitude = excluded.entrance_latitude,
          entrance_longitude = excluded.entrance_longitude,
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

drop trigger if exists wynos_sync_food_store on public.food_stores;
create trigger wynos_sync_food_store
after insert or update of
  name, address, latitude, longitude, pickup_latitude, pickup_longitude,
  is_published, admin_suspended_at
on public.food_stores
for each row execute function public.wynos_sync_food_place();

update public.wynos_places p
set entrance_latitude = s.pickup_latitude,
    entrance_longitude = s.pickup_longitude
from public.food_stores s
where p.merchant_store_id = s.id
  and (
    p.entrance_latitude is distinct from s.pickup_latitude
    or p.entrance_longitude is distinct from s.pickup_longitude
  );

create or replace function public.wynos_place_details(
  p_place_id text
)
returns table (
  place_id text,
  entrance_latitude double precision,
  entrance_longitude double precision,
  pickup_note text,
  merchant_store_id uuid,
  store_slug text,
  store_logo_path text,
  store_cover_path text,
  is_open boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_developer boolean := coalesce(public.is_developer_account(), false);
begin
  return query
  select
    p.id,
    p.entrance_latitude,
    p.entrance_longitude,
    s.pickup_note,
    s.id,
    s.slug,
    s.logo_path,
    s.cover_path,
    s.is_open
  from public.wynos_places p
  left join public.food_store_places fsp
    on fsp.id = p.food_store_place_id
  left join public.food_stores s
    on s.id = coalesce(p.merchant_store_id, fsp.store_id)
  where p.id = p_place_id
    and (
      p.is_active
      or (
        v_developer
        and s.id is not null
        and s.admin_suspended_at is null
      )
    )
  limit 1;
end;
$$;

revoke all on function public.wynos_place_details(text) from public;
grant execute on function public.wynos_place_details(text) to anon, authenticated;
