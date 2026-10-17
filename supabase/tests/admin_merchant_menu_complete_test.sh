#!/usr/bin/env bash
# Disposable synthetic PostgreSQL contract tests; no application credentials needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_merchant_menu_complete_test_$$"
MIGRATION="20261014073941_admin_merchant_menu_complete"
"$PSQL" -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
TMP_DIR="$(mktemp -d)"
cleanup() {
  "$PSQL" -q -X -d postgres -c "drop database if exists $DB with (force)" >/dev/null
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT
run() { "$PSQL" -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth;
create schema internal;
create schema storage;
create schema test;
create table public.profiles(id uuid primary key);
insert into public.profiles(id) select ('00000000-0000-0000-0000-0000000000a'||i)::uuid
  from generate_series(1,7) i;
create function auth.uid() returns uuid language sql stable as $$
  select case when current_setting('role', true) = 'authenticated'
    then nullif(current_setting('test.uid', true), '')::uuid else null end
$$;
create table public.admin_permissions(user_id uuid primary key, level text not null);
create function internal.has_admin_permission(p_system text, p_level text)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_system = 'merchant' and exists (
    select 1 from public.admin_permissions a where a.user_id = auth.uid()
      and (a.level = 'edit' or p_level = 'view'))
$$;
create table public.food_stores(
  id uuid primary key, name text not null,
  menu_category_order jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
create table public.food_menu_items(
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id),
  name text not null, category text not null, description text,
  price numeric(10,2) not null, is_available boolean not null default true,
  daily_stock_limit integer, sold_out_until timestamptz,
  image_path text, options jsonb not null default '[]'::jsonb,
  internal_notes text not null default 'private-fixture-sentinel',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.food_orders(
  id uuid primary key default gen_random_uuid(), status text not null default 'pending',
  created_at timestamptz not null default now()
);
create table public.food_order_items(
  id uuid primary key default gen_random_uuid(), menu_item_id uuid references public.food_menu_items(id),
  order_id uuid references public.food_orders(id), quantity integer not null default 1,
  item_name text, unit_price numeric(10,2), selected_options jsonb, item_note text,
  snapshot jsonb not null
);
create function public.food_touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end;
$$;
create trigger food_stores_touch_updated_at before update on public.food_stores
  for each row execute function public.food_touch_updated_at();
create trigger food_menu_items_touch_updated_at before update on public.food_menu_items
  for each row execute function public.food_touch_updated_at();
create table public.audit_log(
  id bigint generated always as identity primary key,
  actor_id uuid, event_type text, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check(event_type = any(array[
    'merchant_menu_created','merchant_menu_updated','merchant_menu_deleted','merchant_store_updated']))
);
create function internal.log_audit_event(
  p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb
) returns void language sql as $$
  insert into public.audit_log(actor_id, event_type, target_id, detail)
  values(p_actor_id, p_event_type, p_target_id, p_detail)
$$;
create table storage.objects(bucket_id text not null, name text not null, metadata jsonb);
insert into public.admin_permissions values
  ('00000000-0000-0000-0000-0000000000a1', 'view'),
  ('00000000-0000-0000-0000-0000000000a2', 'edit'),
  ('00000000-0000-0000-0000-0000000000a6', 'edit'),
  ('00000000-0000-0000-0000-0000000000a7', 'edit');
insert into public.food_stores(id, name, menu_category_order) values
  ('00000000-0000-0000-0000-0000000000b1', 'Test Shop', '["Main","Soups"]'),
  ('00000000-0000-0000-0000-0000000000b2', 'Empty Shop', '[]'),
  ('00000000-0000-0000-0000-0000000000b3', 'Other Shop', '["Other"]');
insert into public.food_menu_items(id, store_id, name, category, price) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000b1', 'Rice', 'Main', 55),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'Soup', 'Soups', 40),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000b3', 'Other', 'Other', 80);
insert into public.food_orders(id) values('00000000-0000-0000-0000-0000000000e1');
insert into public.food_order_items(id, menu_item_id, order_id, quantity, item_name, unit_price, selected_options, snapshot) values(
  '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
  '00000000-0000-0000-0000-0000000000e1', 2, 'Rice', 65, '[{"name":"Egg","price":10}]',
  '{"name":"Rice","price":55,"quantity":2,"options":[{"name":"Egg","price":10}]}'
);
insert into storage.objects values
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000001.png', '{"mimetype":"image/png","size":2048}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b3/menu/10000000-0000-0000-0000-000000000001.png', '{"mimetype":"image/png","size":2048}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000002.png', '{"mimetype":"text/html","size":2048}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000003.png', '{"mimetype":"image/png","size":8388609}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000004.png', '{"mimetype":"image/png","size":0}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000005.png', '{"mimetype":"image/png","size":"2048"}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000006.png', '{"mimetype":"image/jpeg","size":2048}'),
  ('food-public', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000007.png', '{"mimetype":"image/png","size":1.5}'),
  ('different-bucket', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000008.png', '{"mimetype":"image/png","size":2048}');
create function test.assert(p_ok boolean, p_label text) returns void language plpgsql as $$
begin
  if p_ok is distinct from true then raise exception 'FAIL: %', p_label; end if;
end;
$$;
create function test.expect_error(p_sql text, p_fragment text, p_label text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if p_fragment <> '' and position(lower(p_fragment) in lower(sqlerrm)) = 0 then
      raise exception 'FAIL: %, unexpected error: %', p_label, sqlerrm;
    end if;
    return;
  end;
  raise exception 'FAIL: %, expected rejection', p_label;
end;
$$;
grant usage on schema auth, internal, test to authenticated, anon;
revoke all on function internal.has_admin_permission(text,text) from public;
grant execute on function internal.has_admin_permission(text,text) to authenticated;
grant execute on all functions in schema test to authenticated, anon;
SQL

run >/dev/null < "$ROOT/supabase/migrations/20261013183000_admin_merchant_menu_live.sql"

# Exercise the maintained consumer resolver and stock guard verbatim. This does
# not substitute for the full food_quote_order/food_create_order permission flow.
extract_function() {
  awk -v marker="$2" '
    index($0, marker) == 1 { copying = 1 }
    copying { print }
    copying && $0 == "$$;" { found = 1; exit }
    END { if (!found) exit 1 }
  ' "$ROOT/supabase/$1" | run >/dev/null
}
extract_function migrations_wynos_food_order_options_v1.sql 'create or replace function internal.food_resolve_menu_options('
extract_function migrations_wynos_merchant_production_readiness_v1.sql 'create or replace function internal.food_order_item_guard_availability()'
run >/dev/null <<'SQL'
revoke all on function internal.food_resolve_menu_options(jsonb,jsonb) from public, anon, authenticated;
revoke all on function internal.food_order_item_guard_availability() from public, anon, authenticated;
create trigger food_order_items_guard_availability before insert on public.food_order_items
  for each row execute function internal.food_order_item_guard_availability();
SQL
run >/dev/null < "$ROOT/supabase/migrations/$MIGRATION.sql"
run >/dev/null < "$ROOT/supabase/migrations/$MIGRATION.sql"

run >/dev/null <<'SQL'
create function test.item(p_id uuid) returns jsonb language sql stable as $$
  select value from jsonb_array_elements(public.admin_merchant_menu_catalog(null)->'items')
  where value->>'id' = p_id::text
$$;
create function test.store(p_id uuid) returns jsonb language sql stable as $$
  select value from jsonb_array_elements(public.admin_merchant_menu_catalog(null)->'stores')
  where value->>'id' = p_id::text
$$;
create function test.versions(p_store_id uuid) returns jsonb language sql stable as $$
  select coalesce(jsonb_object_agg(value->>'id', value->>'updated_at'), '{}'::jsonb)
  from jsonb_array_elements(public.admin_merchant_menu_catalog(p_store_id)->'items')
$$;
-- A fixture bridge invokes the real private consumer functions without giving
-- authenticated direct table access or claiming to test the full checkout RPC.
create function test.resolve(p_item_id uuid, p_selected jsonb) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('name', m.name, 'base_price', m.price,
    'selected_options', r.options, 'surcharge', r.surcharge, 'unit_price', m.price + r.surcharge)
  from public.food_menu_items m
  cross join lateral internal.food_resolve_menu_options(m.options, p_selected) r
  where m.id = p_item_id
$$;
create function test.checkout(p_item_id uuid, p_quantity integer, p_selected jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_order_id uuid; v_priced jsonb;
begin
  v_priced := test.resolve(p_item_id, p_selected);
  insert into public.food_orders default values returning id into v_order_id;
  insert into public.food_order_items(order_id, menu_item_id, item_name, unit_price, quantity, selected_options, snapshot)
  values(v_order_id, p_item_id, v_priced->>'name', (v_priced->>'unit_price')::numeric,
    p_quantity, v_priced->'selected_options', v_priced || jsonb_build_object('quantity', p_quantity));
  return v_priced;
end;
$$;
create function test.race_save(p_version timestamptz, p_name text) returns text language plpgsql as $$
begin
  perform public.admin_save_merchant_menu_item('00000000-0000-0000-0000-0000000000c3',
    '00000000-0000-0000-0000-0000000000b3', p_version,
    jsonb_build_object('name', p_name, 'category', 'Other', 'description', null,
      'price', 80, 'is_available', true, 'daily_stock_limit', 1,
      'sold_out_until', null, 'image_path', null, 'options', '[]'::jsonb), 'fixture concurrent stock save');
  -- Hold the successful transaction's locks so the other session contends.
  perform pg_sleep(0.25);
  return 'saved';
exception when others then
  if position('changed' in lower(sqlerrm)) > 0 then return 'conflict'; end if;
  raise;
end;
$$;
create function test.race_checkout() returns text language plpgsql as $$
begin
  perform test.checkout('00000000-0000-0000-0000-0000000000c3', 1, '[]');
  perform pg_sleep(0.25);
  return 'purchased';
exception when others then
  if position('stock exceeded' in lower(sqlerrm)) > 0 then return 'stock-conflict'; end if;
  raise;
end;
$$;
create function test.race_categories(p_version timestamptz, p_items jsonb) returns text language plpgsql as $$
begin
  perform public.admin_save_merchant_menu_categories('00000000-0000-0000-0000-0000000000b1',
    p_version, p_items, '["Main","Bowls"]', '{}', 'fixture merchant category race');
  return 'saved';
exception when others then
  if position('changed' in lower(sqlerrm)) > 0 then return 'conflict'; end if;
  raise;
end;
$$;
grant execute on all functions in schema test to authenticated, anon;

set role anon;
select test.expect_error('select public.admin_merchant_menu_catalog(null)', 'permission denied', 'anon catalog grant');
select test.expect_error('select public.admin_save_merchant_menu_item(null,null,null,''{}'',''fixture change'')', 'permission denied', 'anon save grant');
select test.expect_error('select public.admin_set_merchant_menu_item_archived(null,null,true,''fixture change'')', 'permission denied', 'anon archive grant');
select test.expect_error('select public.admin_save_merchant_menu_categories(null,null,''{}'',''[]'',''{}'',''fixture change'')', 'permission denied', 'anon category grant');
reset role;

set role authenticated;
select set_config('test.uid', '', false);
select test.expect_error('select public.admin_merchant_menu_catalog(null)', 'Not authorized', 'signed-out authenticated role');
select set_config('test.uid', '00000000-0000-0000-0000-0000000000a3', false);
select test.expect_error('select public.admin_merchant_menu_catalog(null)', 'Not authorized', 'outsider catalog');
select test.expect_error('select public.admin_save_merchant_menu_item(null,null,null,''{}'',''fixture change'')', 'Not authorized', 'outsider save');
select test.expect_error('select public.admin_set_merchant_menu_item_archived(null,null,true,''fixture change'')', 'Not authorized', 'outsider archive');
select test.expect_error('select public.admin_save_merchant_menu_categories(null,null,''{}'',''[]'',''{}'',''fixture change'')', 'Not authorized', 'outsider categories');
select set_config('test.uid', '00000000-0000-0000-0000-0000000000a1', false);
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog(null)->'stores') = 3, 'catalog includes every store');
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog(null)->'items') = 3, 'catalog includes menu items');
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog('00000000-0000-0000-0000-0000000000b2')->'stores') = 1
  and public.admin_merchant_menu_catalog('00000000-0000-0000-0000-0000000000b2')->'items' = '[]'::jsonb, 'empty store is selectable');
