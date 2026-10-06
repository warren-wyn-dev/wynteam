#!/usr/bin/env bash
# Merchant QA regression: complete sales report aggregation and access control.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_merchant_sales_report_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

OWNER=00000000-0000-0000-0000-0000000000d1
STAFF=00000000-0000-0000-0000-0000000000d2
STRANGER=00000000-0000-0000-0000-0000000000d9
ACCOUNT=00000000-0000-0000-0000-0000000000e1
OTHER_ACCOUNT=00000000-0000-0000-0000-0000000000e2
STORE=00000000-0000-0000-0000-0000000000f1
OTHER=00000000-0000-0000-0000-0000000000f2

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;

create table public.merchant_memberships(
  merchant_account_id uuid,
  user_id uuid,
  role text,
  active boolean default true,
  primary key (merchant_account_id, user_id)
);
create table public.food_stores(id uuid primary key, merchant_account_id uuid);
create table public.food_staff(store_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_orders(
  id uuid primary key default gen_random_uuid(),
  store_id uuid,
  status text,
  total numeric,
  delivered_at timestamptz,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);
create table public.food_order_items(
  id uuid primary key default gen_random_uuid(),
  order_id uuid,
  item_name text,
  quantity integer
);

create function public.food_has_merchant_access(p_store_id uuid default null)
returns boolean language sql stable security definer set search_path = 'public' as \$\$
  select auth.uid() is not null and (
    exists (
      select 1
      from public.food_stores s
      join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
      where mm.user_id = auth.uid() and mm.active and (p_store_id is null or s.id = p_store_id)
    )
    or exists (
      select 1 from public.food_staff fs
      where fs.user_id = auth.uid() and fs.active and (p_store_id is null or fs.store_id = p_store_id)
    )
  )
\$\$;

grant usage on schema public, auth to authenticated, anon;
insert into public.merchant_memberships values
  ('$ACCOUNT','$OWNER','owner',true),
  ('$OTHER_ACCOUNT','$STRANGER','owner',true);
insert into public.food_stores values ('$STORE','$ACCOUNT'), ('$OTHER','$OTHER_ACCOUNT');
insert into public.food_staff values ('$STORE','$STAFF','orders',true);

with inserted as (
  insert into public.food_orders(store_id,status,total,delivered_at)
  values
    ('$STORE','delivered',100,(((now() at time zone 'Asia/Bangkok')::date + time '00:30') at time zone 'Asia/Bangkok')),
    ('$STORE','delivered',200,(((now() at time zone 'Asia/Bangkok')::date + time '23:30') at time zone 'Asia/Bangkok')),
    ('$STORE','delivered',300,((((now() at time zone 'Asia/Bangkok')::date - 40) + time '12:00') at time zone 'Asia/Bangkok'))
  returning id,total
)
insert into public.food_order_items(order_id,item_name,quantity)
select id, case when total = 200 then 'ชาไทย' else 'ผัดไทย' end,
       case when total = 100 then 1 when total = 200 then 2 else 2 end
from inserted;

insert into public.food_orders(store_id,status,total,delivered_at)
values ('$STORE','cancelled',999,now()), ('$OTHER','delivered',9999,now());
SQL

run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_sales_report_v1.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_sales_report_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect_eq() { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
  [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

R="public.merchant_sales_report('$STORE')"

expect_eq "$OWNER" "select ($R)->>'today_orders'" "2" "two delivered orders count on the Bangkok day"
expect_eq "$OWNER" "select (($R)->>'today_sales')::numeric" "300" "today sales sum all delivered orders"
expect_eq "$OWNER" "select ($R)->>'total_orders'" "3" "report reads complete delivered history"
expect_eq "$OWNER" "select round((($R)->>'average_order')::numeric,2)" "200.00" "average uses all delivered orders"
expect_eq "$OWNER" "select ($R)->'best'->0->>'name'" "ผัดไทย" "best seller ranks by total quantity"
expect_eq "$OWNER" "select ($R)->'best'->0->>'quantity'" "3" "best seller quantity is aggregated"
expect_eq "$STAFF" "select ($R)->>'total_orders'" "3" "active store staff keeps existing report access"
expect_fail "$STRANGER" "select $R" "another store cannot read the report" "merchant access required"
expect_fail "" "select $R" "signed-out user cannot read the report" "merchant access required"
expect_eq "$OWNER" "select has_function_privilege('anon', 'public.merchant_sales_report(uuid)', 'execute')" "f" "anon cannot call report RPC"
expect_eq "$OWNER" "select provolatile from pg_proc where proname = 'merchant_sales_report'" "s" "report RPC is stable"

echo "PASS: Merchant complete sales report"
