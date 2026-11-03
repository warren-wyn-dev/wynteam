#!/usr/bin/env bash
# ZOKY order numbers ZF-0036 (Founder 2026-11-04): the sequence continues,
# existing WF numbers stay, 4+ digits, never cut, re-runnable, rollback.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/zoky_order_number_zf_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="zoky_order_number_zf_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
export PGOPTIONS="--client-min-messages=warning"
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
expect() { local got; got="$(run -At -c "$1" 2>&1 | tail -n1)"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create sequence public.food_order_number_seq start with 1 increment by 1;
create function public.food_next_order_number() returns text language sql volatile set search_path = public as $f$
  select 'WF' || lpad(n, greatest(4, length(n)), '0') from (select nextval('public.food_order_number_seq')::text as n) s $f$;
create table public.food_orders(id serial primary key, order_number text not null unique default public.food_next_order_number());
select setval('public.food_order_number_seq', 34);
insert into public.food_orders default values;   -- WF0035, before the change
SQL
run -f "$ROOT/supabase/migrations/20261104120000_zoky_order_number_zf.sql" >/dev/null
run -f "$ROOT/supabase/migrations/20261104120000_zoky_order_number_zf.sql" >/dev/null

expect "insert into public.food_orders default values returning order_number" "ZF-0036" "next order continues the sequence with ZF-"
expect "select string_agg(order_number, ',' order by id) from public.food_orders" "WF0035,ZF-0036" "the earlier order keeps its WF number"
expect "select setval('public.food_order_number_seq', 9998); select string_agg(public.food_next_order_number(), ',') from generate_series(1,2)" "ZF-9999,ZF-10000" "never cut past 9999"
expect "select has_function_privilege('anon', 'public.food_next_order_number()', 'execute')" "f" "anon cannot draw numbers"
expect "select has_function_privilege('authenticated', 'public.food_next_order_number()', 'execute')" "f" "members cannot draw numbers"

run -f "$ROOT/supabase/rollbacks/20261104120000_zoky_order_number_zf_rollback.sql" >/dev/null
expect "insert into public.food_orders default values returning order_number" "WF10001" "rollback numbers new orders WF again"
echo "zoky_order_number_zf: ok"