select test.assert(test.store('00000000-0000-0000-0000-0000000000b1') ?& array['id','name','menu_category_order','updated_at'], 'store contract');
select test.assert(test.item('00000000-0000-0000-0000-0000000000c1') ?& array[
  'id','store_id','store_name','name','category','description','price','is_available',
  'daily_stock_limit','sold_out_until','image_path','options','sort_order','created_at','updated_at','archived_at'], 'full item contract');
select test.assert(not (test.item('00000000-0000-0000-0000-0000000000c1') ? 'internal_notes'), 'catalog whitelists item fields');
select test.expect_error('select public.admin_save_merchant_menu_item(null,null,null,''{}'',''fixture change'')', 'Not authorized', 'viewer save');
select test.expect_error('select public.admin_set_merchant_menu_item_archived(null,null,true,''fixture change'')', 'Not authorized', 'viewer archive');
select test.expect_error('select public.admin_save_merchant_menu_categories(null,null,''{}'',''[]'',''{}'',''fixture change'')', 'Not authorized', 'viewer categories');
select test.expect_error('select * from public.food_menu_items', 'permission denied', 'authenticated has no direct table grant');

select set_config('test.uid', '00000000-0000-0000-0000-0000000000a2', false);
select set_config('test.values', '{"name":"Rice Bowl","category":"Main","description":"Fresh rice","price":59.25,"is_available":true,"daily_stock_limit":20,"sold_out_until":null,"image_path":null,"options":[]}', false);
do $$
declare v_created jsonb;
begin
  v_created := public.admin_save_merchant_menu_item(null, '00000000-0000-0000-0000-0000000000b2', null,
    current_setting('test.values')::jsonb, 'fixture create empty store');
  perform test.assert(v_created->>'store_id' = '00000000-0000-0000-0000-0000000000b2'
    and v_created->>'store_name' = 'Empty Shop' and v_created->>'name' = 'Rice Bowl'
    and v_created->'archived_at' = 'null'::jsonb, 'create full row in empty store');
  perform set_config('test.created_item', v_created->>'id', false);
end;
$$;
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog('00000000-0000-0000-0000-0000000000b2')->'items') = 1, 'created menu persisted');

do $$
declare
  v_bad jsonb;
  v_values jsonb := current_setting('test.values')::jsonb;
  v_groups jsonb;
  v_choices jsonb;
