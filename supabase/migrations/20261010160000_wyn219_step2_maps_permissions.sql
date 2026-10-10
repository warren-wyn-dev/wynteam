-- WYN-219 Phase 2, step 2 (Maps): move WYNOS Maps admin checks from
-- profiles.platform_role to internal.has_admin_permission('maps', ...).
--
-- Generated from the production definitions dumped by
-- wyn219-dump-admin-check-definitions.yml (run 38059388028, 2026-10-10).
-- Each function body is the production definition verbatim; only its single
-- role-check line changes:
--   staff check (admin or moderator) -> maps:view
--   admin check                      -> maps:edit
-- Storage policies on place-photos keep the owner branch; only the admin
-- branch changes.
--
-- Effect (Founder decisions 2026-10-10): the super admin keeps full access;
-- other platform admins and moderators lose Maps admin access until the super
-- admin grants maps:view or maps:edit on the Team Permissions page.
--
-- Requires: 20261010150000_wyn219_admin_permissions_foundation.sql applied.
-- Test: supabase/tests/wyn_219_step2_maps_test.sh
-- ROLLBACK: supabase/rollbacks/20261010160000_wyn219_step2_maps_permissions_rollback.sql

-- public.admin_wynos_places(p_query text, p_category text, p_status text, p_limit integer): staff -> maps:view
CREATE OR REPLACE FUNCTION public.admin_wynos_places(p_query text DEFAULT NULL::text, p_category text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 250)
 RETURNS TABLE(id text, name_th text, name_en text, category text, address text, building text, latitude double precision, longitude double precision, entrance_latitude double precision, entrance_longitude double precision, source text, source_ref text, verification_status text, merchant_store_id uuid, food_store_place_id uuid, is_active boolean, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_query text := nullif(left(btrim(coalesce(p_query, '')), 200), '');
  v_category text := nullif(btrim(coalesce(p_category, '')), '');
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 250), 1), 500);
begin
  if not internal.has_admin_permission('maps', 'view') then
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
$function$;

