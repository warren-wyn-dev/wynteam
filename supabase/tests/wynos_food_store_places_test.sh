#!/usr/bin/env bash
# WYN-197 behaviour test: per-store place list and customer place search.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_store_places_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_store_places_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

A=00000000-0000-0000-0000-00000000000a   # store A (published)
B=00000000-0000-0000-0000-00000000000b   # store B (not published)
MA=00000000-0000-0000-0000-0000000000a1  # manager of A
DA=00000000-0000-0000-0000-0000000000a2  # delivery staff of A
MB=00000000-0000-0000-0000-0000000000b1  # manager of B
C=00000000-0000-0000-0000-0000000000c1   # customer
DEV=00000000-0000-0000-0000-0000000000d1 # developer account

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.food_stores(id uuid primary key, is_published boolean not null default false);
create table public.test_roles(user_id uuid, store_id uuid, role text);
create function public.food_customer_access_enabled() returns boolean language sql stable as \$\$ select auth.uid() is not null \$\$;
create function public.food_public_access_enabled() returns boolean language sql stable as \$\$ select true \$\$;
create function public.is_developer_account() returns boolean language sql stable as \$\$ select auth.uid() = '$DEV'::uuid \$\$;
create function public.food_has_merchant_access(p_store_id uuid default null) returns boolean language sql stable security definer as
  \$\$ select exists (select 1 from public.test_roles r where r.user_id = auth.uid() and r.store_id = p_store_id) \$\$;
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[]) returns boolean language sql stable security definer as
  \$\$ select exists (select 1 from public.test_roles r where r.user_id = auth.uid() and r.store_id = p_store_id and r.role = any(p_roles)) \$\$;
create function public.food_touch_updated_at() returns trigger language plpgsql as \$\$ begin new.updated_at = now(); return new; end \$\$;
grant usage on schema public, auth to authenticated, anon;
grant select on public.food_stores, public.test_roles to authenticated;
insert into public.food_stores values ('$A', true), ('$B', false);
insert into public.test_roles values ('$MA','$A','manager'), ('$DA','$A','delivery'), ('$MB','$B','manager');
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_store_places_v1.sql"

# as <uid> <sql>: run as an authenticated user, last output line only.
as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

ADD="insert into food_store_places(store_id,name,detail,latitude,longitude) values"
expect_eq "$MA" "$ADD ('$A','หอพัก ABC','ตึก 2',13.76,100.50),('$A','คอนโด Sky',null,13.77,100.51),('$A','100% Plaza',null,13.78,100.52) returning 1" "1" "manager adds places to their store"
expect_eq "$MB" "$ADD ('$B','หอพัก B',null,13.70,100.40) returning 1" "1" "manager of B adds a place to B"
expect_fail "$DA" "$ADD ('$A','จุดใหม่',null,13.7,100.5)" "delivery staff cannot add places" "row-level security"
expect_fail "$MB" "$ADD ('$A','แอบเพิ่ม',null,13.7,100.5)" "manager of B cannot add to A" "row-level security"
expect_fail "$MA" "$ADD ('$A','   ',null,13.7,100.5)" "blank name is rejected" "food_store_places_name_length"
expect_fail "$MA" "$ADD ('$A','จุด',null,95,100.5)" "invalid latitude is rejected" "food_store_places_location_range"
expect_eq "$MB" "select count(*) from food_store_places" "1" "manager of B sees only B's places"
expect_eq "$MB" "with u as (update food_store_places set name='x' where store_id='$A' returning 1) select count(*) from u" "0" "manager of B cannot rename A's places"
expect_eq "$MB" "with d as (delete from food_store_places where store_id='$A' returning 1) select count(*) from d" "0" "manager of B cannot delete A's places"
expect_eq "$C" "select count(*) from food_store_places" "0" "customers cannot read the table directly"

S="select string_agg(name, ',' order by name) from public.food_search_store_places"
expect_eq "$C" "$S('$A','หอ')" "หอพัก ABC" "customer finds a place by name"
expect_eq "$C" "$S('$A','ตึก 2')" "หอพัก ABC" "customer finds a place by its detail"
expect_eq "$C" "$S('$A','%')" "100% Plaza" "LIKE wildcards are matched literally"
expect_eq "$C" "select count(*) from public.food_search_store_places('$A','')" "3" "empty query lists the store's places"
expect_eq "$C" "$S('$A','หอพัก B')" "" "search never returns another store's places"
expect_eq "$MA" "update food_store_places set is_active=false where name='คอนโด Sky' returning 1" "1" "manager hides a place"
expect_eq "$C" "select count(*) from public.food_search_store_places('$A','')" "2" "hidden places are not offered to customers"
expect_fail "$C" "select * from public.food_search_store_places('$B','')" "unpublished store is not searchable" "store is not accepting orders"
expect_eq "$DEV" "$S('$B','')" "หอพัก B" "developers can search an unpublished store"
expect_fail "" "select * from public.food_search_store_places('$A','')" "signed-out users cannot search" "food customer access required"
expect_eq "" "select has_function_privilege('anon','public.food_search_store_places(uuid,text)','execute')" "f" "anon cannot call the search RPC"
expect_eq "" "select has_table_privilege('anon','public.food_store_places','select')" "f" "anon has no table privilege"

echo "PASS: WYNOS Food store places are per-store and customer search is scoped"