begin
  for v_bad in select value from jsonb_array_elements('[
    {"name":""}, {"price":-1}, {"price":100001}, {"price":"NaN"},
    {"daily_stock_limit":0}, {"daily_stock_limit":1.5}, {"is_available":"true"},
    {"options":{}}, {"options":[{}]},
    {"options":[{"id":"size","name":"Size","required":"true","max_select":1,"choices":[{"id":"big","name":"Big","price":0}]}]},
    {"options":[{"id":"size","name":"Size","required":true,"max_select":1.5,"choices":[{"id":"big","name":"Big","price":0}]}]},
    {"options":[{"id":"size","name":"Size","required":true,"max_select":2,"choices":[{"id":"big","name":"Big","price":0}]}]},
    {"options":[{"id":"size","name":"Size","required":true,"max_select":1,"choices":[{"id":"big","name":"Big","price":-1}]}]},
    {"options":[{"id":"size","name":"Size","required":true,"max_select":1,"choices":[{"id":"big","name":"Big","price":0},{"id":" big ","name":"Big again","price":5}]}]},
    {"options":[{"id":"size","name":"Size","required":true,"max_select":1,"choices":[{"id":"big","name":"Big","price":0}]},{"id":" size ","name":"Size again","required":false,"max_select":1,"choices":[{"id":"small","name":"Small","price":0}]}]}
  ]'::jsonb) loop
    perform test.expect_error(format('select public.admin_save_merchant_menu_item(null,%L,null,%L::jsonb,%L)',
      '00000000-0000-0000-0000-0000000000b2', (v_values || v_bad)::text, 'fixture invalid values'), '', 'invalid menu/options: ' || v_bad::text);
  end loop;
  select jsonb_agg(jsonb_build_object('id', 'group-' || n, 'name', 'Group ' || n,
    'required', false, 'max_select', 1, 'choices', '[{"id":"choice","name":"Choice","price":0}]'::jsonb))
    into v_groups from generate_series(1,21) n;
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(null,%L,null,%L::jsonb,%L)',
    '00000000-0000-0000-0000-0000000000b2', (v_values || jsonb_build_object('options', v_groups))::text,
    'fixture too many option groups'), 'options', 'maximum twenty option groups');
  select jsonb_agg(jsonb_build_object('id', 'choice-' || n, 'name', 'Choice ' || n, 'price', 0))
    into v_choices from generate_series(1,51) n;
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(null,%L,null,%L::jsonb,%L)',
    '00000000-0000-0000-0000-0000000000b2', (v_values || jsonb_build_object('options',
      jsonb_build_array(jsonb_build_object('id', 'group', 'name', 'Group', 'required', false,
        'max_select', 1, 'choices', v_choices))))::text, 'fixture too many choices'), 'options', 'maximum fifty choices');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(null,%L,null,%L::jsonb,%L)',
    '00000000-0000-0000-0000-0000000000b2', (v_values - 'options')::text, 'fixture invalid values'), '', 'full values required');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(null,%L,null,%L::jsonb,%L)',
    '00000000-0000-0000-0000-0000000000b2', v_values::text, 'x'), 'reason', 'short audit reason');
end;
$$;
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog('00000000-0000-0000-0000-0000000000b2')->'items') = 1, 'rejected creates are atomic');

do $$
declare
  v_before jsonb := test.item('00000000-0000-0000-0000-0000000000c1');
  v_values jsonb := current_setting('test.values')::jsonb || jsonb_build_object(
    'image_path', 'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000001.png',
    'sold_out_until', '2030-01-01T12:00:00Z',
    'options', '[{"id":"extras","name":"Extras","required":false,"max_select":1,"choices":[{"id":"egg","name":"Egg","price":10.25}]}]'::jsonb);
  v_saved jsonb;
begin
  v_saved := public.admin_save_merchant_menu_item('00000000-0000-0000-0000-0000000000c1',
    '00000000-0000-0000-0000-0000000000b1', (v_before->>'updated_at')::timestamptz, v_values, 'fixture edit options image stock');
  perform test.assert(v_saved->>'name' = 'Rice Bowl' and (v_saved->>'price')::numeric = 59.25
    and v_saved->'options' = v_values->'options' and v_saved->>'image_path' = v_values->>'image_path'
    and (v_saved->>'daily_stock_limit')::int = 20
    and (v_saved->>'sold_out_until')::timestamptz = '2030-01-01T12:00:00Z'::timestamptz
    and v_saved->>'updated_at' <> v_before->>'updated_at', 'save full fields and advance item version');
  perform test.assert(not (v_saved ? 'internal_notes'), 'save response whitelists item fields');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
    v_saved->>'id', v_saved->>'store_id', v_saved->>'updated_at', v_values::text, 'fixture unchanged values'),
    'No changes', 'unchanged save denied despite unrelated schema columns');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
    v_before->>'id', v_before->>'store_id', v_before->>'updated_at', v_values::text, 'fixture stale save'), 'changed', 'stale item edit');
  perform test.expect_error(format('select public.admin_set_merchant_menu_item_archived(%L,%L,true,%L)',
    v_before->>'id', v_before->>'updated_at', 'fixture stale archive'), 'changed', 'stale archive');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
    v_saved->>'id', '00000000-0000-0000-0000-0000000000b3', v_saved->>'updated_at', v_values::text, 'fixture reassign store'), '', 'store reassignment denied');
  perform test.assert((test.resolve((v_saved->>'id')::uuid,
    '[{"group_id":"extras","choice_id":"egg","price":99999}]')->>'unit_price')::numeric = 69.50,
    'real consumer resolver uses saved base price and option price');
  perform test.assert(test.resolve((v_saved->>'id')::uuid,
    '[{"group_id":"extras","choice_id":"egg"}]')->'selected_options'->0->>'choice_name' = 'Egg',
    'real consumer resolver snapshots saved option name');
  perform test.expect_error(format('select test.resolve(%L,''[{"group_id":"extras","choice_id":"foreign"}]'')',
    v_saved->>'id'), 'invalid menu option', 'consumer resolver rejects unknown option');
  perform test.expect_error(format('select test.checkout(%L,1,''[]'')', v_saved->>'id'),
    'unavailable', 'real consumer guard rejects temporary sold-out menu');
end;
$$;

do $$
declare
  v_path text;
  v_item jsonb := test.item('00000000-0000-0000-0000-0000000000c1');
  v_values jsonb := current_setting('test.values')::jsonb;
begin
  foreach v_path in array array[
    'stores/00000000-0000-0000-0000-0000000000b3/menu/10000000-0000-0000-0000-000000000001.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000099.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000002.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000003.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000004.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000005.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000006.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000007.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/10000000-0000-0000-0000-000000000008.png',
    'https://example.invalid/menu.png',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/../10000000-0000-0000-0000-000000000001.png'
  ] loop
    perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
      v_item->>'id', v_item->>'store_id', v_item->>'updated_at',
      (v_values || jsonb_build_object('image_path', v_path))::text, 'fixture invalid image'), '', 'invalid image: ' || v_path);
  end loop;
  perform test.assert(test.item((v_item->>'id')::uuid) = v_item, 'image rejection preserves item');
end;
$$;

do $$
declare
  v_item jsonb := test.item('00000000-0000-0000-0000-0000000000c1');
  v_archived jsonb;
  v_restored jsonb;
  v_ready jsonb;
  v_order_snapshot jsonb;
  v_legacy_expected jsonb;
