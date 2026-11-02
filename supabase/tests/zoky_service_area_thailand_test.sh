#!/usr/bin/env bash
# ZOKY nationwide service area (Founder 2026-11-02 "เปิดใช้ทั่วประเทศไทย").
# Applies WYN-211, then the Thailand row, then checks the area answer across
# Thailand (islands and border towns), neighbouring cities, ordering fees,
# store readiness and the rollback. Throwaway local PostgreSQL database.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/zoky_service_area_thailand_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="zoky_service_area_thailand_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

BUYER=00000000-0000-0000-0000-0000000000c0
BKK_STORE=00000000-0000-0000-0000-0000000000f1
VTE_STORE=00000000-0000-0000-0000-0000000000f2

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
  delivery_radius_km numeric default 10, delivery_base_km numeric default 2, delivery_fee_per_km numeric default 5);
create table public.food_menu_items(store_id uuid, is_available boolean default true);
create function internal.food_distance_km(p_lat1 double precision, p_lng1 double precision, p_lat2 double precision, p_lng2 double precision)
returns numeric language sql immutable set search_path = '' as \$\$
  select round((6371 * 2 * asin(least(1, sqrt(power(sin(radians(p_lat2 - p_lat1) / 2), 2)
    + cos(radians(p_lat1)) * cos(radians(p_lat2)) * power(sin(radians(p_lng2 - p_lng1) / 2), 2)))))::numeric, 2) \$\$;
grant usage on schema public, auth, internal to authenticated, anon;
insert into auth.users values ('$BUYER');
insert into public.food_stores(id, latitude, longitude) values ('$BKK_STORE', 13.7465, 100.5348), ('$VTE_STORE', 17.9757, 102.6331);
insert into public.food_menu_items values ('$BKK_STORE', true), ('$VTE_STORE', true);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_service_area_v1.sql"

db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_db() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
inside() { db "select internal.food_in_service_area($1)"; }

BANGKOK="13.7563, 100.5018"
# Before: Maha Sarakham only.
[[ "$(inside "$BANGKOK")" == "f" ]] || { echo "FAIL: Bangkok must be outside before the Thailand area"; exit 1; }

run >/dev/null < "$ROOT/supabase/migrations/20261102140000_zoky_service_area_thailand.sql"
# Re-runnable.
run >/dev/null < "$ROOT/supabase/migrations/20261102140000_zoky_service_area_thailand.sql"
expect_db "select count(*) from public.food_service_areas where code = 'thailand' and active" "1" "Thailand area is active"
expect_db "select count(*) from public.food_service_areas where code = 'maha_sarakham' and active" "1" "Maha Sarakham row untouched"

declare -A IN=(
  [Bangkok]="13.7563, 100.5018" [ChiangMai]="18.7883, 98.9853" [MaeSai]="20.4266, 99.8838"
  [Patong]="7.8961, 98.2961" [Samui]="9.5297, 100.0617" [KoTao]="10.0956, 99.8404" [KoPhangan]="9.7319, 100.0136"
  [KoLipe]="6.4887, 99.3047" [PhiPhi]="7.7407, 98.7784" [KoChang]="12.0563, 102.3224" [KoKood]="11.6564, 102.5644"
  [Betong]="5.7731, 101.0727" [HatYai]="7.0084, 100.4747" [MahaSarakham]="16.1847, 103.3007" [KhonKaen]="16.4419, 102.8360"
  [NongKhaiRiverside]="17.8805, 102.7465" [MukdahanRiverside]="16.5436, 104.7238" [Ubon]="15.2287, 104.8564"
  [Aranyaprathet]="13.6929, 102.5013" [MaeSot]="16.7136, 98.5745"
)
declare -A OUT=(
  [Vientiane]="17.9757, 102.6331" [Savannakhet]="16.5563, 104.7525" [Poipet]="13.6585, 102.5627" [Myawaddy]="16.6893, 98.5097"
  [PhnomPenh]="11.5564, 104.9282" [KualaLumpur]="3.1390, 101.6869" [Yangon]="16.8409, 96.1735" [Hanoi]="21.0278, 105.8342"
)
for k in "${!IN[@]}"; do [[ "$(inside "${IN[$k]}")" == "t" ]] || { echo "FAIL: $k should be inside Thailand"; exit 1; }; done
for k in "${!OUT[@]}"; do [[ "$(inside "${OUT[$k]}")" == "f" ]] || { echo "FAIL: $k should be outside Thailand"; exit 1; }; done
expect_db "select internal.food_in_service_area(null, null)" "f" "no pin is never inside"

# Signed-in area check RPC and ordering fees now work in Bangkok; the store's own radius still applies.
expect_db "select set_config('test.uid','$BUYER',false); set role authenticated; select public.food_service_area_check($BANGKOK)" "t" "Bangkok buyer passes the area check"
expect_db "select set_config('test.uid','$BUYER',false); select (internal.food_delivery_fee('$BKK_STORE', 13.7400, 100.5600)) is not null" "t" "Bangkok store quotes a Bangkok delivery"
if run -c "select set_config('test.uid','$BUYER',false);" -c "select internal.food_delivery_fee('$BKK_STORE', 18.7883, 98.9853)" >/dev/null 2>&1; then
  echo "FAIL: a Bangkok store must not deliver to Chiang Mai (store radius)"; exit 1; fi
if run -c "select set_config('test.uid','$BUYER',false);" -c "select internal.food_delivery_fee('$VTE_STORE', 17.9700, 102.6300)" >/dev/null 2>&1; then
  echo "FAIL: a store pinned in Vientiane must stay outside the service area"; exit 1; fi
expect_db "select internal.food_store_readiness_missing('$BKK_STORE') @> array['service_area']" "f" "Bangkok store is not blocked by the area"
expect_db "select internal.food_store_readiness_missing('$VTE_STORE') @> array['service_area']" "t" "Vientiane store still needs a Thai pin"

# Rollback restores Maha Sarakham-only ordering.
run >/dev/null < "$ROOT/supabase/rollbacks/20261102140000_zoky_service_area_thailand_rollback.sql"
[[ "$(inside "$BANGKOK")" == "f" ]] || { echo "FAIL: rollback must put Bangkok outside again"; exit 1; }
[[ "$(inside "16.1847, 103.3007")" == "t" ]] || { echo "FAIL: rollback keeps Maha Sarakham"; exit 1; }
echo "PASS: zoky_service_area_thailand_test (${#IN[@]} inside, ${#OUT[@]} outside, fees, readiness, rollback)"
