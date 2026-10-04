#!/usr/bin/env bash
# WYN-210 behaviour test: Wynos Merchant finance summary for a date range.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_merchant_finance_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_merchant_finance_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

OWNER=00000000-0000-0000-0000-0000000000d1
MANAGER=00000000-0000-0000-0000-0000000000d2
RIDER=00000000-0000-0000-0000-0000000000d3
STRANGER=00000000-0000-0000-0000-0000000000d9
DEV=00000000-0000-0000-0000-0000000000d5
LEGACY_OWNER=00000000-0000-0000-0000-0000000000d6
LEGACY_RIDER=00000000-0000-0000-0000-0000000000d7
ACCOUNT=00000000-0000-0000-0000-0000000000e1
OTHER_ACCOUNT=00000000-0000-0000-0000-0000000000e2
STORE=00000000-0000-0000-0000-0000000000f1
OTHER=00000000-0000-0000-0000-0000000000f2

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, primary key (merchant_account_id, user_id));
create table public.food_stores(id uuid primary key, merchant_account_id uuid);
create table public.developer_accounts(user_id uuid primary key);
create table public.food_staff(store_id uuid, user_id uuid, role text, active boolean default true);
-- Same as production (merchant core completion): developers pass for any
-- store and legacy food_staff pass for any role. The finance RPC must not
-- rely on it.
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null) returns boolean language sql stable security definer set search_path = '' as \$\$
  select auth.uid() is not null and (
    exists (select 1 from public.developer_accounts d where d.user_id = auth.uid())
    or exists (select 1 from public.food_stores s join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
      where s.id = p_store_id and m.user_id = auth.uid() and m.active and (p_roles is null or m.role = any(p_roles)))
    or exists (select 1 from public.food_staff fs where fs.store_id = p_store_id and fs.user_id = auth.uid() and fs.active)) \$\$;
create table public.food_orders(id uuid primary key default gen_random_uuid(), store_id uuid, status text, payment_status text,
  refund_status text default 'none', subtotal numeric, delivery_fee numeric, total numeric,
  paid_at timestamptz, refunded_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.food_order_campaigns(order_id uuid, platform_funded numeric default 0, released_at timestamptz, settlement_id uuid);
create table public.food_ad_clicks(store_id uuid, click_day date, cost numeric);
-- Same rule as WYN-206: delivered, not refunded, not released, not settled.
create function internal.food_platform_owed_rows(p_store_id uuid) returns table (order_id uuid, amount numeric) language sql stable set search_path = '' as \$\$
  select foc.order_id, foc.platform_funded from public.food_order_campaigns foc join public.food_orders o on o.id = foc.order_id
  where o.store_id = p_store_id and foc.platform_funded > 0 and foc.released_at is null and foc.settlement_id is null
    and o.status = 'delivered' and o.payment_status <> 'refunded' \$\$;
grant usage on schema public, auth, internal to authenticated, anon;

insert into auth.users values ('$OWNER'), ('$MANAGER'), ('$RIDER'), ('$STRANGER'), ('$DEV'), ('$LEGACY_OWNER'), ('$LEGACY_RIDER');
insert into public.developer_accounts values ('$DEV');
insert into public.food_staff values ('$STORE','$LEGACY_OWNER','owner',true), ('$STORE','$LEGACY_RIDER','delivery',true);
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true), ('$ACCOUNT','$MANAGER','manager',true),
  ('$ACCOUNT','$RIDER','delivery',true), ('$OTHER_ACCOUNT','$STRANGER','owner',true);
insert into public.food_stores values ('$STORE','$ACCOUNT'), ('$OTHER','$OTHER_ACCOUNT');

-- 3 Oct (Bangkok): one paid order 100+20, 10 off, total 110.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$STORE','delivered','paid',100,20,110,'2026-10-03 05:00+07');
-- 4 Oct: two paid orders. B: 200+30, 30 off (total 200), WYNOS funds 15.
--        C: 80+20 total 100, refunded on 4 Oct.
insert into public.food_orders(id, store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('00000000-0000-0000-0000-0000000000b2','$STORE','delivered','paid',200,30,200,'2026-10-04 12:00+07');
insert into public.food_order_campaigns values ('00000000-0000-0000-0000-0000000000b2', 15, null, null);
insert into public.food_orders(store_id, status, payment_status, refund_status, subtotal, delivery_fee, total, paid_at, refunded_at)
  values ('$STORE','cancelled','refunded','refunded',80,20,100,'2026-10-04 13:00+07','2026-10-04 18:00+07');
-- 4 Oct 23:30 Bangkok is still 4 Oct even though it is 16:30 UTC.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$STORE','delivered','paid',50,0,50,'2026-10-04 23:30+07');
-- Not money yet: pending payment and a slip waiting for review.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total)
  values ('$STORE','pending_acceptance','pending',999,0,999), ('$STORE','pending_acceptance','submitted',70,20,90);
