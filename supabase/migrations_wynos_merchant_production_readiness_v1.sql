-- WYNOS Merchant production-readiness suite v1
-- Adds structured opening hours, temporary closures, prep-time estimates,
-- publish-readiness enforcement, location quality / duplicate warnings,
-- automatic "sold out today", category ordering, and merchant audit history.
-- Additive for existing stores: legacy stores without business_schedule keep
-- using the existing is_open flag until a schedule is configured.

alter table public.food_stores
  add column if not exists business_schedule jsonb not null default '{}'::jsonb,
  add column if not exists special_closed_dates date[] not null default '{}'::date[],
  add column if not exists temporary_closed_until timestamptz,
  add column if not exists temporary_closed_reason text,
  add column if not exists prep_time_min_minutes integer not null default 15,
  add column if not exists prep_time_max_minutes integer not null default 30,
  add column if not exists menu_category_order jsonb not null default '[]'::jsonb;

alter table public.food_stores
  drop constraint if exists food_stores_business_schedule_object;
alter table public.food_stores
  add constraint food_stores_business_schedule_object
  check (jsonb_typeof(business_schedule) = 'object');

alter table public.food_stores
  drop constraint if exists food_stores_menu_category_order_array;
alter table public.food_stores
  add constraint food_stores_menu_category_order_array
  check (jsonb_typeof(menu_category_order) = 'array');

alter table public.food_stores
  drop constraint if exists food_stores_prep_time_range;
alter table public.food_stores
  add constraint food_stores_prep_time_range check (
    prep_time_min_minutes between 1 and 240
    and prep_time_max_minutes between prep_time_min_minutes and 240
  );

alter table public.food_stores
  drop constraint if exists food_stores_temporary_closed_reason_length;
alter table public.food_stores
  add constraint food_stores_temporary_closed_reason_length check (
    temporary_closed_reason is null or char_length(temporary_closed_reason) <= 200
  );

alter table public.food_menu_items
  add column if not exists sold_out_until timestamptz,
  add column if not exists daily_stock_limit integer;

alter table public.food_menu_items
  drop constraint if exists food_menu_items_daily_stock_limit;
alter table public.food_menu_items
  add constraint food_menu_items_daily_stock_limit check (
    daily_stock_limit is null or daily_stock_limit between 1 and 9999
  );

create index if not exists food_menu_items_store_sort_idx
  on public.food_menu_items(store_id, sort_order, created_at);

-- Opening-hours helpers ------------------------------------------------------

