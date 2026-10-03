#!/usr/bin/env bash
# WYN-196 behaviour test: delivery radius, distance fee and pin validation.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_delivery_zone_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_delivery_zone_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create function public.food_customer_access_enabled() returns boolean language sql as $$ select auth.uid() is not null $$;
create table public.food_stores(id uuid primary key, delivery_fee numeric(10,2) not null default 0);
create table public.food_customer_addresses(
  id uuid primary key default gen_random_uuid(), user_id uuid not null, label text, recipient_name text,
  recipient_phone text, address text, delivery_note text, is_default boolean default false,
  created_at timestamptz default now(), updated_at timestamptz default now());
create table public.food_orders(id uuid primary key);
create table public.food_menu_items(id uuid);
create table public.food_campaigns(id uuid);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_delivery_zone_v1.sql"

expect_eq()   { local got; got="$(run -At -c "select set_config('test.uid','00000000-0000-0000-0000-0000000000c1',false);" -c "$1" 2>&1 | tail -n1)";
                [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','00000000-0000-0000-0000-0000000000c1',false);" -c "$1" 2>&1)"; then echo "FAIL (expected error): $2"; exit 1; fi
                [[ "$err" == *"$3"* ]] || { echo "FAIL: $2 (wrong error: $err)"; exit 1; }; }

A=00000000-0000-0000-0000-00000000000a; B=00000000-0000-0000-0000-00000000000b
run -c "insert into food_stores(id,delivery_fee) values ('$A',20),('$B',15)" \
    -c "update food_stores set latitude=13.7563, longitude=100.5018, delivery_fee_per_km=8 where id='$A'" >/dev/null
FEE="select distance_km || '|' || delivery_fee from internal.food_delivery_fee"

expect_eq "select coalesce(distance_km::text,'null') || '|' || delivery_fee from internal.food_delivery_fee('$B',null,null)" "null|15.00" "unpinned store keeps its flat fee"
expect_eq "$FEE('$A',13.7653,100.5018)" "1.00|20.00" "inside base distance pays the base fee"
expect_eq "$FEE('$A',13.7923,100.5018)" "4.00|36.00" "4 km pays base + ceil(2 km x 8)"
expect_eq "$FEE('$A',13.8003,100.5018)" "4.89|44.00" "partial km rounds the extra fee up"
expect_fail "$FEE('$A',13.8103,100.5018)" "6 km is outside the default 5 km radius" "outside delivery area"
expect_fail "$FEE('$A',null,null)" "pinned store needs a delivery pin" "delivery location required"
expect_fail "$FEE('$A',95,100)" "invalid latitude is rejected" "delivery location required"
expect_fail "update food_stores set delivery_radius_km=0 where id='$A'" "radius must be positive" "food_stores_delivery_zone_range"
expect_fail "update food_stores set latitude=1, longitude=null where id='$B'" "store pin must be a full pair" "food_stores_location_pair"

# Address pins go through the customer RPC and must be a valid pair.
UPSERT="select public.food_upsert_customer_address(null,'บ้าน','ผู้รับ','0800000000','ที่อยู่',null,true"
expect_fail "$UPSERT,13.7,null)" "half address pin is rejected" "invalid delivery location"
expect_fail "$UPSERT,99,100)" "out-of-range address pin is rejected" "invalid delivery location"
expect_eq "$UPSERT,13.7,100.5) is not null" "t" "valid address pin is saved"
expect_eq "select latitude || ',' || longitude from food_customer_addresses" "13.7,100.5" "address keeps its pin"
expect_eq "$UPSERT,null,null) is not null" "t" "address without a pin is still allowed"

echo "PASS: WYNOS Food delivery zone enforces radius, distance fee and valid pins"