-- Ads: 2 clicks on 4 Oct.
insert into public.food_ad_clicks values ('$STORE','2026-10-04',2.5), ('$STORE','2026-10-04',2.5);
-- Previous period for a 4 Oct one-day range is 3 Oct (above).
-- Another store's money must never appear.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$OTHER','delivered','paid',5000,0,5000,'2026-10-04 12:00+07');
insert into public.food_ad_clicks values ('$OTHER','2026-10-04',500);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_finance_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_finance_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

S4="public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')"

# Who may see the money.
expect_fail "$RIDER" "select $S4" "delivery staff cannot read finance" "merchant manager access required"
expect_fail "$STRANGER" "select $S4" "another store's owner cannot read it" "merchant manager access required"
expect_fail "" "select $S4" "signed-out users cannot read it" "merchant manager access required"
expect_eq "$MANAGER" "select ($S4)->>'orders'" "3" "manager can read finance"
expect_fail "$DEV" "select $S4" "a developer account cannot read a store it does not belong to" "merchant manager access required"
expect_fail "$LEGACY_RIDER" "select $S4" "legacy delivery staff cannot read finance" "merchant manager access required"
expect_eq "$LEGACY_OWNER" "select ($S4)->>'orders'" "3" "legacy store owner can read finance"
expect_fail "$OWNER" "select public.merchant_finance_summary('$STORE','2026-10-05','2026-10-04')" "from after to is rejected" "invalid date range"
expect_fail "$OWNER" "select public.merchant_finance_summary('$STORE','2025-01-01','2026-10-04')" "ranges over a year are rejected" "date range is too long"

# 4 Oct: orders B, C and the 23:30 order (Bangkok day).
expect_eq "$OWNER" "select ($S4)->>'orders'" "3" "three paid orders on 4 Oct"
expect_eq "$OWNER" "select (($S4)->>'food')::numeric" "330" "food = 200 + 80 + 50"
expect_eq "$OWNER" "select (($S4)->>'delivery')::numeric" "50" "delivery = 30 + 20 + 0"
expect_eq "$OWNER" "select (($S4)->>'discounts')::numeric" "30" "discounts = 230 - 200"
expect_eq "$OWNER" "select (($S4)->>'refunds')::numeric" "100" "refund of C"
expect_eq "$OWNER" "select (($S4)->>'sales_net')::numeric" "250" "net sales = 350 paid - 100 refunded"
expect_eq "$OWNER" "select (($S4)->>'ad_spend')::numeric" "5.0" "two clicks of 2.50"
expect_eq "$OWNER" "select (($S4)->>'platform_funded')::numeric" "15" "WYNOS share of B"
expect_eq "$OWNER" "select (($S4)->>'income')::numeric" "260.0" "income = 250 - 5 + 15"
expect_eq "$OWNER" "select (($S4)->>'food')::numeric + (($S4)->>'delivery')::numeric - (($S4)->>'discounts')::numeric - (($S4)->>'refunds')::numeric = (($S4)->>'sales_net')::numeric" "t" "lines add up to net sales"
expect_eq "$OWNER" "select (($S4)->>'prev_sales_net')::numeric" "110" "previous day (3 Oct) for comparison"

# Range 3-4 Oct and the daily rows used for the CSV.
R="public.merchant_finance_summary('$STORE','2026-10-03','2026-10-04')"
expect_eq "$OWNER" "select (($R)->>'sales_net')::numeric" "360" "two-day net sales"
expect_eq "$OWNER" "select jsonb_array_length(($R)->'days')" "2" "one row per day"
expect_eq "$OWNER" "select (($R)->'days'->0->>'day') || ':' || (($R)->'days'->0->>'income')" "2026-10-03:110" "3 Oct income row"

# Things to look at: slips waiting, WYNOS owed (not range bound).
expect_eq "$OWNER" "select ($S4)->>'pending_slip_count'" "1" "one slip waiting"
expect_eq "$OWNER" "select (($S4)->>'pending_slip_total')::numeric" "90" "waiting slip amount"
expect_eq "$OWNER" "select (($S4)->>'platform_owed')::numeric" "15" "WYNOS still owes 15"
run -q -c "update public.food_order_campaigns set settlement_id = gen_random_uuid()" >/dev/null
expect_eq "$OWNER" "select (($S4)->>'platform_owed')::numeric" "0" "nothing owed after WYNOS settles"
expect_eq "$OWNER" "select (($S4)->>'platform_funded')::numeric" "15" "settled share still counts as income"

# Empty range.
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-11-01','2026-11-07')->>'income')::numeric" "0" "empty week is zero"

# Privileges.
expect_eq "$OWNER" "select has_function_privilege('anon', 'public.merchant_finance_summary(uuid,date,date)', 'execute')" "f" "anon cannot call it"
expect_eq "$OWNER" "select provolatile from pg_proc where proname = 'merchant_finance_summary'" "s" "function is read-only (stable)"

echo "PASS: WYN-210 merchant finance summary"