begin
  v_archived := public.admin_set_merchant_menu_item_archived((v_item->>'id')::uuid,
    (v_item->>'updated_at')::timestamptz, true, 'fixture archive item');
  perform test.assert(v_archived->'archived_at' <> 'null'::jsonb and v_archived->>'is_available' = 'false', 'archive disables item');
  perform test.assert(not (v_archived ? 'internal_notes'), 'archive response whitelists item fields');
  perform test.assert(test.item((v_item->>'id')::uuid)->'archived_at' <> 'null'::jsonb, 'admin catalog retains archive');
  perform test.expect_error(format('select test.checkout(%L,1,''[]'')', v_item->>'id'),
    'unavailable', 'real consumer guard rejects archived menu');
  v_legacy_expected := jsonb_build_object('name', v_archived->'name', 'category', v_archived->'category',
    'description', v_archived->'description', 'price', v_archived->'price',
    'is_available', v_archived->'is_available', 'daily_stock_limit', v_archived->'daily_stock_limit');
  perform test.expect_error(format('select public.admin_update_merchant_menu_item(%L,%L::jsonb,%L,%L,null,60,true,null,%L)',
    v_item->>'id', v_legacy_expected::text, 'Legacy revive', 'Main', 'fixture legacy revive'), 'archiv', 'legacy RPC cannot revive archive');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
    v_item->>'id', v_item->>'store_id', v_archived->>'updated_at', current_setting('test.values'), 'fixture edit archive'), 'archiv', 'save cannot revive archive');
  v_restored := public.admin_set_merchant_menu_item_archived((v_item->>'id')::uuid,
    (v_archived->>'updated_at')::timestamptz, false, 'fixture restore item');
  perform test.assert(v_restored->'archived_at' = 'null'::jsonb and v_restored->>'is_available' = 'false', 'restore remains unavailable');
  perform test.expect_error(format('select test.checkout(%L,1,''[]'')', v_item->>'id'),
    'unavailable', 'real consumer guard rejects restored menu until explicitly available');
  perform test.expect_error(format('select public.admin_set_merchant_menu_item_archived(%L,%L,false,%L)',
    v_item->>'id', v_archived->>'updated_at', 'fixture stale restore'), 'changed', 'stale restore');
  v_ready := public.admin_save_merchant_menu_item((v_item->>'id')::uuid, (v_item->>'store_id')::uuid,
    (v_restored->>'updated_at')::timestamptz, current_setting('test.values')::jsonb ||
      jsonb_build_object('options', v_restored->'options', 'image_path', v_restored->'image_path'),
    'fixture explicit availability after restore');
  v_order_snapshot := test.checkout((v_item->>'id')::uuid, 1, '[{"group_id":"extras","choice_id":"egg"}]');
  perform test.assert((v_order_snapshot->>'unit_price')::numeric = 69.50
    and v_order_snapshot->>'name' = 'Rice Bowl', 'new order snapshots edited menu and real resolved add-on');
  perform test.expect_error(format('select test.checkout(%L,20,''[]'')', v_item->>'id'),
    'stock exceeded', 'real consumer guard rejects daily stock overflow');
end;
$$;

do $$
declare
  v_store_id uuid := '00000000-0000-0000-0000-0000000000b1';
  v_before jsonb := test.store(v_store_id);
  v_before_items jsonb := test.versions(v_store_id);
  v_saved jsonb;
  v_item jsonb;
begin
  v_saved := public.admin_save_merchant_menu_categories(v_store_id,
    (v_before->>'updated_at')::timestamptz, v_before_items,
    '["Bowls","Main"]', '{"Soups":"Bowls"}', 'fixture category rename reorder');
  perform test.assert(v_saved ?& array['store','items'] and v_saved->'store'->'menu_category_order' = '["Bowls","Main"]'::jsonb,
    'category save response and order');
  perform test.assert(not ((v_saved->'items'->0) ? 'internal_notes'), 'category response whitelists item fields');
  perform test.assert(test.item('00000000-0000-0000-0000-0000000000c2')->>'category' = 'Bowls', 'category rename persists');
  perform test.assert(test.item('00000000-0000-0000-0000-0000000000c3')->>'category' = 'Other', 'category rename store isolation');
  perform test.expect_error(format('select public.admin_save_merchant_menu_categories(%L,%L,%L::jsonb,''["Main","Bowls"]'',''{}'',%L)',
    v_store_id, v_before->>'updated_at', v_before_items::text, 'fixture stale categories'), 'changed', 'stale store category edit');
  perform test.expect_error(format('select public.admin_save_merchant_menu_categories(%L,%L,''{}'',''["Main","Bowls"]'',''{}'',%L)',
    v_store_id, test.store(v_store_id)->>'updated_at', 'fixture missing item versions'), 'changed', 'all item versions required');
  v_before_items := test.versions(v_store_id);
  v_item := test.item('00000000-0000-0000-0000-0000000000c2');
  perform public.admin_save_merchant_menu_item((v_item->>'id')::uuid, v_store_id,
    (v_item->>'updated_at')::timestamptz, current_setting('test.values')::jsonb || '{"category":"Bowls","name":"Soup Bowl"}', 'fixture concurrent item edit');
  perform test.expect_error(format('select public.admin_save_merchant_menu_categories(%L,%L,%L::jsonb,''["Main","Bowls"]'',''{}'',%L)',
    v_store_id, test.store(v_store_id)->>'updated_at', v_before_items::text, 'fixture stale item versions'), 'changed', 'stale item map with current store version');
  perform test.expect_error(format('select public.admin_save_merchant_menu_categories(%L,%L,%L::jsonb,''["Main","Bowls"]'',''{}'',%L)',
    v_store_id, test.store(v_store_id)->>'updated_at',
    (test.versions(v_store_id) || jsonb_build_object('00000000-0000-0000-0000-0000000000c3', test.item('00000000-0000-0000-0000-0000000000c3')->>'updated_at'))::text,
    'fixture foreign item versions'), 'changed', 'foreign item version map rejected');
  perform test.expect_error(format('select public.admin_save_merchant_menu_categories(%L,%L,%L::jsonb,''["Main","Main"]'',''{}'',%L)',
    v_store_id, test.store(v_store_id)->>'updated_at', test.versions(v_store_id)::text, 'fixture duplicate categories'), '', 'duplicate category order denied');
end;
$$;

-- Leave an archived item for migration rerun and rollback preservation checks.
select public.admin_set_merchant_menu_item_archived(current_setting('test.created_item')::uuid,
  (test.item(current_setting('test.created_item')::uuid)->>'updated_at')::timestamptz, true, 'fixture archive before rollback');
reset role;
select test.assert((select snapshot = '{"name":"Rice","price":55,"quantity":2,"options":[{"name":"Egg","price":10}]}'::jsonb
  and item_name = 'Rice' and unit_price = 65 and selected_options = '[{"name":"Egg","price":10}]'::jsonb
  from public.food_order_items where id = '00000000-0000-0000-0000-0000000000d1'), 'order snapshot survives edits archive restore categories');
select test.assert((select count(*) > 0 and bool_and(actor_id = '00000000-0000-0000-0000-0000000000a2'
  and length(detail->>'reason') between 5 and 300) from public.audit_log), 'writes audited with actor and reason');
select test.assert(exists(select 1 from public.audit_log where detail->>'reason' = 'fixture edit options image stock'
  and detail ?& array['before','after']), 'edit has before and after audit');
select test.assert(exists(select 1 from public.audit_log where detail->>'reason' = 'fixture category rename reorder'), 'category audit reason');
select test.assert(not has_function_privilege('anon', 'public.admin_merchant_menu_catalog(uuid)', 'EXECUTE'), 'anon catalog privilege revoked');
insert into public.audit_log(actor_id, event_type, detail) values
  ('00000000-0000-0000-0000-0000000000a2', 'merchant_store_updated', '{"reason":"fixture legacy event preserved"}'),
  ('00000000-0000-0000-0000-0000000000a2', 'merchant_menu_deleted', '{"reason":"fixture legacy event preserved"}');
SQL

# Two independent authenticated sessions submit the same stock/menu version.
RACE_VERSION="$(run -At -c "select updated_at from public.food_menu_items where id='00000000-0000-0000-0000-0000000000c3'")"
race_save() {
  run -At -c "set role authenticated; select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);" \
    -c "select test.race_save('$RACE_VERSION','$1')" | tail -n1
}
race_save 'Concurrent A' > "$TMP_DIR/race-a" &
RACE_A_PID=$!
race_save 'Concurrent B' > "$TMP_DIR/race-b" &
RACE_B_PID=$!
wait "$RACE_A_PID"
wait "$RACE_B_PID"
RACE_RESULTS="$(sort "$TMP_DIR/race-a" "$TMP_DIR/race-b")"
[[ "$RACE_RESULTS" == $'conflict\nsaved' ]] || { echo "FAIL concurrent saves: $RACE_RESULTS"; exit 1; }
run >/dev/null <<'SQL'
select test.assert((select count(*) = 1 from public.audit_log
  where detail->>'reason' = 'fixture concurrent stock save'), 'only one concurrent write audited');
