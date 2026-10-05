#!/usr/bin/env bash
# WYNOS Maps saved places behaviour test: owner-only Home/Work/Favorites.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_maps_saved_places_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_maps_saved_places_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

A=00000000-0000-0000-0000-0000000000a1
B=00000000-0000-0000-0000-0000000000b1

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key);
create table public.wynos_places(id text primary key, is_active boolean not null default true);
create function public.food_touch_updated_at() returns trigger language plpgsql as \$\$ begin new.updated_at = now(); return new; end \$\$;
grant usage on schema public, auth to authenticated, anon;
insert into public.profiles values ('$A'), ('$B');
insert into public.wynos_places values ('wynos_place_live', true), ('wynos_place_hidden', false);
SQL

run -f "$ROOT/supabase/migrations_wynos_maps_saved_places_v1.sql" >/dev/null

as_user() { # uid sql
  run -At <<SQL
set role authenticated;
select set_config('test.uid', '$1', false);
$2
SQL
}
expect_error() { # label uid sql pattern
  local out
  if out=$(as_user "$2" "$3" 2>&1); then echo "FAIL $1: expected an error"; exit 1; fi
  echo "$out" | grep -q "$4" || { echo "FAIL $1: wrong error: $out"; exit 1; }
  echo "PASS $1"
}
expect_eq() { # label actual expected
  [ "$2" = "$3" ] || { echo "FAIL $1: got '$2', want '$3'"; exit 1; }
  echo "PASS $1"
}
last() { tail -n 1; }

expect_error "anon cannot list" "" "select count(*) from public.wynos_saved_places_list();" "authentication required"
anon_exec=$(run -At -c "select has_function_privilege('anon','public.wynos_saved_places_list()','execute')")
expect_eq "anon has no execute grant" "$anon_exec" "f"
expect_error "table is not readable directly" "$A" "select count(*) from public.wynos_saved_places;" "permission denied"

as_user "$A" "select public.wynos_save_place('home','', 'wynos_place_live','หอพัก A','ขามเรียง',16.24,103.25);" >/dev/null
as_user "$A" "select public.wynos_save_place('home','บ้านใหม่', null,'บ้านใหม่',null,16.30,103.30);" >/dev/null
homes=$(as_user "$A" "select count(*)||':'||max(name)||':'||max(label) from public.wynos_saved_places_list() where kind='home';" | last)
expect_eq "home is replaced, not duplicated" "$homes" "1:บ้านใหม่:บ้านใหม่"

as_user "$A" "select public.wynos_save_place('work','', null,'คณะวิทยาการ',null,16.25,103.26);" >/dev/null
work_label=$(as_user "$A" "select label from public.wynos_saved_places_list() where kind='work';" | last)
expect_eq "work gets a default Thai label" "$work_label" "ที่ทำงาน"

first=$(as_user "$A" "select public.wynos_save_place('favorite','', 'wynos_place_hidden','ร้านกาแฟ',null,16.2401,103.2501);" | last)
again=$(as_user "$A" "select public.wynos_save_place('favorite','', null,'ร้านกาแฟ',null,16.2401,103.2501);" | last)
expect_eq "same favorite is reused" "$again" "$first"
hidden_link=$(as_user "$A" "select coalesce(place_id,'none') from public.wynos_saved_places_list() where id='$first';" | last)
expect_eq "hidden places are not linked" "$hidden_link" "none"

order=$(as_user "$A" "select string_agg(kind, ',') from public.wynos_saved_places_list();" | last)
expect_eq "list orders home, work, then favorites" "$order" "home,work,favorite"

b_count=$(as_user "$B" "select count(*) from public.wynos_saved_places_list();" | last)
expect_eq "another user sees none of them" "$b_count" "0"
b_delete=$(as_user "$B" "select public.wynos_delete_saved_place('$first');" | last)
expect_eq "another user cannot delete them" "$b_delete" "f"

expect_error "rejects bad kind" "$A" "select public.wynos_save_place('office','', null,'x',null,16,103);" "invalid saved place kind"
expect_error "rejects bad location" "$A" "select public.wynos_save_place('favorite','', null,'x',null,95,103);" "invalid saved place location"
expect_error "rejects empty name" "$A" "select public.wynos_save_place('favorite','', null,'   ',null,16,103);" "saved place name required"

as_user "$B" "select count(public.wynos_save_place('favorite','', null,'fav '||g, null, 16 + g / 1000.0, 103)) from generate_series(1, 50) g;" >/dev/null
expect_error "favorites are capped at 50" "$B" "select public.wynos_save_place('favorite','', null,'one more',null,17,104);" "saved place limit reached"

a_delete=$(as_user "$A" "select public.wynos_delete_saved_place('$first');" | last)
expect_eq "owner can delete" "$a_delete" "t"

echo "wynos_maps_saved_places_test: all checks passed"
