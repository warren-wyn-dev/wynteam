#!/usr/bin/env bash
# Behaviour test for supabase/migrations_wynos_push_app_routing_v1.sql on a
# throwaway local PostgreSQL database: push_tokens.app accepts only the three
# WYNOS apps (or NULL for older tokens), and Food order numbers become
# 4 digits without ever being cut past 9999. The migration runs twice to
# prove it is re-runnable.
#
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_push_app_routing_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_push_app_routing_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
create table public.push_tokens(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token text not null unique,
  platform text not null
);
insert into public.push_tokens(user_id, token, platform) values (gen_random_uuid(), 'legacy', 'web');
create sequence public.food_order_number_seq start with 1 increment by 1;
select setval('public.food_order_number_seq', 14);
SQL

run -f "$ROOT/supabase/migrations_wynos_push_app_routing_v1.sql" >/dev/null
run -f "$ROOT/supabase/migrations_wynos_push_app_routing_v1.sql" >/dev/null

fail=0
check() {
  local name="$1" sql="$2" expected="$3" actual
  actual=$(run -tA -c "$sql" 2>&1 || true)
  if [ "$actual" = "$expected" ]; then echo "PASS $name"; else echo "FAIL $name: expected [$expected] got [$actual]"; fail=1; fi
}

check "older token keeps app NULL" "select coalesce(app,'null') from public.push_tokens where token='legacy'" "null"
check "social/food/merchant accepted" \
  "insert into public.push_tokens(user_id,token,platform,app) values (gen_random_uuid(),'s','web','social'),(gen_random_uuid(),'f','web','food'),(gen_random_uuid(),'m','web','merchant'); select count(*) from public.push_tokens where app is not null" "3"
check "unknown app rejected" \
  "do \$\$ begin insert into public.push_tokens(user_id,token,platform,app) values (gen_random_uuid(),'x','web','admin'); raise exception 'accepted'; exception when check_violation then null; end \$\$; select 'rejected'" "rejected"
check "next order is WF0015" "select public.food_next_order_number()" "WF0015"
check "WF9999 then WF10000, never cut" \
  "select setval('public.food_order_number_seq', 9998); select string_agg(public.food_next_order_number(), ',') from generate_series(1,2)" "9998
WF9999,WF10000"
check "WF123456 past six digits" \
  "select setval('public.food_order_number_seq', 123455); select public.food_next_order_number()" "123455
WF123456"

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || { echo "SOME CHECKS FAILED"; exit 1; }
