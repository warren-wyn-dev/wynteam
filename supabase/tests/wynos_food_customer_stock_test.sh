#!/usr/bin/env bash
# WYNOS Food live stock RPC: customer-visible only, excludes cancelled/old
# orders, returns null for unlimited items, and never exposes draft/suspended stores.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_customer_stock_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { $PSQL -q -X -t -A -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

STORE=00000000-0000-4000-8000-0000000000a1
DRAFT=00000000-0000-4000-8000-0000000000a2
SUSPENDED=00000000-0000-4000-8000-0000000000a3
LIMITED=00000000-0000-4000-8000-0000000000b1
UNLIMITED=00000000-0000-4000-8000-0000000000b2
DRAFT_ITEM=00000000-0000-4000-8000-0000000000b3
SUSPENDED_ITEM=00000000-0000-4000-8000-0000000000b4

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create table public.food_stores(
  id uuid primary key,
  is_published boolean not null default false,
  admin_suspended_at timestamptz
);
create table public.food_menu_items(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id),
  name text not null,
  daily_stock_limit integer
);
create table public.food_orders(
  id uuid primary key,
  status text not null,
  created_at timestamptz not null default now()
);
create table public.food_order_items(
  id uuid primary key,
  order_id uuid not null references public.food_orders(id),
  menu_item_id uuid not null references public.food_menu_items(id),
  quantity integer not null
);
create or replace function public.food_customer_access_enabled() returns boolean
language sql stable as \$\$ select true \$\$;
create or replace function public.is_developer_account() returns boolean
language sql stable as \$\$ select false \$\$;
create or replace function public.food_public_access_enabled() returns boolean
language sql stable as \$\$ select true \$\$;
grant usage on schema public to anon, authenticated;

insert into public.food_stores values
  ('$STORE', true, null),
  ('$DRAFT', false, null),
  ('$SUSPENDED', true, now());

insert into public.food_menu_items values
  ('$LIMITED', '$STORE', 'limited', 10),
  ('$UNLIMITED', '$STORE', 'unlimited', null),
  ('$DRAFT_ITEM', '$DRAFT', 'draft', 10),
  ('$SUSPENDED_ITEM', '$SUSPENDED', 'suspended', 10);

insert into public.food_orders(id,status,created_at) values
  ('10000000-0000-4000-8000-000000000001','preparing',now()),
  ('10000000-0000-4000-8000-000000000002','cancelled',now()),
  ('10000000-0000-4000-8000-000000000003','delivered',now() - interval '2 days');

insert into public.food_order_items values
  ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','$LIMITED',3),
  ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','$LIMITED',4),
  ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003','$LIMITED',5);
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_food_customer_stock_v1.sql"

[ "$(val "select to_regclass('public.food_order_items_menu_idx') is not null")" = "t" ] || fail "menu item stock lookup index exists"
[ "$(val "set role authenticated; select remaining_stock from public.food_menu_stock_remaining('$STORE') where menu_item_id='$LIMITED'")" = "7" ] || fail "live remaining stock excludes cancelled and old orders"
[ -z "$(val "set role authenticated; select remaining_stock from public.food_menu_stock_remaining('$STORE') where menu_item_id='$UNLIMITED'")" ] || fail "unlimited item returns null remaining stock"
[ "$(val "set role authenticated; select count(*) from public.food_menu_stock_remaining('$DRAFT')")" = "0" ] || fail "draft store hidden"
[ "$(val "set role authenticated; select count(*) from public.food_menu_stock_remaining('$SUSPENDED')")" = "0" ] || fail "suspended store hidden"
if val "set role anon; select count(*) from public.food_menu_stock_remaining('$STORE')" >/dev/null 2>&1; then fail "anon must not execute stock RPC"; fi

run >/dev/null -c "create or replace function public.food_customer_access_enabled() returns boolean language sql stable as \$\$ select false \$\$;"
[ "$(val "set role authenticated; select count(*) from public.food_menu_stock_remaining('$STORE')")" = "0" ] || fail "customer access gate enforced"

echo "PASS: food customer stock"
