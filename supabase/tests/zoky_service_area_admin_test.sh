#!/usr/bin/env bash
# ZOKY Admin chooses service areas (Founder 2026-11-02): whole country + 77
# provinces, super admin only, audited, never zero open areas. Applies WYN-211,
# the Thailand row and the admin migration on a throwaway PostgreSQL database.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/zoky_service_area_admin_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="zoky_service_area_admin_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
export PGOPTIONS="--client-min-messages=warning"
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

SUPER=00000000-0000-0000-0000-0000000000a0
VIEWER=00000000-0000-0000-0000-0000000000a1
EDITOR=00000000-0000-0000-0000-0000000000a2
NOBODY=00000000-0000-0000-0000-0000000000a3
STORE_CM=00000000-0000-0000-0000-0000000000f1

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table internal.platform_super_admins(user_id uuid primary key);
create table public.admin_permissions(user_id uuid, system text, level text);
create function internal.is_super_admin() returns boolean language sql stable security definer set search_path='' as
  \$\$ select exists (select 1 from internal.platform_super_admins where user_id = (select auth.uid())) \$\$;
create function internal.has_admin_permission(p_system text, p_level text) returns boolean language sql stable security definer set search_path='' as
  \$\$ select internal.is_super_admin() or exists (select 1 from public.admin_permissions a where a.user_id = (select auth.uid())
       and a.system = p_system and (a.level = 'edit' or p_level = 'view')) \$\$;
create table public.audit_log(actor_id uuid, actor_username_snapshot text, event_type text not null, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check (event_type in ('user_banned', 'zoky_team_lead_appointed')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void
  language sql security definer as \$\$ insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.developer_accounts(user_id uuid primary key);
create table public.food_rollout_settings(id boolean primary key default true, public_enabled boolean not null default false);
insert into public.food_rollout_settings values (true, false);
create table public.food_stores(id uuid primary key, name text default 'ร้าน', phone text default '0800000000', address text default 'ที่อยู่',
  business_hours text default '10-20', delivery_area text default 'ในเมือง', promptpay_name text default 'ร้าน', promptpay_id text default '0800000000',
  bank_account_name text, bank_account_number text, payment_qr_path text,
  latitude double precision, longitude double precision, delivery_fee numeric default 20,
  delivery_radius_km numeric default 10, delivery_base_km numeric default 2, delivery_fee_per_km numeric default 5);
create table public.food_menu_items(store_id uuid, is_available boolean default true);
create function internal.food_distance_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision)
returns numeric language sql immutable set search_path = '' as \$\$
  select round((6371 * 2 * asin(least(1, sqrt(power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2)))))::numeric, 2) \$\$;
grant usage on schema public, auth, internal to authenticated, anon;
insert into auth.users values ('$SUPER'), ('$VIEWER'), ('$EDITOR'), ('$NOBODY');
insert into internal.platform_super_admins values ('$SUPER');
insert into public.admin_permissions values ('$VIEWER', 'food', 'view'), ('$EDITOR', 'food', 'edit');
insert into public.food_stores(id, latitude, longitude) values ('$STORE_CM', 18.7883, 98.9853);
insert into public.food_menu_items values ('$STORE_CM', true);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_service_area_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261102140000_zoky_service_area_thailand.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261103100000_zoky_service_area_admin.sql"

