#!/usr/bin/env bash
# ZOKY Merchant busy mode (Founder 2026-11-03, "ทำ ก กับ ข"): order staff add
# 5-60 extra minutes for 15-240 minutes; customers and pickup slots follow;
# columns change only through the RPC; rollback restores the old slots.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/zoky_merchant_busy_mode_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="zoky_merchant_busy_mode_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
export PGOPTIONS="--client-min-messages=warning"
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "$1" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi; [[ "$err" == *"$2"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

STORE=00000000-0000-0000-0000-0000000000a1
OWNER=00000000-0000-0000-0000-0000000000c1
ORDERS=00000000-0000-0000-0000-0000000000c2
DELIVERY=00000000-0000-0000-0000-0000000000c3
BUYER=00000000-0000-0000-0000-0000000000d1

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid', true), '')::uuid \$\$;
create table public.food_stores(id uuid primary key, name text, is_published boolean default true, pickup_enabled boolean default true,
  pickup_prep_minutes integer not null default 15, business_schedule jsonb default '{"weekly":{}}');
grant select, update on public.food_stores to authenticated;
create table public.test_roles(store_id uuid, user_id uuid, role text);
create function public.merchant_has_store_role(p_store uuid, p_roles text[]) returns boolean language sql stable as
  \$\$ select exists(select 1 from public.test_roles r where r.store_id = p_store and r.user_id = auth.uid() and r.role = any(p_roles)) \$\$;
-- Open all day: slots run from now + wait to the end of the Bangkok day.
create function internal.food_store_effectively_open(p_store uuid, p_at timestamptz) returns boolean language sql stable as \$\$ select true \$\$;
insert into public.food_stores(id, name) values ('$STORE', 'ร้านทดสอบ');
insert into public.test_roles values ('$STORE', '$OWNER', 'owner'), ('$STORE', '$ORDERS', 'orders'), ('$STORE', '$DELIVERY', 'delivery');
SQL
run -f "$ROOT/supabase/migrations/20261104100000_zoky_merchant_busy_mode.sql" >/dev/null
# Re-runnable.
run -f "$ROOT/supabase/migrations/20261104100000_zoky_merchant_busy_mode.sql" >/dev/null

NOW="timestamptz '2026-11-04 03:02:00+00'"   # 10:02 Bangkok
FIRST="select min(s) from internal.food_pickup_slots('$STORE', $NOW) s"
expect "$FIRST" "2026-11-04 03:30:00+00" "normal first pickup slot is now + 15 min rounded up to 15"
expect "select busy_extra_minutes || ':' || coalesce(busy_until::text, '-') from public.food_stores" "0:-" "off by default"

# Who may switch it.
expect_fail "set test.uid='$BUYER'; select public.food_store_set_busy('$STORE', 20, 60)" "order management role required" "a customer cannot"
expect_fail "set test.uid='$DELIVERY'; select public.food_store_set_busy('$STORE', 20, 60)" "order management role required" "delivery-only staff cannot"
expect_fail "set test.uid='$ORDERS'; select public.food_store_set_busy('$STORE', 90, 60)" "invalid_busy_minutes" "more than 60 extra minutes"
expect_fail "set test.uid='$ORDERS'; select public.food_store_set_busy('$STORE', 2, 60)" "invalid_busy_minutes" "fewer than 5 extra minutes"
expect_fail "set test.uid='$ORDERS'; select public.food_store_set_busy('$STORE', 20, 5)" "invalid_busy_duration" "too short"
expect_fail "set test.uid='$ORDERS'; select public.food_store_set_busy('$STORE', 20, 600)" "invalid_busy_duration" "too long"
expect "set test.uid='$ORDERS'; select public.food_store_set_busy('$STORE', 20, 60) between now() + interval '59 minutes' and now() + interval '61 minutes'" "t" "orders staff turn it on for an hour"
expect "select busy_extra_minutes from public.food_stores" "20" "extra minutes stored"

# Direct writes are refused; the RPC is the only way in.
expect_fail "set test.uid='$OWNER'; update public.food_stores set busy_extra_minutes = 0" "use food_store_set_busy" "direct update refused"
expect_fail "set test.uid='$OWNER'; update public.food_stores set busy_until = now() + interval '9 hours'" "use food_store_set_busy" "direct extension refused"
expect "set test.uid='$OWNER'; update public.food_stores set name = 'ร้านใหม่' returning name" "ร้านใหม่" "other columns still editable"

# Pickup slots wait for the busy minutes while busy mode lasts.
run -c "update public.food_stores set busy_until = timestamptz '2026-11-04 04:00:00+00'" >/dev/null
expect "$FIRST" "2026-11-04 03:45:00+00" "busy: first slot now + 15 + 20 rounded up"
run -c "update public.food_stores set busy_until = timestamptz '2026-11-04 03:00:00+00'" >/dev/null
expect "$FIRST" "2026-11-04 03:30:00+00" "expired busy mode no longer delays"
expect "select internal.food_store_busy_extra(20, $NOW + interval '1 minute', $NOW) || ',' || internal.food_store_busy_extra(20, $NOW, $NOW) || ',' || internal.food_store_busy_extra(20, null, $NOW)" "20,0,0" "busy extra helper"

# Turning it off clears both columns.
expect "set test.uid='$OWNER'; select coalesce(public.food_store_set_busy('$STORE', 0, null)::text, 'off')" "off" "owner turns it off"
expect "select busy_extra_minutes || ':' || coalesce(busy_until::text, '-') from public.food_stores" "0:-" "cleared"

# Grants: anon cannot call it.
expect "select has_function_privilege('anon', 'public.food_store_set_busy(uuid,integer,integer)', 'execute')" "f" "anon has no execute"
expect "select has_function_privilege('authenticated', 'public.food_store_set_busy(uuid,integer,integer)', 'execute')" "t" "authenticated may call (role checked inside)"

# Rollback restores the original slots and removes the columns.
run -f "$ROOT/supabase/rollbacks/20261104100000_zoky_merchant_busy_mode_rollback.sql" >/dev/null
expect "$FIRST" "2026-11-04 03:30:00+00" "rollback slots"
expect "select count(*) from information_schema.columns where table_name = 'food_stores' and column_name like 'busy%'" "0" "rollback columns"
expect "select count(*) from pg_proc where proname in ('food_store_set_busy', 'food_stores_busy_guard', 'food_store_busy_extra')" "0" "rollback functions"
echo "zoky_merchant_busy_mode: ok"
