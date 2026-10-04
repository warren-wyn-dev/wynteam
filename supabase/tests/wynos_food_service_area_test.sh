#!/usr/bin/env bash
# WYN-211 behaviour test: WYNOS Food open to everyone, ordering limited to
# Maha Sarakham (delivery pin and store pin inside the province).
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_service_area_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_service_area_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

BUYER=00000000-0000-0000-0000-0000000000c0
DEV=00000000-0000-0000-0000-0000000000d5
IN_STORE=00000000-0000-0000-0000-0000000000f1
OUT_STORE=00000000-0000-0000-0000-0000000000f2
NOPIN_STORE=00000000-0000-0000-0000-0000000000f3

# Places (lat, lng).
MSK_CITY="16.1847, 103.3007"       # Mueang Maha Sarakham
KOSUM="16.2486, 103.0673"          # Kosum Phisai, Maha Sarakham
BORABUE="15.9940, 103.1210"        # Borabue, Maha Sarakham
KHON_KAEN="16.4419, 102.8360"      # Khon Kaen city (next province)
ROI_ET="16.0538, 103.6520"         # Roi Et city (next province)
KANTHARAWICHAI_EDGE_OUT="16.3200, 103.4300"  # Kalasin side, inside the bounding box
BANGKOK="13.7563, 100.5018"

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.developer_accounts(user_id uuid primary key);
create table public.food_rollout_settings(id boolean primary key default true, public_enabled boolean not null default false);
insert into public.food_rollout_settings values (true, false);
create table public.food_stores(id uuid primary key, name text default 'ร้าน', phone text default '0800000000', address text default 'ที่อยู่',
  business_hours text default '10-20', delivery_area text default 'ในเมือง', promptpay_name text default 'ร้าน', promptpay_id text default '0800000000',
  bank_account_name text, bank_account_number text, payment_qr_path text,
  latitude double precision, longitude double precision, delivery_fee numeric default 20,
  delivery_radius_km numeric default 50, delivery_base_km numeric default 2, delivery_fee_per_km numeric default 5);
create table public.food_menu_items(store_id uuid, is_available boolean default true);
-- Same as migrations_wynos_food_delivery_zone_v1.sql.
create function internal.food_distance_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision)
returns numeric language sql immutable set search_path = '' as \$\$
  select round((6371 * 2 * asin(least(1, sqrt(power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2)))))::numeric, 2) \$\$;
grant usage on schema public, auth, internal to authenticated, anon;

insert into auth.users values ('$BUYER'), ('$DEV');
insert into public.developer_accounts values ('$DEV');
insert into public.food_stores(id, latitude, longitude) values ('$IN_STORE', 16.1850, 103.3000), ('$OUT_STORE', 16.4419, 102.8360), ('$NOPIN_STORE', null, null);
insert into public.food_menu_items values ('$IN_STORE', true), ('$OUT_STORE', true), ('$NOPIN_STORE', true);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_service_area_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_service_area_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_db()   { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

inside() { db "select internal.food_in_service_area($1)"; }
for place in "$MSK_CITY" "$KOSUM" "$BORABUE"; do
  [[ "$(inside "$place")" == "t" ]] || { echo "FAIL: $place should be inside Maha Sarakham"; exit 1; }
done
for place in "$KHON_KAEN" "$ROI_ET" "$KANTHARAWICHAI_EDGE_OUT" "$BANGKOK"; do
  [[ "$(inside "$place")" == "f" ]] || { echo "FAIL: $place should be outside Maha Sarakham"; exit 1; }
done
expect_db "select internal.food_in_service_area(null, null)" "f" "no pin is never inside"
expect_db "select cardinality(lats) > 1000 from public.food_service_areas where code = 'maha_sarakham'" "t" "boundary is stored"

# Web gate RPC: signed-in users only, boolean only.
expect_eq "$BUYER" "set role authenticated; select public.food_service_area_check($MSK_CITY)" "t" "buyer in Maha Sarakham"
expect_eq "$BUYER" "set role authenticated; select public.food_service_area_check($KHON_KAEN)" "f" "buyer in Khon Kaen"
expect_eq "" "set role authenticated; select public.food_service_area_check($MSK_CITY)" "f" "signed out gets false"
expect_db "select has_function_privilege('anon', 'public.food_service_area_check(double precision,double precision)', 'execute')" "f" "anon cannot call it"
expect_db "select has_table_privilege('authenticated', 'public.food_service_areas', 'select')" "f" "boundary table has no direct access"

# Ordering (quote/create both go through internal.food_delivery_fee).
expect_eq "$BUYER" "select delivery_fee from internal.food_delivery_fee('$IN_STORE', $MSK_CITY)" "20" "in-province store to in-province pin works"
expect_fail "$BUYER" "select * from internal.food_delivery_fee('$IN_STORE', $KHON_KAEN)" "pin in Khon Kaen is refused" "outside service area"
expect_fail "$BUYER" "select * from internal.food_delivery_fee('$IN_STORE', $BANGKOK)" "pin in Bangkok is refused" "outside service area"
expect_fail "$BUYER" "select * from internal.food_delivery_fee('$OUT_STORE', $KHON_KAEN)" "store outside the province cannot sell" "store is outside the service area"
expect_fail "$BUYER" "select * from internal.food_delivery_fee('$NOPIN_STORE', $MSK_CITY)" "store without a pin cannot sell" "store is outside the service area"
expect_fail "$BUYER" "select * from internal.food_delivery_fee('$IN_STORE', null, null)" "delivery pin is still required" "delivery location required"
# Developers keep testing from anywhere.
expect_eq "$DEV" "select delivery_fee is not null from internal.food_delivery_fee('$OUT_STORE', $KHON_KAEN)" "t" "developer can test outside the province"

# Publishing needs a store pin inside the province.
expect_db "select 'service_area' = any(internal.food_store_readiness_missing('$IN_STORE'))" "f" "in-province store is ready"
expect_db "select 'service_area' = any(internal.food_store_readiness_missing('$OUT_STORE'))" "t" "out-of-province store is not ready"
expect_db "select 'service_area' = any(internal.food_store_readiness_missing('$NOPIN_STORE'))" "t" "unpinned store is not ready"

# Founder opened Food to everyone.
expect_db "select public_enabled from public.food_rollout_settings" "t" "public rollout switched on"

echo "PASS: WYN-211 WYNOS Food service area (Maha Sarakham)"