db() { run -At -c "$1" 2>&1 | tail -n1; }
as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect() { [[ "$1" == "$2" ]] || { echo "FAIL: $3 (got '$1', want '$2')"; exit 1; }; }
fails() { local out; if out="$(run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
          [[ "$out" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $out)"; exit 1; }; }
inside() { db "select internal.food_in_service_area($1)"; }

# Shape and starting state: same live behaviour as before (Thailand + Maha Sarakham on).
expect "$(db "select count(distinct group_code) from public.food_service_areas where kind = 'province'")" "77" "77 provinces"
expect "$(db "select count(*) from public.food_service_areas where kind = 'country'")" "1" "one country row"
expect "$(db "select string_agg(group_code, ',' order by group_code) from (select distinct group_code from public.food_service_areas where active) x")" "TH,TH-44" "only Thailand and Maha Sarakham start open"
expect "$(db "select count(*) from public.food_service_areas where group_code is null or kind is null")" "0" "every row grouped"
# Re-running keeps admin choices.
run >/dev/null -c "update public.food_service_areas set active = true where group_code = 'TH-50'"
run >/dev/null < "$ROOT/supabase/migrations/20261103100000_zoky_service_area_admin.sql"
expect "$(db "select bool_or(active) from public.food_service_areas where group_code = 'TH-50'")" "t" "re-run keeps Chiang Mai on"
run >/dev/null -c "update public.food_service_areas set active = false where group_code = 'TH-50'"

# Each province contains its own landmark and no other province does.
declare -A PLACE=( [TH-10]="13.7563, 100.5018" [TH-50]="18.7883, 98.9853" [TH-83]="7.8961, 98.2961" [TH-84]="10.0956, 99.8404"
  [TH-91]="6.4887, 99.3047" [TH-71]="15.1508, 98.4531" [TH-20]="13.1590, 100.8056" [TH-43]="17.8805, 102.7465" [TH-44]="16.1847, 103.3007" )
for iso in "${!PLACE[@]}"; do
  expect "$(db "select string_agg(distinct group_code, ',') from public.food_service_areas a where kind = 'province'
                and internal.food_point_in_polygon(${PLACE[$iso]}, a.lats, a.lngs)")" "$iso" "landmark of $iso"
done

# Read access: super admin and Food viewers; others denied.
expect "$(as "$SUPER" "select (public.admin_zoky_service_areas())->>'can_edit'")" "true" "super admin can edit"
expect "$(as "$VIEWER" "select jsonb_array_length((public.admin_zoky_service_areas())->'areas')")" "78" "viewer sees country + 77 provinces"
expect "$(as "$VIEWER" "select (public.admin_zoky_service_areas())->>'can_edit'")" "false" "viewer cannot edit"
expect "$(as "$VIEWER" "select (public.admin_zoky_service_areas())->'areas'->0->>'group_code'")" "TH" "country listed first"
fails "$NOBODY" "select public.admin_zoky_service_areas()" "no permission cannot list" "Not authorized"
fails "" "select public.admin_zoky_service_areas()" "signed out cannot list" "Not authorized"

# Changes: super admin only (Food edit is not enough).
fails "$EDITOR" "select public.admin_zoky_set_service_area('TH-50', true)" "food editor cannot change" "Only the super admin"
fails "$VIEWER" "select public.admin_zoky_set_service_area('TH-50', true)" "viewer cannot change" "Only the super admin"
fails "$SUPER" "select public.admin_zoky_set_service_area('TH-99', true)" "unknown area" "Service area not found"
fails "$SUPER" "select public.admin_zoky_set_service_area('TH-50', null)" "state required" "required"
run -q -c "revoke all on table public.food_service_areas from authenticated" >/dev/null
fails "$EDITOR" "update public.food_service_areas set active = true" "no direct table writes" "permission denied"

# Country off, Chiang Mai on: Bangkok closes, Chiang Mai and Maha Sarakham stay open.
expect "$(as "$SUPER" "select (public.admin_zoky_set_service_area('TH-50', true))->>'changed'")" "true" "open Chiang Mai"
expect "$(as "$SUPER" "select (public.admin_zoky_set_service_area('TH', false))->>'changed'")" "true" "close whole country"
expect "$(inside "13.7563, 100.5018")" "f" "Bangkok closed"
expect "$(inside "18.7883, 98.9853")" "t" "Chiang Mai open"
expect "$(inside "16.1847, 103.3007")" "t" "Maha Sarakham open"
expect "$(db "select internal.food_store_readiness_missing('$STORE_CM') @> array['service_area']")" "f" "Chiang Mai store can publish"
expect "$(as "$SUPER" "select (public.admin_zoky_set_service_area('TH-50', true))->>'changed'")" "false" "no-op is not a change"
expect "$(db "select count(*) from public.audit_log where event_type = 'zoky_service_area_changed'")" "2" "two audited changes"
expect "$(db "select detail->>'name' from public.audit_log where detail->>'group_code' = 'TH-50'")" "เชียงใหม่" "audit names the province"
expect "$(db "select actor_id from public.audit_log where detail->>'group_code' = 'TH' limit 1")" "$SUPER" "audit names the actor"

# Public overview and map boundaries follow the open areas.
expect "$(as "" "select (public.food_service_area_overview())->>'nationwide'")" "false" "overview: not nationwide"
expect "$(as "" "select (select string_agg(x->>'name', ',') from jsonb_array_elements((public.food_service_area_overview())->'areas') x)")" "มหาสารคาม,เชียงใหม่" "overview: open provinces"
expect "$(as "" "select jsonb_array_length((public.food_service_area_boundaries())->'features')")" "2" "map shows two provinces"
expect "$(as "" "select (f->'geometry'->'coordinates'->0->0) = (f->'geometry'->'coordinates'->0->-1) from jsonb_array_elements((public.food_service_area_boundaries())->'features') f limit 1")" "t" "rings are closed"

# Never zero open areas.
expect "$(as "$SUPER" "select (public.admin_zoky_set_service_area('TH-44', false))->>'changed'")" "true" "close Maha Sarakham"
fails "$SUPER" "select public.admin_zoky_set_service_area('TH-50', false)" "last open area stays open" "At least one service area must stay open"
expect "$(inside "18.7883, 98.9853")" "t" "Chiang Mai still open"

# Whole country back on: map returns only the outline.
expect "$(as "$SUPER" "select (public.admin_zoky_set_service_area('TH', true))->>'changed'")" "true" "reopen whole country"
expect "$(as "" "select (public.food_service_area_overview())->>'nationwide'")" "true" "overview: nationwide"
expect "$(as "" "select (public.food_service_area_boundaries())->'features'->0->'properties'->>'code'")" "TH" "map: country outline only"
expect "$(as "" "select jsonb_array_length((public.food_service_area_boundaries())->'features')")" "1" "map: one feature"

# Rollback restores the two original areas and drops the RPCs.
run >/dev/null < "$ROOT/supabase/rollbacks/20261103100000_zoky_service_area_admin_rollback.sql"
expect "$(db "select string_agg(code, ',' order by code) from public.food_service_areas where active")" "maha_sarakham,thailand" "rollback: original areas on"
expect "$(db "select count(*) from public.food_service_areas where kind = 'province'")" "1" "rollback: provinces removed"
expect "$(db "select to_regprocedure('public.admin_zoky_set_service_area(text,boolean)') is null")" "t" "rollback: RPC dropped"
echo "PASS: zoky_service_area_admin_test"
