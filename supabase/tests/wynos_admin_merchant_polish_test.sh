#!/usr/bin/env bash
# WYN-214 behaviour test: admin store detail shows pin, service area and
# readiness; admin order list filters refunds and payments to review.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_admin_merchant_polish_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_admin_merchant_polish_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
USER1=00000000-0000-0000-0000-0000000000c0
IN_STORE=00000000-0000-0000-0000-0000000000f1
OUT_STORE=00000000-0000-0000-0000-0000000000f2

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, username text, display_name text, platform_role text not null default 'user');
create function internal.current_platform_role() returns text language sql stable security definer set search_path = public as
  \$\$ select platform_role from public.profiles where id = auth.uid() \$\$;
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, created_at timestamptz default now());
create table public.food_stores(id uuid primary key, name text, slug text, phone text, address text, business_hours text,
  is_open boolean default false, is_published boolean default false, admin_suspended_at timestamptz, admin_suspended_reason text,
  admin_suspended_by uuid, created_at timestamptz default now(), merchant_account_id uuid,
  latitude double precision, longitude double precision, delivery_radius_km numeric default 5);
create table public.food_orders(id uuid primary key default gen_random_uuid(), order_number text, store_id uuid, status text,
  payment_status text, refund_status text default 'none', recipient_name text, recipient_phone text, total numeric,
  created_at timestamptz default now(), delivered_at timestamptz);
-- Stand-ins for WYN-211's area check and the store readiness list.
create function internal.food_in_service_area(p_lat double precision, p_lng double precision) returns boolean language sql stable as
  \$\$ select p_lat is not null and p_lat between 15.4 and 16.7 and p_lng between 102.8 and 103.6 \$\$;
create function internal.food_store_readiness_missing(p_store_id uuid) returns text[] language sql stable as
  \$\$ select case when internal.food_in_service_area(s.latitude, s.longitude) then array[]::text[] else array['service_area'] end
     from public.food_stores s where s.id = p_store_id \$\$;
grant usage on schema public, auth, internal to authenticated, anon;

insert into auth.users values ('$ADMIN'), ('$MOD'), ('$USER1');
insert into public.profiles(id, username, platform_role) values ('$ADMIN','admin','admin'), ('$MOD','mod','moderator'), ('$USER1','u','user');
insert into public.food_stores(id, name, latitude, longitude) values ('$IN_STORE','ในเขต',16.18,103.30), ('$OUT_STORE','นอกเขต',null,null);
insert into public.food_orders(order_number, store_id, status, payment_status, refund_status) values
  ('1','$IN_STORE','cancelled','paid','pending'), ('2','$IN_STORE','cancelled','paid','failed'),
  ('3','$IN_STORE','cancelled','refunded','refunded'), ('4','$IN_STORE','pending_acceptance','submitted','none'),
  ('5','$IN_STORE','preparing','issue','none'), ('6','$IN_STORE','delivered','paid','none');
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_admin_merchant_polish_v1.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_admin_merchant_polish_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

D_IN="public.admin_food_store_detail('$IN_STORE')"
D_OUT="public.admin_food_store_detail('$OUT_STORE')"
expect_eq "$MOD" "select ($D_IN)->>'in_service_area'" "true" "moderator sees the store is inside the area"
expect_eq "$ADMIN" "select ($D_IN)->>'latitude'" "16.18" "store pin latitude"
expect_eq "$ADMIN" "select ($D_IN)->'readiness_missing'" "[]" "nothing missing for the pinned store"
expect_eq "$ADMIN" "select ($D_OUT)->>'in_service_area'" "false" "unpinned store is outside"
expect_eq "$ADMIN" "select ($D_OUT)->'readiness_missing'" '["service_area"]' "unpinned store needs a pin in the area"
expect_fail "$USER1" "select $D_IN" "users cannot read store detail" "Not authorized"

L="select string_agg(order_number, ',' order by order_number) from public.admin_food_orders"
expect_eq "$ADMIN" "$L(null, 'refund_pending')" "1,2" "refund requested or failed"
expect_eq "$ADMIN" "$L(null, 'payment_review')" "4,5" "slip waiting or payment issue"
expect_eq "$ADMIN" "$L(null, 'delivered')" "6" "status filters still work"
expect_fail "$ADMIN" "select * from public.admin_food_orders(null, 'nope')" "unknown filter rejected" "Invalid order status"
expect_fail "$MOD" "select * from public.admin_food_orders(null, 'refund_pending')" "moderators cannot list orders" "Only admins can view Food orders"

echo "PASS: WYN-214 admin merchant polish"
