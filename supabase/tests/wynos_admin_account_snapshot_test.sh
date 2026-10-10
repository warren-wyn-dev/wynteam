#!/usr/bin/env bash
# SQL integration test for WYNOS Admin Account Snapshot on disposable Postgres.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PSQL="psql"
DB="wyn_account_snapshot_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
SOCIAL=00000000-0000-0000-0000-0000000000c0
FOOD=00000000-0000-0000-0000-0000000000d0
MERCHANT=00000000-0000-0000-0000-0000000000e0
MAPS=00000000-0000-0000-0000-0000000000f0
EMPTY=00000000-0000-0000-0000-000000000011
MISSING=00000000-0000-0000-0000-000000000099

run >/dev/null <<SQL
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
create schema auth;
create function auth.uid() returns uuid language sql stable
  as \$\$ select nullif(current_setting('test.uid', true), '')::uuid \$\$;
create table auth.users (id uuid primary key, created_at timestamptz not null default now());
create table public.profiles (id uuid primary key, username text, platform_role text not null default 'user');
create table public.food_orders (buyer_id uuid);
create table public.food_customer_addresses (user_id uuid);
create table public.merchant_users (user_id uuid, active boolean not null);
create table public.merchant_applications (user_id uuid, status text not null);
create table public.merchant_memberships (user_id uuid, active boolean not null);
create table public.wynos_saved_places (user_id uuid);
create table public.wynos_place_suggestions (user_id uuid);
create table public.wynos_place_photos (user_id uuid);
grant usage on schema public, auth to authenticated, anon;
insert into auth.users(id)
values ('$ADMIN'), ('$MOD'), ('$SOCIAL'), ('$FOOD'), ('$MERCHANT'), ('$MAPS'), ('$EMPTY');
insert into public.profiles (id, username, platform_role)
values ('$ADMIN','admin','admin'), ('$MOD','mod','moderator'),
 ('$SOCIAL','social_only','user'), ('$FOOD','food_user','user'),
 ('$MERCHANT','merchant_user','user'), ('$MAPS','maps_user','user');
SQL

# Migration is replay-safe and SQL authorization is independent of the UI.
run -f "$ROOT/supabase/migrations_wynos_admin_account_snapshot_v1.sql" >/dev/null
run -f "$ROOT/supabase/migrations_wynos_admin_account_snapshot_v1.sql" >/dev/null
actor() { run -At -c "select set_config('test.uid', '$1', false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
eq() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 (got '$2', expected '$3')" >&2; exit 1; fi; echo "PASS: $1"; }
fail() {
 local out
 if out="$(run -c "select set_config('test.uid', '$2', false);" -c "set role authenticated;" -c "$3" 2>&1)"; then
   echo "FAIL: $1 unexpectedly allowed" >&2; exit 1
 fi
 if [[ "$out" != *"$4"* ]]; then echo "FAIL: $1 wrong error: $out" >&2; exit 1; fi
 echo "PASS: $1"
}
signal() { actor "$1" "select public.admin_wynos_account_snapshot('$2')->'signals'->>'$3'"; }

eq "anon RPC EXECUTE revoked" "$(run -At -c "select has_function_privilege('anon', 'public.admin_wynos_account_snapshot(uuid)', 'execute')")" "f"
eq "authenticated RPC requires SQL role guard" "$(run -At -c "select has_function_privilege('authenticated', 'public.admin_wynos_account_snapshot(uuid)', 'execute')")" "t"
fail "user denied even for own account" "$SOCIAL" "select public.admin_wynos_account_snapshot('$SOCIAL')" "Not authorized"
fail "user denied when targeting admin" "$SOCIAL" "select public.admin_wynos_account_snapshot('$ADMIN')" "Not authorized"
fail "moderator denied" "$MOD" "select public.admin_wynos_account_snapshot('$SOCIAL')" "Not authorized"
fail "missing authentication denied" "" "select public.admin_wynos_account_snapshot('$SOCIAL')" "Not authorized"

eq "Social profile true" "$(signal "$ADMIN" "$SOCIAL" social_profile)" "true"
eq "Social-only no Food" "$(signal "$ADMIN" "$SOCIAL" food_activity)" "false"
eq "Social-only no Merchant" "$(signal "$ADMIN" "$SOCIAL" merchant_record)" "false"
eq "Social-only no Maps" "$(signal "$ADMIN" "$SOCIAL" maps_activity)" "false"
eq "bare Auth user has no Social profile evidence" "$(signal "$ADMIN" "$EMPTY" social_profile)" "false"
eq "bare Auth user has central ID" "$(actor "$ADMIN" "select public.admin_wynos_account_snapshot('$EMPTY')->>'account_id'")" "$EMPTY"
eq "absent Auth account yields null" "$(actor "$ADMIN" "select public.admin_wynos_account_snapshot('$MISSING') is null")" "t"

run -c "insert into public.food_orders(buyer_id) values ('$FOOD')" >/dev/null
eq "Food order detected" "$(signal "$ADMIN" "$FOOD" food_activity)" "true"
eq "Food order does not create Merchant" "$(signal "$ADMIN" "$FOOD" merchant_record)" "false"
run -c "insert into public.food_customer_addresses(user_id) values ('$SOCIAL')" >/dev/null
eq "Food address detected" "$(signal "$ADMIN" "$SOCIAL" food_activity)" "true"

run -c "insert into public.merchant_users(user_id,active) values ('$MERCHANT',false)" >/dev/null
eq "inactive Merchant identity counted as evidence" "$(signal "$ADMIN" "$MERCHANT" merchant_record)" "true"
run -c "delete from public.merchant_users" -c "insert into public.merchant_applications(user_id,status) values ('$MERCHANT','pending')" >/dev/null
eq "pending Merchant application counted as evidence" "$(signal "$ADMIN" "$MERCHANT" merchant_record)" "true"
run -c "delete from public.merchant_applications" -c "insert into public.merchant_memberships(user_id,active) values ('$MERCHANT',false)" >/dev/null
eq "inactive Merchant membership counted as evidence" "$(signal "$ADMIN" "$MERCHANT" merchant_record)" "true"

run -c "insert into public.wynos_saved_places(user_id) values ('$MAPS')" >/dev/null
eq "Maps saved place detected" "$(signal "$ADMIN" "$MAPS" maps_activity)" "true"
run -c "delete from public.wynos_saved_places" -c "insert into public.wynos_place_suggestions(user_id) values ('$MAPS')" >/dev/null
eq "Maps suggestion detected" "$(signal "$ADMIN" "$MAPS" maps_activity)" "true"
run -c "delete from public.wynos_place_suggestions" -c "insert into public.wynos_place_photos(user_id) values ('$MAPS')" >/dev/null
eq "Maps photo detected" "$(signal "$ADMIN" "$MAPS" maps_activity)" "true"

run -c "update public.profiles set platform_role='user' where id='$ADMIN'" >/dev/null
fail "revoked admin denied immediately" "$ADMIN" "select public.admin_wynos_account_snapshot('$SOCIAL')" "Not authorized"

eq "central accounts not duplicated" "$(run -At -c 'select count(*) from auth.users')" "7"
eq "Social not auto-Merchant" "$(run -At -c "select count(*) from public.merchant_users where user_id='$SOCIAL'")" "0"
eq "Social not auto-Maps" "$(run -At -c "select count(*) from public.wynos_saved_places where user_id='$SOCIAL'")" "0"
echo "PASS: WYNOS Admin Account Snapshot security and activity integration tests"