-- public.admin_wynos_place_for_store(p_store_id uuid): staff -> maps:view
CREATE OR REPLACE FUNCTION public.admin_wynos_place_for_store(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_place public.wynos_places%rowtype;
begin
  if not internal.has_admin_permission('maps', 'view') then
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
$function$;

-- public.admin_wynos_place_photos(p_status text, p_limit integer): staff -> maps:view
CREATE OR REPLACE FUNCTION public.admin_wynos_place_photos(p_status text DEFAULT 'pending'::text, p_limit integer DEFAULT 200)
 RETURNS TABLE(id uuid, place_id text, place_name text, user_id uuid, storage_path text, width integer, height integer, status text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if not internal.has_admin_permission('maps', 'view') then
    raise exception 'Not authorized';
  end if;

  return query
  select ph.id, ph.place_id, p.name_th, ph.user_id, ph.storage_path, ph.width, ph.height, ph.status, ph.created_at
  from public.wynos_place_photos ph
  join public.wynos_places p on p.id = ph.place_id
  where v_status is null or ph.status = v_status
  order by ph.created_at asc
  limit v_limit;
end;
$function$;

-- public.admin_wynos_place_suggestions(p_status text, p_limit integer): staff -> maps:view
CREATE OR REPLACE FUNCTION public.admin_wynos_place_suggestions(p_status text DEFAULT 'pending'::text, p_limit integer DEFAULT 200)
 RETURNS TABLE(id uuid, user_id uuid, name text, category text, address text, note text, latitude double precision, longitude double precision, status text, place_id text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if not internal.has_admin_permission('maps', 'view') then
    raise exception 'Not authorized';
  end if;

  return query
  select
    s.id, s.user_id, s.name, s.category, s.address, s.note,
    s.latitude, s.longitude, s.status, s.place_id, s.created_at
  from public.wynos_place_suggestions s
  where v_status is null or s.status = v_status
  order by
    case when s.status = 'pending' then 0 else 1 end,
    s.created_at desc
  limit v_limit;
end;
$function$;

-- public.admin_upsert_wynos_place(p_place_id text, p_name_th text, p_name_en text, p_category text, p_address text, p_building text, p_latitude double precision, p_longitude double precision, p_entrance_latitude double precision, p_entrance_longitude double precision, p_source text, p_source_ref text, p_verification_status text, p_is_active boolean): admin -> maps:edit
CREATE OR REPLACE FUNCTION public.admin_upsert_wynos_place(p_place_id text, p_name_th text, p_name_en text DEFAULT NULL::text, p_category text DEFAULT 'place'::text, p_address text DEFAULT NULL::text, p_building text DEFAULT NULL::text, p_latitude double precision DEFAULT NULL::double precision, p_longitude double precision DEFAULT NULL::double precision, p_entrance_latitude double precision DEFAULT NULL::double precision, p_entrance_longitude double precision DEFAULT NULL::double precision, p_source text DEFAULT 'wynos'::text, p_source_ref text DEFAULT NULL::text, p_verification_status text DEFAULT 'unverified'::text, p_is_active boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_id text := nullif(btrim(coalesce(p_place_id, '')), '');
  v_name_th text := left(btrim(coalesce(p_name_th, '')), 160);
  v_name_en text := nullif(left(btrim(coalesce(p_name_en, '')), 160), '');
  v_address text := nullif(left(btrim(coalesce(p_address, '')), 1000), '');
  v_building text := nullif(left(btrim(coalesce(p_building, '')), 200), '');
  v_source_ref text := nullif(left(btrim(coalesce(p_source_ref, '')), 240), '');
begin
  if not internal.has_admin_permission('maps', 'edit') then
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
$function$;

-- public.admin_set_wynos_place_active(p_place_id text, p_active boolean): admin -> maps:edit
CREATE OR REPLACE FUNCTION public.admin_set_wynos_place_active(p_place_id text, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_name text;
begin
  if not internal.has_admin_permission('maps', 'edit') then
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
$function$;

-- public.admin_import_wynos_places(p_places jsonb): admin -> maps:edit
CREATE OR REPLACE FUNCTION public.admin_import_wynos_places(p_places jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if not internal.has_admin_permission('maps', 'edit') then
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
$function$;

-- public.admin_review_wynos_place_photo(p_photo_id uuid, p_decision text): admin -> maps:edit
CREATE OR REPLACE FUNCTION public.admin_review_wynos_place_photo(p_photo_id uuid, p_decision text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_decision text := lower(btrim(coalesce(p_decision, '')));
  v_status text;
begin
  if not internal.has_admin_permission('maps', 'edit') then
    raise exception 'Only admins can review place photos';
  end if;
  if v_decision not in ('approve', 'reject') then
    raise exception 'invalid review decision';
  end if;

  update public.wynos_place_photos ph
  set status = case v_decision when 'approve' then 'approved' else 'rejected' end,
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where ph.id = p_photo_id
  returning ph.status into v_status;

  if v_status is null then
    raise exception 'photo not found';
  end if;
  return v_status;
end;
$function$;

-- public.admin_review_wynos_place_suggestion(p_suggestion_id uuid, p_decision text): admin -> maps:edit
CREATE OR REPLACE FUNCTION public.admin_review_wynos_place_suggestion(p_suggestion_id uuid, p_decision text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_admin uuid := auth.uid();
  v_suggestion public.wynos_place_suggestions%rowtype;
  v_place_id text;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
begin
  if not internal.has_admin_permission('maps', 'edit') then
    raise exception 'Only admins can review WYNOS Place suggestions';
  end if;
  if v_decision not in ('approve','reject') then
    raise exception 'invalid review decision';
  end if;

  select * into v_suggestion
  from public.wynos_place_suggestions
  where id = p_suggestion_id
  for update;

  if not found then
    raise exception 'suggestion not found';
  end if;
  if v_suggestion.status <> 'pending' then
    raise exception 'suggestion already reviewed';
  end if;

  if v_decision = 'approve' then
    insert into public.wynos_places(
      name_th, category, address, latitude, longitude,
      source, source_ref, verification_status, is_active
    ) values (
      v_suggestion.name,
      v_suggestion.category,
      v_suggestion.address,
      v_suggestion.latitude,
      v_suggestion.longitude,
      'user_report',
      'suggestion:' || v_suggestion.id::text,
      'unverified',
      true
    )
    on conflict (source, source_ref) where source_ref is not null do update
    set name_th = excluded.name_th,
        category = excluded.category,
        address = excluded.address,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        is_active = true,
        updated_at = now()
    returning id into v_place_id;

    update public.wynos_place_suggestions
    set status = 'approved',
        reviewed_by = v_admin,
        reviewed_at = now(),
        place_id = v_place_id
    where id = v_suggestion.id;

    perform internal.log_audit_event(
      v_admin,
      'admin_wynos_place_saved',
      null,
      jsonb_build_object(
        'place_id', v_place_id,
        'suggestion_id', v_suggestion.id,
        'source', 'user_report'
      )
    );
  else
    update public.wynos_place_suggestions
    set status = 'rejected',
        reviewed_by = v_admin,
        reviewed_at = now()
    where id = v_suggestion.id;
  end if;

  return v_place_id;
end;
$function$;

-- policy Place photos readable when approved on storage.objects
drop policy if exists "Place photos readable when approved" on storage.objects;
create policy "Place photos readable when approved"
  on storage.objects
  for select
  to authenticated
  using (((bucket_id = 'place-photos'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR internal.has_admin_permission('maps'::text, 'view'::text) OR internal.wynos_place_photo_is_approved(name))));

-- policy Place photos delete own or admin on storage.objects
drop policy if exists "Place photos delete own or admin" on storage.objects;
create policy "Place photos delete own or admin"
  on storage.objects
  for delete
  to authenticated
  using (((bucket_id = 'place-photos'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR internal.has_admin_permission('maps'::text, 'edit'::text))));