create or replace function internal.food_schedule_day_key(p_isodow integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select (array['mon','tue','wed','thu','fri','sat','sun'])[greatest(1, least(7, p_isodow))];
$$;

create or replace function internal.food_slot_open(
  p_slot jsonb,
  p_local_time time
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_open time;
  v_close time;
begin
  if p_slot is null or coalesce((p_slot->>'enabled')::boolean, false) = false then
    return false;
  end if;
  begin
    v_open := (p_slot->>'open')::time;
    v_close := (p_slot->>'close')::time;
  exception when others then
    return false;
  end;
  if v_open = v_close then
    return true;
  end if;
  if v_close > v_open then
    return p_local_time >= v_open and p_local_time < v_close;
  end if;
  return p_local_time >= v_open;
end;
$$;

create or replace function internal.food_store_effectively_open(
  p_store_id uuid,
  p_at timestamptz default now()
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_local timestamp;
  v_date date;
  v_time time;
  v_dow integer;
  v_today jsonb;
  v_prev jsonb;
  v_prev_open time;
  v_prev_close time;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found or not v_store.is_open or v_store.admin_suspended_at is not null then
    return false;
  end if;

  if v_store.temporary_closed_until is not null and v_store.temporary_closed_until > p_at then
    return false;
  end if;

  v_local := p_at at time zone 'Asia/Bangkok';
  v_date := v_local::date;
  v_time := v_local::time;
  v_dow := extract(isodow from v_local)::integer;

  if v_date = any(coalesce(v_store.special_closed_dates, '{}'::date[])) then
    return false;
  end if;

  -- Legacy fallback: a store with no structured weekly schedule keeps using
  -- the manual is_open flag exactly as before.
  if v_store.business_schedule = '{}'::jsonb
     or jsonb_typeof(v_store.business_schedule->'weekly') <> 'object' then
    return true;
  end if;

  v_today := v_store.business_schedule->'weekly'->internal.food_schedule_day_key(v_dow);
  if internal.food_slot_open(v_today, v_time) then
    return true;
  end if;

  -- Previous-day overnight slot, e.g. 18:00–02:00.
  v_prev := v_store.business_schedule->'weekly'->internal.food_schedule_day_key(case when v_dow = 1 then 7 else v_dow - 1 end);
  if v_prev is not null and coalesce((v_prev->>'enabled')::boolean, false) then
    begin
      v_prev_open := (v_prev->>'open')::time;
      v_prev_close := (v_prev->>'close')::time;
      if v_prev_close < v_prev_open and v_time < v_prev_close then
        return true;
      end if;
    exception when others then
      null;
    end;
  end if;

  return false;
end;
$$;

revoke all on function internal.food_schedule_day_key(integer) from public, anon, authenticated;
revoke all on function internal.food_slot_open(jsonb,time) from public, anon, authenticated;
revoke all on function internal.food_store_effectively_open(uuid,timestamptz) from public, anon, authenticated;

create or replace function public.food_store_open_status(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_store public.food_stores%rowtype;
  v_open boolean;
begin
  select * into v_store from public.food_stores where id = p_store_id;
  if not found then return jsonb_build_object('open', false, 'reason', 'not_found'); end if;
  v_open := internal.food_store_effectively_open(p_store_id, now());
  return jsonb_build_object(
    'open', v_open,
    'manual_open', v_store.is_open,
    'temporary_closed_until', v_store.temporary_closed_until,
    'temporary_closed_reason', v_store.temporary_closed_reason
  );
end;
$$;

revoke all on function public.food_store_open_status(uuid) from public;
grant execute on function public.food_store_open_status(uuid) to anon, authenticated;

-- Publish readiness ----------------------------------------------------------

create or replace function internal.food_store_publish_readiness_json(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s public.food_stores%rowtype;
  v_menu boolean;
  v_checks jsonb;
  v_missing jsonb := '[]'::jsonb;
begin
  select * into s from public.food_stores where id = p_store_id;
  if not found then
    return jsonb_build_object('ready', false, 'checks', '{}'::jsonb, 'missing', jsonb_build_array('store'));
  end if;

  select exists(
    select 1 from public.food_menu_items m
    where m.store_id = p_store_id
  ) into v_menu;

  v_checks := jsonb_build_object(
    'name', length(btrim(coalesce(s.name,''))) > 0,
    'description', length(btrim(coalesce(s.description,''))) > 0,
    'phone', length(btrim(coalesce(s.phone,''))) > 0,
    'address', length(btrim(coalesce(s.address,''))) > 0,
    'logo', s.logo_path is not null,
    'cover', s.cover_path is not null,
    'location', s.latitude is not null and s.longitude is not null,
    'schedule', s.business_schedule <> '{}'::jsonb and jsonb_typeof(s.business_schedule->'weekly') = 'object',
    'prep_time', s.prep_time_min_minutes >= 1 and s.prep_time_max_minutes >= s.prep_time_min_minutes,
    'payment', coalesce(nullif(btrim(s.promptpay_id),''), nullif(btrim(s.bank_account_number),'')) is not null,
    'menu', v_menu
  );

  select coalesce(jsonb_agg(key order by key), '[]'::jsonb)
    into v_missing
  from jsonb_each(v_checks)
  where value <> 'true'::jsonb;

  return jsonb_build_object(
    'ready', jsonb_array_length(v_missing) = 0,
    'checks', v_checks,
    'missing', v_missing
  );
end;
$$;

revoke all on function internal.food_store_publish_readiness_json(uuid) from public, anon, authenticated;

create or replace function public.food_store_publish_readiness(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.food_has_merchant_access(p_store_id) and not public.food_is_platform_admin() then
    raise exception 'Not authorized';
  end if;
  return internal.food_store_publish_readiness_json(p_store_id);
end;
$$;

revoke all on function public.food_store_publish_readiness(uuid) from public, anon;
grant execute on function public.food_store_publish_readiness(uuid) to authenticated;

create or replace function internal.food_store_guard_publish_readiness()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ready jsonb;
begin
  if new.is_published and not old.is_published then
    v_ready := internal.food_store_publish_readiness_json(new.id);
    if coalesce((v_ready->>'ready')::boolean, false) = false then
      raise exception 'store is not ready to publish: %', v_ready->'missing';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_store_guard_publish_readiness() from public, anon, authenticated;

drop trigger if exists food_stores_guard_publish_readiness on public.food_stores;
create trigger food_stores_guard_publish_readiness
before update of is_published on public.food_stores
for each row execute function internal.food_store_guard_publish_readiness();

-- Effective order acceptance -------------------------------------------------

create or replace function internal.food_order_guard_store_schedule()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not internal.food_store_effectively_open(new.store_id, now()) then
    raise exception 'store is closed';
  end if;
  return new;
end;
$$;

revoke all on function internal.food_order_guard_store_schedule() from public, anon, authenticated;

drop trigger if exists food_orders_guard_store_schedule on public.food_orders;
create trigger food_orders_guard_store_schedule
before insert on public.food_orders
for each row execute function internal.food_order_guard_store_schedule();

create or replace function internal.food_order_item_guard_availability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $
declare
  v_item public.food_menu_items%rowtype;
  v_sold_today integer := 0;
  v_today date := (now() at time zone 'Asia/Bangkok')::date;
begin
  if new.menu_item_id is null then
    return new;
  end if;

  -- Lock the menu row so concurrent checkouts cannot both consume the final
  -- daily quantity.
  select * into v_item
  from public.food_menu_items
  where id = new.menu_item_id
  for update;

  if not found
     or not v_item.is_available
     or (v_item.sold_out_until is not null and v_item.sold_out_until > now()) then
    raise exception 'menu item is unavailable';
  end if;

  if v_item.daily_stock_limit is not null then
    select coalesce(sum(oi.quantity),0)::integer
      into v_sold_today
    from public.food_order_items oi
    join public.food_orders o on o.id = oi.order_id
    where oi.menu_item_id = new.menu_item_id
      and o.status <> 'cancelled'
      and (o.created_at at time zone 'Asia/Bangkok')::date = v_today;

    if v_sold_today + new.quantity > v_item.daily_stock_limit then
      raise exception 'menu item daily stock exceeded';
    end if;
  end if;

  return new;
end;
$;

revoke all on function internal.food_order_item_guard_availability() from public, anon, authenticated;

drop trigger if exists food_order_items_guard_availability on public.food_order_items;
create trigger food_order_items_guard_availability
before insert on public.food_order_items
for each row execute function internal.food_order_item_guard_availability();

-- Location quality / duplicate detection ------------------------------------

create or replace function public.food_store_location_quality(
  p_store_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_name text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_nearby integer := 0;
  v_duplicates integer := 0;
  v_pickup_distance numeric;
  v_warnings jsonb := '[]'::jsonb;
  v_score integer := 100;
begin
  if not public.food_has_merchant_access(p_store_id) and not public.food_is_platform_admin() then
    raise exception 'Not authorized';
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid location';
  end if;

  select
    count(*) filter (where d <= 0.03),
    count(*) filter (
      where d <= 0.08
        and lower(btrim(coalesce(s.name,''))) = lower(btrim(coalesce(p_name,'')))
    )
  into v_nearby, v_duplicates
  from (
    select s.*, internal.food_distance_km(p_latitude,p_longitude,s.latitude,s.longitude) d
    from public.food_stores s
    where s.id <> p_store_id
      and s.latitude is not null and s.longitude is not null
  ) s;

  if v_duplicates > 0 then
    v_warnings := v_warnings || jsonb_build_array('possible_duplicate');
    v_score := v_score - 45;
  elsif v_nearby > 0 then
    v_warnings := v_warnings || jsonb_build_array('very_close_to_another_store');
    v_score := v_score - 20;
  end if;

  select internal.food_distance_km(p_latitude,p_longitude,s.pickup_latitude,s.pickup_longitude)
    into v_pickup_distance
  from public.food_stores s
  where s.id = p_store_id
    and s.pickup_latitude is not null and s.pickup_longitude is not null;

  if v_pickup_distance is not null and v_pickup_distance > 2 then
    v_warnings := v_warnings || jsonb_build_array('pickup_far_from_store');
    v_score := v_score - 20;
  end if;

  return jsonb_build_object(
    'score', greatest(v_score, 0),
    'nearby_store_count', v_nearby,
    'possible_duplicate_count', v_duplicates,
    'pickup_distance_km', v_pickup_distance,
    'warnings', v_warnings
  );
end;
$$;

revoke all on function public.food_store_location_quality(uuid,double precision,double precision,text) from public, anon;
grant execute on function public.food_store_location_quality(uuid,double precision,double precision,text) to authenticated;

-- Audit history --------------------------------------------------------------

do $$
declare
  v_def text;
  v_types text[];
begin
  select pg_get_constraintdef(c.oid) into v_def
  from pg_constraint c
  where c.conname = 'audit_log_event_type_check'
    and c.conrelid = 'public.audit_log'::regclass;

  select coalesce(array_agg(distinct t), '{}') into v_types
  from regexp_matches(coalesce(v_def, ''), '''([^'']*)''', 'g') as m,
       unnest(string_to_array(btrim(m[1], '{}'), ',')) as raw,
       btrim(raw, ' "') as t
  where t ~ '^[a-z0-9_]+$';

  select array_agg(distinct t order by t) into v_types
  from unnest(v_types || array[
    'merchant_store_updated',
    'merchant_store_published',
    'merchant_store_unpublished',
    'merchant_menu_created',
    'merchant_menu_updated',
    'merchant_menu_deleted',
    'merchant_menu_reordered'
  ]) as t;

  alter table public.audit_log drop constraint if exists audit_log_event_type_check;
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type = any (%L::text[]))',
    v_types
  );
end;
$$;

create or replace function internal.food_store_audit_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fields text[] := '{}'::text[];
  v_event text := 'merchant_store_updated';
begin
  if new.name is distinct from old.name then v_fields := array_append(v_fields,'name'); end if;
  if new.description is distinct from old.description then v_fields := array_append(v_fields,'description'); end if;
  if new.phone is distinct from old.phone then v_fields := array_append(v_fields,'phone'); end if;
  if new.address is distinct from old.address then v_fields := array_append(v_fields,'address'); end if;
  if new.logo_path is distinct from old.logo_path then v_fields := array_append(v_fields,'logo'); end if;
  if new.cover_path is distinct from old.cover_path then v_fields := array_append(v_fields,'cover'); end if;
  if new.latitude is distinct from old.latitude or new.longitude is distinct from old.longitude then v_fields := array_append(v_fields,'location'); end if;
  if new.pickup_latitude is distinct from old.pickup_latitude or new.pickup_longitude is distinct from old.pickup_longitude then v_fields := array_append(v_fields,'pickup_location'); end if;
  if new.business_schedule is distinct from old.business_schedule or new.special_closed_dates is distinct from old.special_closed_dates then v_fields := array_append(v_fields,'schedule'); end if;
  if new.temporary_closed_until is distinct from old.temporary_closed_until then v_fields := array_append(v_fields,'temporary_close'); end if;
  if new.prep_time_min_minutes is distinct from old.prep_time_min_minutes or new.prep_time_max_minutes is distinct from old.prep_time_max_minutes then v_fields := array_append(v_fields,'prep_time'); end if;
  if new.delivery_area is distinct from old.delivery_area
     or new.delivery_fee is distinct from old.delivery_fee
     or new.minimum_order is distinct from old.minimum_order
     or new.delivery_radius_km is distinct from old.delivery_radius_km
     or new.delivery_base_km is distinct from old.delivery_base_km
     or new.delivery_fee_per_km is distinct from old.delivery_fee_per_km then
    v_fields := array_append(v_fields,'delivery');
  end if;
  if new.promptpay_name is distinct from old.promptpay_name
     or new.promptpay_id is distinct from old.promptpay_id
     or new.bank_name is distinct from old.bank_name
     or new.bank_account_name is distinct from old.bank_account_name
     or new.bank_account_number is distinct from old.bank_account_number
     or new.payment_qr_path is distinct from old.payment_qr_path then
    v_fields := array_append(v_fields,'payment');
  end if;
  if new.menu_category_order is distinct from old.menu_category_order then v_fields := array_append(v_fields,'category_order'); end if;
  if new.is_open is distinct from old.is_open then v_fields := array_append(v_fields,'is_open'); end if;

  if new.is_published is distinct from old.is_published then
    v_event := case when new.is_published then 'merchant_store_published' else 'merchant_store_unpublished' end;
    v_fields := array_append(v_fields,'is_published');
  end if;

  if cardinality(v_fields) > 0 then
    perform internal.log_audit_event(
      (select auth.uid()),
      v_event,
      new.id,
      jsonb_build_object('fields',to_jsonb(v_fields))
    );
  end if;
  return new;
end;
$$;

revoke all on function internal.food_store_audit_changes() from public, anon, authenticated;

drop trigger if exists food_stores_audit_changes on public.food_stores;
create trigger food_stores_audit_changes
after update on public.food_stores
for each row execute function internal.food_store_audit_changes();

create or replace function internal.food_menu_audit_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_store_id uuid;
  v_event text;
  v_item_id uuid;
  v_name text;
begin
  v_store_id := coalesce(new.store_id, old.store_id);
  v_item_id := coalesce(new.id, old.id);
  v_name := coalesce(new.name, old.name);
  v_event := case
    when tg_op = 'INSERT' then 'merchant_menu_created'
    when tg_op = 'DELETE' then 'merchant_menu_deleted'
    when new.sort_order is distinct from old.sort_order then 'merchant_menu_reordered'
    else 'merchant_menu_updated'
  end;
  perform internal.log_audit_event(
    (select auth.uid()),
    v_event,
    v_store_id,
    jsonb_build_object('menu_item_id',v_item_id,'menu_name',v_name)
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$;

revoke all on function internal.food_menu_audit_changes() from public, anon, authenticated;

drop trigger if exists food_menu_items_audit_changes on public.food_menu_items;
create trigger food_menu_items_audit_changes
after insert or update or delete on public.food_menu_items
for each row execute function internal.food_menu_audit_changes();

create or replace function public.merchant_store_audit_history(
  p_store_id uuid,
  p_limit integer default 50
)
returns table(
  id uuid,
  actor_id uuid,
  actor_username text,
  event_type text,
  detail jsonb,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.food_has_merchant_access(p_store_id) and not public.food_is_platform_admin() then
    raise exception 'Not authorized';
  end if;
  return query
  select a.id,a.actor_id,a.actor_username_snapshot,a.event_type,a.detail,a.created_at
  from public.audit_log a
  where a.target_id = p_store_id
    and a.event_type like 'merchant_%'
  order by a.created_at desc
  limit greatest(1, least(coalesce(p_limit,50),100));
end;
$$;

revoke all on function public.merchant_store_audit_history(uuid,integer) from public, anon;
grant execute on function public.merchant_store_audit_history(uuid,integer) to authenticated;