select test.assert((select daily_stock_limit = 1 from public.food_menu_items
  where id = '00000000-0000-0000-0000-0000000000c3'), 'concurrent stock value persisted');
SQL

# The original availability trigger serializes two purchases of the final unit.
race_checkout() {
  run -At -c "set role authenticated; select set_config('test.uid','00000000-0000-0000-0000-0000000000a3',false);" \
    -c 'select test.race_checkout()' | tail -n1
}
race_checkout > "$TMP_DIR/checkout-a" &
CHECKOUT_A_PID=$!
race_checkout > "$TMP_DIR/checkout-b" &
CHECKOUT_B_PID=$!
wait "$CHECKOUT_A_PID"
wait "$CHECKOUT_B_PID"
CHECKOUT_RESULTS="$(sort "$TMP_DIR/checkout-a" "$TMP_DIR/checkout-b")"
[[ "$CHECKOUT_RESULTS" == $'purchased\nstock-conflict' ]] || { echo "FAIL concurrent checkout: $CHECKOUT_RESULTS"; exit 1; }
run >/dev/null <<'SQL'
select test.assert((select sum(quantity) = 1 from public.food_order_items
  where menu_item_id = '00000000-0000-0000-0000-0000000000c3'), 'actual stock guard prevents concurrent oversell');
SQL

# Reproduce the merchant item-lock -> admin store-lock ordering explicitly. The
# temporary grants model existing merchant table access after testing RPC-only
# admin access above; this fixture does not model deployed merchant RLS policies.
run >/dev/null -c 'grant select, update, insert on public.food_menu_items to authenticated'
wait_for_sql() {
  local attempt
  for ((attempt=0; attempt<100; attempt++)); do
    [[ "$(run -At -c "$1")" == 't' ]] && return 0
    sleep 0.02
  done
  echo "FAIL timed out: $2"
  return 1
}
category_race() {
  run -At -c "set application_name='admin-menu-category-race'; set role authenticated; select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);" \
    -c "select test.race_categories('$CATEGORY_VERSION','$CATEGORY_ITEMS'::jsonb)" | tail -n1
}
snapshot_categories() {
  CATEGORY_VERSION="$(run -At -c "select updated_at from public.food_stores where id='00000000-0000-0000-0000-0000000000b1'")"
  CATEGORY_ITEMS="$(run -At -c "select jsonb_object_agg(id::text,to_jsonb(updated_at)) from public.food_menu_items where store_id='00000000-0000-0000-0000-0000000000b1'")"
}
snapshot_categories
mkfifo "$TMP_DIR/merchant-input"
run -At < "$TMP_DIR/merchant-input" > "$TMP_DIR/merchant-result" 2> "$TMP_DIR/merchant-error" &
MERCHANT_PID=$!
exec {MERCHANT_FD}> "$TMP_DIR/merchant-input"
printf '%s\n' \
  'begin;' \
  "set application_name='admin-menu-merchant-update';" \
  'set role authenticated;' \
  "select id from public.food_menu_items where id='00000000-0000-0000-0000-0000000000c2' for update;" \
  'select pg_advisory_xact_lock(57490101);' >&"$MERCHANT_FD"
wait_for_sql "select exists(select 1 from pg_locks where locktype='advisory' and objid=57490101 and granted)" 'merchant holds item row'
category_race > "$TMP_DIR/category-update-result" 2> "$TMP_DIR/category-update-error" &
CATEGORY_PID=$!
wait_for_sql "select exists(select 1 from pg_stat_activity where application_name='admin-menu-category-race' and wait_event_type='Lock')" 'category waits for merchant item row'
printf '%s\n' \
  "update public.food_menu_items set description='Merchant direct edit' where id='00000000-0000-0000-0000-0000000000c2';" \
  'commit;' \
  "select 'merchant-committed';" >&"$MERCHANT_FD"
exec {MERCHANT_FD}>&-
if ! wait "$MERCHANT_PID"; then cat "$TMP_DIR/merchant-error"; exit 1; fi
if ! wait "$CATEGORY_PID"; then cat "$TMP_DIR/category-update-error"; exit 1; fi
[[ "$(tail -n1 "$TMP_DIR/merchant-result")" == 'merchant-committed' && "$(cat "$TMP_DIR/category-update-result")" == 'conflict' ]] || {
  echo 'FAIL merchant UPDATE/category race did not commit and reject stale category'; exit 1;
}

# An inserted item locks the store before the new tuple exists, invalidating a
# category snapshot taken before the merchant insert rather than creating a phantom.
snapshot_categories
mkfifo "$TMP_DIR/merchant-insert-input"
run -At < "$TMP_DIR/merchant-insert-input" > "$TMP_DIR/merchant-insert-result" 2> "$TMP_DIR/merchant-insert-error" &
INSERT_PID=$!
exec {INSERT_FD}> "$TMP_DIR/merchant-insert-input"
printf '%s\n' \
  'begin;' \
  "set application_name='admin-menu-merchant-insert';" \
  'set role authenticated;' \
  "insert into public.food_menu_items(id,store_id,name,category,price) values('00000000-0000-0000-0000-0000000000c4','00000000-0000-0000-0000-0000000000b1','Merchant inserted','Main',35);" \
  'select pg_advisory_xact_lock(57490102);' >&"$INSERT_FD"
wait_for_sql "select exists(select 1 from pg_locks where locktype='advisory' and objid=57490102 and granted)" 'merchant insert holds store row'
category_race > "$TMP_DIR/category-insert-result" 2> "$TMP_DIR/category-insert-error" &
CATEGORY_INSERT_PID=$!
wait_for_sql "select exists(select 1 from pg_stat_activity where application_name='admin-menu-category-race' and wait_event_type='Lock')" 'category waits for merchant insert store lock'
printf '%s\n' 'commit;' "select 'insert-committed';" >&"$INSERT_FD"
exec {INSERT_FD}>&-
if ! wait "$INSERT_PID"; then cat "$TMP_DIR/merchant-insert-error"; exit 1; fi
if ! wait "$CATEGORY_INSERT_PID"; then cat "$TMP_DIR/category-insert-error"; exit 1; fi
[[ "$(tail -n1 "$TMP_DIR/merchant-insert-result")" == 'insert-committed' && "$(cat "$TMP_DIR/category-insert-result")" == 'conflict' ]] || {
  echo 'FAIL merchant INSERT/category race did not serialize and reject stale category'; exit 1;
}
run >/dev/null -c 'revoke select, update, insert on public.food_menu_items from authenticated'

# Exercise the actual Merchant SELECT/UPDATE policies with synthetic ownership
# helpers. Restoring an archive must remain a separate step from opening sales;
# owners retain the same per-store lifecycle permissions as before.
run >/dev/null <<'SQL'
alter table public.food_stores add column is_published boolean not null default false;
create function public.merchant_has_store_role(p_store_id uuid,p_roles text[]) returns boolean
language sql stable security definer set search_path='' as $$
  select auth.uid()='00000000-0000-0000-0000-0000000000a4'::uuid
    and p_store_id='00000000-0000-0000-0000-0000000000b1'::uuid and 'owner'=any(p_roles)
$$;
create function public.food_has_merchant_access(p_store_id uuid) returns boolean
language sql stable as $$ select public.merchant_has_store_role(p_store_id,array['owner']) $$;
create function public.is_developer_account() returns boolean language sql stable as $$ select false $$;
create function public.food_public_access_enabled() returns boolean language sql stable as $$ select false $$;
create function public.food_is_permanent_account() returns boolean language sql stable as $$ select false $$;
alter table public.food_menu_items enable row level security;
grant select on public.food_stores to authenticated;
grant select,update on public.food_menu_items to authenticated;
insert into public.food_menu_items(id,store_id,name,category,price,archived_at,is_available)
values('00000000-0000-0000-0000-0000000000c5','00000000-0000-0000-0000-0000000000b1',
  'Merchant archive lifecycle','Main',40,clock_timestamp(),false);
