-- WYNOS Food structured customer addresses v1
-- Adds normalized Thai address fields while retaining the existing full address
-- column for backwards compatibility and order snapshots.

alter table public.food_customer_addresses
  add column if not exists address_line1 text,
  add column if not exists moo text,
  add column if not exists soi text,
  add column if not exists road text,
  add column if not exists subdistrict text,
  add column if not exists district text,
  add column if not exists province text,
  add column if not exists postal_code text;

update public.food_customer_addresses
set address_line1 = address
where address_line1 is null and nullif(btrim(address), '') is not null;

create or replace function public.food_upsert_customer_address_v3(
  p_address_id uuid,
  p_label text,
  p_recipient_name text,
  p_recipient_phone text,
  p_address_line1 text,
  p_moo text default null,
  p_soi text default null,
  p_road text default null,
  p_subdistrict text default null,
  p_district text default null,
  p_province text default null,
  p_postal_code text default null,
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
  v_line1 text := nullif(left(btrim(coalesce(p_address_line1, '')), 240), '');
  v_moo text := nullif(left(btrim(coalesce(p_moo, '')), 40), '');
  v_soi text := nullif(left(btrim(coalesce(p_soi, '')), 120), '');
  v_road text := nullif(left(btrim(coalesce(p_road, '')), 120), '');
  v_subdistrict text := nullif(left(btrim(coalesce(p_subdistrict, '')), 120), '');
  v_district text := nullif(left(btrim(coalesce(p_district, '')), 120), '');
  v_province text := nullif(left(btrim(coalesce(p_province, '')), 120), '');
  v_postal text := nullif(left(btrim(coalesce(p_postal_code, '')), 5), '');
  v_bangkok boolean;
  v_address text;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if coalesce(char_length(btrim(p_label)), 0) = 0
     or coalesce(char_length(btrim(p_recipient_name)), 0) = 0
     or coalesce(char_length(btrim(p_recipient_phone)), 0) = 0
     or v_line1 is null
     or v_subdistrict is null
     or v_district is null
     or v_province is null
     or v_postal is null then
    raise exception 'structured address information is required';
  end if;

  if v_postal !~ '^[0-9]{5}$' then
    raise exception 'invalid postal code';
  end if;

  if (p_latitude is null) <> (p_longitude is null)
     or p_latitude not between -90 and 90
     or p_longitude not between -180 and 180 then
    raise exception 'invalid delivery location';
  end if;

  if p_latitude is null or p_longitude is null then
    raise exception 'delivery location required';
  end if;

  v_bangkok := v_province in ('กรุงเทพมหานคร', 'กรุงเทพฯ');
  v_address := concat_ws(' ',
    v_line1,
    case when v_moo is not null then 'หมู่ ' || v_moo end,
    case when v_soi is not null then 'ซอย ' || v_soi end,
    case when v_road is not null then 'ถนน ' || v_road end,
    case when v_subdistrict is not null then (case when v_bangkok then 'แขวง ' else 'ตำบล ' end) || v_subdistrict end,
    case when v_district is not null then (case when v_bangkok then 'เขต ' else 'อำเภอ ' end) || v_district end,
    case when v_province is not null then 'จังหวัด ' || v_province end,
    v_postal
  );

  if v_place_id is not null then
    select coalesce(v_place_name, p.name_th, p.name_en)
      into v_place_name
    from public.wynos_places p
    where p.id = v_place_id and p.is_active;
    if not found then v_place_id := null; end if;
  end if;

  if p_is_default then
    update public.food_customer_addresses
    set is_default = false
    where user_id = auth.uid() and is_default;
  end if;

  if p_address_id is null then
    insert into public.food_customer_addresses (
      user_id, label, recipient_name, recipient_phone, address, address_line1,
      moo, soi, road, subdistrict, district, province, postal_code,
      delivery_note, is_default, latitude, longitude, place_id, place_name,
      building_name, floor, room, landmark
    ) values (
      auth.uid(),
      left(btrim(p_label), 80),
      left(btrim(p_recipient_name), 120),
      left(btrim(p_recipient_phone), 50),
      left(v_address, 800),
      v_line1, v_moo, v_soi, v_road, v_subdistrict, v_district, v_province, v_postal,
      nullif(left(btrim(coalesce(p_delivery_note, '')), 500), ''),
      p_is_default,
      p_latitude, p_longitude, v_place_id, v_place_name,
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
        address = left(v_address, 800),
        address_line1 = v_line1,
        moo = v_moo,
        soi = v_soi,
        road = v_road,
        subdistrict = v_subdistrict,
        district = v_district,
        province = v_province,
        postal_code = v_postal,
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

    if v_id is null then raise exception 'address not found'; end if;
  end if;

  if not exists (
    select 1 from public.food_customer_addresses
    where user_id = auth.uid() and is_default
  ) then
    update public.food_customer_addresses set is_default = true where id = v_id;
  end if;

  return v_id;
end;
$$;

revoke all on function public.food_upsert_customer_address_v3(
  uuid,text,text,text,text,text,text,text,text,text,text,text,text,boolean,
  double precision,double precision,text,text,text,text,text,text
) from public, anon;

grant execute on function public.food_upsert_customer_address_v3(
  uuid,text,text,text,text,text,text,text,text,text,text,text,text,boolean,
  double precision,double precision,text,text,text,text,text,text
) to authenticated;