SQL
extract_policy() {
  awk -v marker="$2" '
    index($0, marker) == 1 { copying = 1 }
    copying { print }
    copying && /;$/ { found = 1; exit }
    END { if (!found) exit 1 }
  ' "$ROOT/supabase/$1" | run >/dev/null
}
extract_policy migrations_wynos_food_customer_access_gate_v2.sql 'create policy "Food menu visible by rollout gate"'
extract_policy migrations_wynos_merchant_core_completion_v1.sql 'create policy "Food menu updated by merchant"'
extract_policy migrations_wynos_merchant_core_completion_v1.sql 'create policy "Food menu inserted by merchant"'
run >/dev/null <<'SQL'
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
select test.expect_error($q$update public.food_menu_items set archived_at=null,is_available=true
  where id='00000000-0000-0000-0000-0000000000c5'$q$,'Restored menu','merchant cannot restore and publish in one update');
select test.assert((select archived_at is not null and not is_available from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c5'),'rejected restore preserves original archive');
with changed as (update public.food_menu_items set archived_at=null,is_available=true
  where id='00000000-0000-0000-0000-0000000000c3' returning id)
select test.assert((select count(*)=0 from changed),'owner cannot restore another store menu');
update public.food_menu_items set archived_at=null where id='00000000-0000-0000-0000-0000000000c5';
select test.assert((select archived_at is null and not is_available from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c5'),'owner can restore unavailable menu');
update public.food_menu_items set is_available=true where id='00000000-0000-0000-0000-0000000000c5';
select test.assert((select is_available from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c5'),'owner can explicitly publish after restore');
reset role;
update public.food_menu_items set archived_at=clock_timestamp(),is_available=false
where id='00000000-0000-0000-0000-0000000000c5';
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
select test.assert((public.admin_set_merchant_menu_item_archived(
  '00000000-0000-0000-0000-0000000000c5',
  (test.item('00000000-0000-0000-0000-0000000000c5')->>'updated_at')::timestamptz,
  false,'fixture separate admin restore')->>'is_available')='false','admin restore still remains unavailable');
reset role;
update public.food_menu_items set archived_at=clock_timestamp(),is_available=false
where id='00000000-0000-0000-0000-0000000000c5';
SQL

# Trusted upload references must also be safe through the real Merchant table
# policies, not only the Admin save RPC. Storage policy definitions and the
# latest store-write helper are loaded verbatim; fixture ownership stays synthetic.
run >/dev/null <<'SQL'
alter table public.food_stores add column merchant_account_id uuid;
update public.food_stores set merchant_account_id=id;
create table public.merchant_memberships(merchant_account_id uuid,user_id uuid,role text,active boolean);
insert into public.merchant_memberships values
  ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a4','owner',true);
create table public.food_staff(store_id uuid,user_id uuid,role text,active boolean);
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]
$$;
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated;
grant select,insert,update,delete on storage.objects to authenticated;
grant insert on public.food_menu_items to authenticated;
insert into storage.objects values
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp','{"mimetype":"image/webp","size":4194304}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b3/10000000-0000-0000-0000-000000000101.webp','{"mimetype":"image/webp","size":2048}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000102.webp','{"mimetype":"image/png","size":2048}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000103.webp','{"mimetype":"image/webp","size":4194305}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000104.webp','{"mimetype":"image/webp","size":0}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000105.webp','{"mimetype":"image/webp","size":"2048"}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000106.webp','{"mimetype":"image/webp","size":1.5}'),
  ('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000107.jpg','{"mimetype":"image/jpeg","size":2048}');
SQL
extract_function migrations_wynos_food_storage_store_isolation_v1.sql 'create or replace function public.food_path_uuid('
extract_function migrations_wynos_merchant_access_hardening_v1.sql 'create or replace function public.food_store_media_writable('
extract_policy migrations_wynos_food_merchant_v1.sql 'create policy "Food public media readable"'
extract_policy migrations_wynos_food_storage_store_isolation_v1.sql 'create policy "Food public media merchant upload"'
extract_policy migrations_wynos_food_storage_store_isolation_v1.sql 'create policy "Food public media merchant update"'
extract_policy migrations_wynos_food_storage_store_isolation_v1.sql 'create policy "Food public media merchant delete"'
run >/dev/null <<'SQL'
revoke all on function public.food_path_uuid(text) from public,anon;
revoke all on function public.food_store_media_writable(text) from public,anon;
grant execute on function public.food_path_uuid(text),public.food_store_media_writable(text) to authenticated;
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a1',false);
select test.assert(jsonb_array_length(public.admin_merchant_menu_catalog('00000000-0000-0000-0000-0000000000b1')->'images')=2,
  'catalog includes only valid legacy and trusted images of this store');
select test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-0000000000b1'')','Not authorized','view-only upload denied');
select set_config('test.uid','',false);
select test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-0000000000b1'')','Not authorized','signed-out upload denied');
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
select test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-0000000000b1'')','Not authorized','owner without Admin permission cannot use Admin upload');
select test.assert(public.food_store_media_writable('stores/00000000-0000-0000-0000-0000000000b1/menu/old.png'),
  'existing helper still permits owner store media');
select test.assert(not public.food_store_media_writable('admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'),
  'existing helper denies owner writes to trusted prefix');
select test.expect_error($q$insert into storage.objects values('food-public',
  'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000199.webp',
  '{"mimetype":"image/webp","size":1024}')$q$,'row-level security','owner cannot upload bytes to trusted prefix');
with changed as (update storage.objects set metadata='{"mimetype":"image/webp","size":1}'
  where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp' returning name)
select test.assert((select count(*)=0 from changed),'owner cannot overwrite trusted object');
with removed as (delete from storage.objects
  where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp' returning name)
select test.assert((select count(*)=0 from removed),'owner cannot delete trusted object');
insert into storage.objects values('food-public','stores/00000000-0000-0000-0000-0000000000b1/menu/owner-still-uploads.png',
  '{"mimetype":"image/png","size":1024}');
select test.expect_error($q$update storage.objects set name=
  'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000199.webp'
  where name='stores/00000000-0000-0000-0000-0000000000b1/menu/owner-still-uploads.png'$q$,
  'row-level security','owner cannot rename legacy object into trusted prefix');
update public.food_menu_items set image_path='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'
  where id='00000000-0000-0000-0000-0000000000c1';
select test.assert((select image_path like 'admin-menu/%' from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c1'),'owner may attach existing same-store trusted image');
do $$
declare v_path text;
begin
  foreach v_path in array array[
    'admin-menu/00000000-0000-0000-0000-0000000000b3/10000000-0000-0000-0000-000000000101.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000199.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000102.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000103.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000104.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000105.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000106.webp',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000107.jpg',
    'admin-menu/not-a-store/not-a-file.webp',
    'stores/00000000-0000-0000-0000-0000000000b1/menu/../../../admin-menu/00000000-0000-0000-0000-0000000000b3/10000000-0000-0000-0000-000000000101.webp',
    '/admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp',
    'https://example.invalid/photo.png', 'javascript:alert(1)', 'legacy/./photo.png', 'legacy/../photo.png',
    'legacy/'||chr(92)||'photo.png', 'legacy/'||chr(10)||'photo.png',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp/extra'
  ] loop
    perform test.expect_error(format('update public.food_menu_items set image_path=%L where id=%L',
      v_path,'00000000-0000-0000-0000-0000000000c1'),'Invalid menu image','direct owner image update denied: '||v_path);
    perform test.expect_error(format('insert into public.food_menu_items(store_id,name,category,price,image_path) values(%L,''Unsafe image'',''Main'',1,%L)',
      '00000000-0000-0000-0000-0000000000b1',v_path),'Invalid menu image','direct owner image insert denied: '||v_path);
  end loop;
end $$;
insert into public.food_menu_items(id,store_id,name,category,price,image_path) values(
  '00000000-0000-0000-0000-0000000000c6','00000000-0000-0000-0000-0000000000b1','Trusted image insert','Main',1,
  'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp');
select test.assert(exists(select 1 from public.food_menu_items where id='00000000-0000-0000-0000-0000000000c6'),
  'owner inserts own menu with trusted image');
update public.food_menu_items set image_path='legacy/menu-photo.png' where id='00000000-0000-0000-0000-0000000000c6';
select test.assert((select image_path='legacy/menu-photo.png' from public.food_menu_items where id='00000000-0000-0000-0000-0000000000c6'),
  'ordinary safe legacy owner paths keep existing semantics');
with changed as(update public.food_menu_items set image_path=null where id='00000000-0000-0000-0000-0000000000c3' returning id)
select test.assert((select count(*)=0 from changed),'owner cannot change another store image');
reset role;
delete from storage.objects where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp';
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
update public.food_menu_items set image_path=image_path,name='Historical reference retained' where id='00000000-0000-0000-0000-0000000000c1';
select test.assert((select name='Historical reference retained' and image_path like 'admin-menu/%' from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c1'),'unchanged missing historical trusted reference does not block edits');
reset role;
insert into storage.objects values('food-public','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp',
  '{"mimetype":"image/webp","size":4194304}');
set role anon;
select test.expect_error('select public.admin_authorize_merchant_menu_upload(null)','permission denied','anon upload RPC revoked');
reset role;
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
do $$
declare v_item jsonb; v_values jsonb; v_saved jsonb;
begin
  v_item:=test.item('00000000-0000-0000-0000-0000000000c6');
  v_values:=(v_item-array['id','store_id','store_name','sort_order','created_at','updated_at','archived_at'])
    ||jsonb_build_object('image_path','admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp');
  v_saved:=public.admin_save_merchant_menu_item((v_item->>'id')::uuid,(v_item->>'store_id')::uuid,
    (v_item->>'updated_at')::timestamptz,v_values,'fixture Admin trusted image save');
  perform test.assert(v_saved->>'image_path'=v_values->>'image_path','Admin save accepts existing same-store trusted image');
  perform test.expect_error(format('select public.admin_save_merchant_menu_item(%L,%L,%L,%L::jsonb,%L)',
    v_saved->>'id',v_saved->>'store_id',v_saved->>'updated_at',
    (v_values||jsonb_build_object('image_path','admin-menu/00000000-0000-0000-0000-0000000000b3/10000000-0000-0000-0000-000000000101.webp'))::text,
    'fixture Admin foreign trusted image'),'Invalid menu image','Admin save rejects foreign trusted image');
end $$;
select test.expect_error('select public.admin_authorize_merchant_menu_upload(null)','Store not found','missing store upload rejected');
select test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-000000000099'')','Store not found','unknown store upload rejected');
select test.expect_error('select * from internal.admin_menu_upload_budgets','permission denied','upload budget is not readable');
select test.expect_error('update internal.admin_menu_upload_budgets set attempts=1','permission denied','upload budget is not writable');
select test.assert(not public.food_store_media_writable('admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'),
  'Admin permission does not grant trusted-prefix Storage writes');
reset role;
-- A historical/additional permissive OR must not let any ordinary caller forge
-- a supposedly trusted image. Temporary broad access exists only in this fixture.
create table public.developer_accounts(user_id uuid primary key);
insert into public.developer_accounts values('00000000-0000-0000-0000-0000000000a3');
grant usage on schema storage to anon;
grant select,insert,update,delete on storage.objects to anon;
create policy "test broad historical storage writes" on storage.objects
for all to public using(true) with check(true);
create function test.trusted_storage_guards(p_label text) returns void language plpgsql as $$
declare v_count bigint;
begin
  perform test.expect_error($q$insert into storage.objects values('food-public',
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000199.webp',
    '{"mimetype":"image/webp","size":1024}')$q$,'row-level security',p_label||' broad policy cannot forge trusted image');
  with changed as(update storage.objects set metadata='{"mimetype":"image/webp","size":1}'
    where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp' returning name)
  select count(*) into v_count from changed;
  perform test.assert(v_count=0,p_label||' broad policy cannot overwrite trusted image');
  with removed as(delete from storage.objects
    where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp' returning name)
  select count(*) into v_count from removed;
  perform test.assert(v_count=0,p_label||' broad policy cannot delete trusted image');
  perform test.expect_error($q$update storage.objects set name=
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000199.webp'
    where name='stores/00000000-0000-0000-0000-0000000000b1/menu/owner-still-uploads.png'$q$,
    'row-level security',p_label||' broad policy cannot rename legacy image into trusted prefix');
  with changed as(update storage.objects set name='stores/00000000-0000-0000-0000-0000000000b1/menu/stolen.webp'
    where name='admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp' returning name)
  select count(*) into v_count from changed;
  perform test.assert(v_count=0,p_label||' broad policy cannot rename trusted image out of prefix');
  perform test.assert(exists(select 1 from storage.objects where name=
    'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'),
    p_label||' trusted public read remains available');
  insert into storage.objects values('fixture-other-bucket','admin-menu/'||p_label||'.webp','{}');
  delete from storage.objects where bucket_id='fixture-other-bucket' and name='admin-menu/'||p_label||'.webp';
end $$;
grant execute on function test.trusted_storage_guards(text) to authenticated,anon;
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
select test.trusted_storage_guards('owner');
select set_config('test.uid','00000000-0000-0000-0000-0000000000a3',false);
select test.trusted_storage_guards('developer');
reset role;
set role anon;
select test.trusted_storage_guards('anon');
reset role;
drop policy "test broad historical storage writes" on storage.objects;
revoke select,insert,update,delete on storage.objects from anon;
select test.assert((select count(*)=3 from pg_policy where polrelid='storage.objects'::regclass
  and not polpermissive and polname like 'Food admin menu trusted % guard'),'three reserved-prefix policies are restrictive');
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
do $$
begin
  for i in 1..10 loop
    perform test.assert(public.admin_authorize_merchant_menu_upload(case when i%2=0
      then '00000000-0000-0000-0000-0000000000b1'::uuid else '00000000-0000-0000-0000-0000000000b3'::uuid end),
      'allowed upload returns only true');
  end loop;
  perform test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-0000000000b2'')',
    'Menu image upload limit reached','store rotation cannot bypass actor upload limit');
end $$;
reset role;
select test.assert((select attempts=10 from internal.admin_menu_upload_budgets
  where actor_id='00000000-0000-0000-0000-0000000000a2'),'rejected upload leaves bounded counter at ten');
update internal.admin_menu_upload_budgets set window_started_at=clock_timestamp()-interval '11 minutes'
  where actor_id='00000000-0000-0000-0000-0000000000a2';
set role authenticated;
select test.assert(public.admin_authorize_merchant_menu_upload('00000000-0000-0000-0000-0000000000b1'),'expired window permits next upload');
select set_config('test.uid','00000000-0000-0000-0000-0000000000a6',false);
do $$ begin for i in 1..9 loop perform public.admin_authorize_merchant_menu_upload('00000000-0000-0000-0000-0000000000b1'); end loop; end $$;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a7',false);
select public.admin_authorize_merchant_menu_upload('00000000-0000-0000-0000-0000000000b1');
reset role;
select test.assert((select attempts=1 from internal.admin_menu_upload_budgets
  where actor_id='00000000-0000-0000-0000-0000000000a2'),'new window reuses actor row and resets count');
delete from public.profiles where id='00000000-0000-0000-0000-0000000000a7';
select test.assert(not exists(select 1 from internal.admin_menu_upload_budgets
  where actor_id='00000000-0000-0000-0000-0000000000a7'),'actor deletion cascades only ephemeral budget');
select test.assert((select relrowsecurity from pg_class where oid='internal.admin_menu_upload_budgets'::regclass),
  'private upload budgets enable RLS');
create function test.race_upload(p_store_id uuid) returns text language plpgsql as $$
begin
  perform public.admin_authorize_merchant_menu_upload(p_store_id);
  perform pg_sleep(0.25);
  return 'allowed';
exception when others then
  if sqlerrm='Menu image upload limit reached' then return 'limited'; end if;
  raise;
end $$;
grant execute on function test.race_upload(uuid) to authenticated;
SQL
race_upload() {
  run -At -c "set role authenticated; select set_config('test.uid','00000000-0000-0000-0000-0000000000a6',false);" \
    -c "select test.race_upload('$1')" | tail -n1
}
race_upload '00000000-0000-0000-0000-0000000000b1' > "$TMP_DIR/upload-a" &
UPLOAD_A_PID=$!
race_upload '00000000-0000-0000-0000-0000000000b3' > "$TMP_DIR/upload-b" &
UPLOAD_B_PID=$!
wait "$UPLOAD_A_PID"
wait "$UPLOAD_B_PID"
[[ "$(sort "$TMP_DIR/upload-a" "$TMP_DIR/upload-b")" == $'allowed\nlimited' ]] || {
  echo 'FAIL overlapping different-store uploads did not share one remaining slot'; exit 1;
}
run >/dev/null <<'SQL'
select test.assert((select attempts=10 from internal.admin_menu_upload_budgets
  where actor_id='00000000-0000-0000-0000-0000000000a6'),'overlapping uploads preserve actor quota');
select test.assert((select count(*)=2 from internal.admin_menu_upload_budgets),'bounded one-row-per-actor storage');
update public.admin_permissions set level='view' where user_id='00000000-0000-0000-0000-0000000000a6';
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a6',false);
select test.expect_error('select public.admin_authorize_merchant_menu_upload(''00000000-0000-0000-0000-0000000000b1'')',
  'Not authorized','permission revocation is checked before existing budget');
reset role;
update public.admin_permissions set level='edit' where user_id='00000000-0000-0000-0000-0000000000a6';
SQL

# Reapplying and rolling back executable definitions must preserve persisted data.
run >/dev/null < "$ROOT/supabase/migrations/$MIGRATION.sql"
run >/dev/null <<'SQL'
select test.assert((select attempts=10 from internal.admin_menu_upload_budgets
  where actor_id='00000000-0000-0000-0000-0000000000a6'),'migration rerun preserves upload budgets');
SQL
run >/dev/null < "$ROOT/supabase/rollbacks/${MIGRATION}_rollback.sql"
run >/dev/null <<'SQL'
select test.assert(to_regprocedure('public.admin_merchant_menu_catalog(uuid)') is null, 'rollback drops new catalog RPC');
select test.assert(to_regprocedure('public.admin_save_merchant_menu_item(uuid,uuid,timestamp with time zone,jsonb,text)') is null, 'rollback drops save RPC');
select test.assert(to_regprocedure('public.admin_authorize_merchant_menu_upload(uuid)') is null,'rollback drops upload authorization RPC');
select test.assert(to_regclass('internal.admin_menu_upload_budgets') is null,'rollback drops only ephemeral upload budgets');
select test.assert(to_regprocedure('internal.admin_menu_image_valid(uuid,text)') is not null,'rollback retains guard validator dependency');
select test.assert((select count(*)=3 from pg_policy where polrelid='storage.objects'::regclass
  and not polpermissive and polname like 'Food admin menu trusted % guard'),'rollback retains restrictive trusted-prefix policies');
select test.assert(exists(select 1 from storage.objects where name=
  'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'),
  'rollback preserves trusted media object');
select test.assert(exists(select 1 from public.food_menu_items where store_id = '00000000-0000-0000-0000-0000000000b2'
  and archived_at is not null and not is_available), 'rollback preserves archive and unavailable state');
select test.assert((select snapshot->>'name' = 'Rice' and (snapshot->>'price')::numeric = 55
  from public.food_order_items where id = '00000000-0000-0000-0000-0000000000d1'), 'rollback preserves immutable order snapshot');
do $$
declare v_item jsonb;
begin
  select to_jsonb(m) into v_item from public.food_menu_items m
  where store_id = '00000000-0000-0000-0000-0000000000b2' and archived_at is not null;
  perform set_config('test.rollback_item', v_item::text, false);
end;
$$;
set role authenticated;
select set_config('test.uid', '00000000-0000-0000-0000-0000000000a2', false);
select test.assert(jsonb_array_length(public.admin_merchant_menu_items(null)) >= 3, 'legacy read callable after rollback');
do $$
declare
  v_item jsonb := current_setting('test.rollback_item')::jsonb;
  v_expected jsonb;
begin
  v_expected := jsonb_build_object('name', v_item->'name', 'category', v_item->'category',
    'description', v_item->'description', 'price', v_item->'price',
    'is_available', v_item->'is_available', 'daily_stock_limit', v_item->'daily_stock_limit');
  perform test.expect_error(format('select public.admin_update_merchant_menu_item(%L,%L::jsonb,%L,%L,null,60,true,null,%L)',
    v_item->>'id', v_expected::text, 'Rollback revive', v_item->>'category', 'fixture rollback revive'), 'archiv', 'rollback legacy RPC cannot revive archived item');
end;
$$;
reset role;
create policy "test broad historical storage writes" on storage.objects
for all to public using(true) with check(true);
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
select test.trusted_storage_guards('rollback-owner');
reset role;
drop policy "test broad historical storage writes" on storage.objects;
set role authenticated;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a4',false);
select test.expect_error($q$update public.food_menu_items set image_path=
  'admin-menu/00000000-0000-0000-0000-0000000000b3/10000000-0000-0000-0000-000000000101.webp'
  where id='00000000-0000-0000-0000-0000000000c1'$q$,'Invalid menu image','rollback retains foreign trusted image guard');
update public.food_menu_items set name='Image still retained after rollback',image_path=image_path
  where id='00000000-0000-0000-0000-0000000000c1';
select test.assert((select image_path=
  'admin-menu/00000000-0000-0000-0000-0000000000b1/10000000-0000-0000-0000-000000000101.webp'
  from public.food_menu_items where id='00000000-0000-0000-0000-0000000000c1'),'rollback preserves existing trusted image reference');
select test.expect_error($q$update public.food_menu_items set archived_at=null,is_available=true
  where id='00000000-0000-0000-0000-0000000000c5'$q$,'Restored menu','rollback retains direct restore safety guard');
update public.food_menu_items set archived_at=null where id='00000000-0000-0000-0000-0000000000c5';
select test.assert((select archived_at is null and not is_available from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c5'),'rollback retains permitted unavailable restore');
update public.food_menu_items set is_available=true where id='00000000-0000-0000-0000-0000000000c5';
select test.assert((select is_available from public.food_menu_items
  where id='00000000-0000-0000-0000-0000000000c5'),'rollback retains separate explicit publication');
reset role;
revoke select,update on public.food_menu_items from authenticated;
revoke select on public.food_stores from authenticated;
insert into public.audit_log(actor_id, event_type, detail) values
  ('00000000-0000-0000-0000-0000000000a2', 'merchant_store_updated', '{"reason":"fixture rollback legacy event"}');
SQL
echo "PASS Admin Merchant menu complete: actual roles, CRUD, options, trusted media, Storage isolation, concurrent upload quota, categories, snapshots, audit, rerun and rollback"
