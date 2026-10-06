#!/usr/bin/env bash
# WYN-218 behaviour test: menu options priced and resolved on the server,
# order rate limit, and no slip after the store marked payment paid/refunded.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_order_options_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_order_options_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
# Runs SQL as a signed-in user and prints the error message (empty on success).
as_user() {
  run -At 2>&1 >/dev/null -c "set role authenticated; set test.uid='$1'; $2" \
    | sed -n 's/^ERROR: *//p' | head -1 || true
}
expect_error() { # label uid sql expected-message
  local got; got=$(as_user "$2" "$3")
  [ "$got" = "$4" ] || fail "$1 (expected '$4', got '$got')"
  pass "$1"
}

BUYER=00000000-0000-0000-0000-0000000000c0
BUYER2=00000000-0000-0000-0000-0000000000c2
DEV=00000000-0000-0000-0000-0000000000d5
STORE=00000000-0000-0000-0000-0000000000f1
STORE2=00000000-0000-0000-0000-0000000000f2
KAPRAO=00000000-0000-0000-0000-0000000000a1
WATER=00000000-0000-0000-0000-0000000000a2
NOODLE=00000000-0000-0000-0000-0000000000a3

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.developer_accounts(user_id uuid primary key);
create function public.is_developer_account() returns boolean language sql stable as
  \$\$ select exists(select 1 from public.developer_accounts where user_id = auth.uid()) \$\$;
create function public.food_customer_access_enabled() returns boolean language sql stable as \$\$ select auth.uid() is not null \$\$;
create function public.food_is_permanent_account() returns boolean language sql stable as \$\$ select auth.uid() is not null \$\$;
create function public.food_public_access_enabled() returns boolean language sql stable as \$\$ select true \$\$;
create table public.food_stores(id uuid primary key, is_open boolean default true, is_published boolean default true,
  minimum_order numeric(10,2) default 0, latitude double precision, longitude double precision,
  delivery_fee numeric(10,2) default 20, delivery_radius_km numeric default 5, delivery_base_km numeric default 2,
  delivery_fee_per_km numeric default 5);
create table public.food_menu_items(id uuid primary key, store_id uuid, name text, price numeric(10,2),
  is_available boolean default true, options jsonb not null default '[]');
create table public.food_orders(id uuid primary key default gen_random_uuid(), store_id uuid, buyer_id uuid, created_by uuid,
  source text, status text, payment_status text, recipient_name text, recipient_phone text, shipping_address text,
  customer_note text, subtotal numeric(10,2), delivery_fee numeric(10,2), campaign_id uuid, campaign_name text,
  campaign_discount numeric(10,2), delivery_discount numeric(10,2), total numeric(10,2),
  delivery_latitude double precision, delivery_longitude double precision, delivery_distance_km numeric(6,2),
  payment_slip_path text, payment_note text, payment_verification_status text, payment_provider text,
  payment_provider_code text, payment_transaction_ref text, payment_verified_at timestamptz,
  payment_verification_note text, created_at timestamptz not null default now());
create table public.food_order_items(order_id uuid, menu_item_id uuid, item_name text, unit_price numeric(10,2),
  quantity integer, selected_options jsonb not null default '[]', item_note text);
create table public.food_campaigns(id uuid primary key, usage_count integer default 0);
create table public.food_order_campaigns(order_id uuid, campaign_id uuid, campaign_name text, campaign_type text,
  campaign_discount numeric, delivery_discount numeric);
create table public.food_order_events(order_id uuid, event_type text, to_status text, note text, actor_id uuid);
create function internal.food_campaign_candidates(p_store uuid, p_subtotal numeric, p_fee numeric, p_totals jsonb)
returns table(campaign_id uuid, campaign_name text, campaign_type text, campaign_discount numeric, delivery_discount numeric)
language sql stable as \$\$ select null::uuid, null::text, null::text, null::numeric, null::numeric where false \$\$;
create function internal.food_delivery_fee(p_store_id uuid, p_latitude double precision, p_longitude double precision)
returns table(distance_km numeric, delivery_fee numeric)
language sql stable as \$\$ select null::numeric, s.delivery_fee from public.food_stores s where s.id = p_store_id \$\$;
grant usage on schema public, auth, internal to authenticated, anon;
grant select, insert, update on all tables in schema public to authenticated;

insert into public.developer_accounts values ('$DEV');
insert into public.food_stores(id) values ('$STORE'), ('$STORE2');
insert into public.food_menu_items values
  ('$KAPRAO', '$STORE', 'ข้าวกะเพรา', 50, true,
   '[{"id":"spice","name":"ความเผ็ด","required":true,"max_select":1,
      "choices":[{"id":"mild","name":"ไม่เผ็ด","price":0},{"id":"hot","name":"เผ็ดมาก","price":0}]},
     {"id":"extra","name":"เพิ่ม","required":false,"max_select":2,
      "choices":[{"id":"egg","name":"ไข่ดาว","price":10},{"id":"special","name":"พิเศษ","price":20},{"id":"rice","name":"ข้าวเพิ่ม","price":"5"}]}]'),
  ('$WATER', '$STORE', 'น้ำเปล่า', 10, true, '[]'),
  ('$NOODLE', '$STORE2', 'ก๋วยเตี๋ยว', 40, true, '[]');
SQL
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_order_options_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_order_options_v1.sql"
pass "migration applies twice"

order() { # uid store items-json -> order id
  run -At -c "set role authenticated; set test.uid='$1';
    select public.food_create_order('$2','ลูกค้า','0800000000','ที่อยู่',null,'$3'::jsonb)" | tail -1
}
quote_total() { # items-json -> subtotal|total
  run -At -c "set role authenticated; set test.uid='$BUYER';
    select (q->>'subtotal')||'|'||(q->>'total') from public.food_quote_order('$STORE','$1'::jsonb) q" | tail -1
}

# --- Option pricing ---------------------------------------------------------
LINE_FULL='[{"menu_item_id":"'$KAPRAO'","quantity":2,"selected_options":[{"group_id":"spice","choice_id":"hot"},{"group_id":"extra","choice_id":"egg"},{"group_id":"extra","choice_id":"special"}]}]'
[ "$(quote_total "$LINE_FULL")" = "160.00|180.00" ] || fail "quote adds option prices (got $(quote_total "$LINE_FULL"))"
pass "quote adds option prices: (50+10+20) x 2 = 160, + 20 delivery"

LINE_STR='[{"menu_item_id":"'$KAPRAO'","quantity":1,"selected_options":[{"group_id":"spice","choice_id":"mild"},{"group_id":"extra","choice_id":"rice"}]}]'
[ "$(quote_total "$LINE_STR")" = "55.00|75.00" ] || fail "numeric-string choice price is charged"
pass "numeric-string choice price is charged like the client does"

# Client-supplied names and prices are ignored.
FORGED='[{"menu_item_id":"'$KAPRAO'","quantity":2,"note":"ไม่ใส่ผัก","selected_options":[{"group_id":"spice","choice_id":"hot","choice_name":"กุ้งมังกร x10","price":0},{"group_id":"extra","choice_id":"egg","group_name":"ฟรี","price":-10},{"group_id":"extra","choice_id":"special"}]}]'
O1=$(order "$BUYER" "$STORE" "$FORGED")
[ -n "$O1" ] || fail "order with options is created"
[ "$(val "select subtotal||'|'||total from public.food_orders where id='$O1'")" = "160.00|180.00" ] || fail "order total includes option prices"
pass "order total includes option prices"
[ "$(val "select unit_price||'|'||quantity||'|'||item_note from public.food_order_items where order_id='$O1'")" = "80.00|2|ไม่ใส่ผัก" ] \
  || fail "order item unit price includes options"
pass "order item unit price = 50 + 10 + 20"
[ "$(val "select string_agg(o->>'group_name'||':'||(o->>'choice_name')||':'||(o->>'price'), ',' order by ord)
          from public.food_order_items i, jsonb_array_elements(i.selected_options) with ordinality as t(o, ord)
          where i.order_id='$O1'")" = "ความเผ็ด:เผ็ดมาก:0,เพิ่ม:ไข่ดาว:10,เพิ่ม:พิเศษ:20" ] \
  || fail "stored options come from the menu"
pass "stored option names and prices come from the menu, not the client"

[ -n "$(order "$BUYER2" "$STORE" '[{"menu_item_id":"'$WATER'","quantity":3}]')" ] || fail "item without options, no selected_options"
[ -n "$(order "$BUYER2" "$STORE" '[{"menu_item_id":"'$WATER'","quantity":1,"selected_options":null}]')" ] || fail "selected_options null"
pass "items without options still order (missing or null selected_options)"
[ "$(val "select count(*) from public.food_order_items i join public.food_orders o on o.id=i.order_id
          where o.buyer_id='$BUYER2' and i.selected_options = '[]'::jsonb")" = "2" ] || fail "empty options stored as []"
pass "no options stored as []"

Q="select public.food_quote_order('$STORE','"
E="'::jsonb)"
expect_error "unknown group rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"spice","choice_id":"mild"},{"group_id":"FAKE","choice_id":"x"}]}]'"$E" "invalid menu option"
expect_error "choice from another group rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"spice","choice_id":"egg"}]}]'"$E" "invalid menu option"
expect_error "duplicate choice rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"spice","choice_id":"mild"},{"group_id":"extra","choice_id":"egg"},{"group_id":"extra","choice_id":"egg"}]}]'"$E" "invalid menu option"
expect_error "missing choice_id rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"spice"}]}]'"$E" "invalid menu option"
expect_error "non-array selected_options rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":"egg"}]'"$E" "invalid menu option"
expect_error "required group enforced" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"extra","choice_id":"egg"}]}]'"$E" "required menu option missing"
expect_error "max_select enforced" "$BUYER" "$Q"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"spice","choice_id":"mild"},{"group_id":"spice","choice_id":"hot"}]}]'"$E" "too many menu options selected"
expect_error "options on an item without options rejected" "$BUYER" "$Q"'[{"menu_item_id":"'$WATER'","selected_options":[{"group_id":"spice","choice_id":"mild"}]}]'"$E" "invalid menu option"
expect_error "create checks options too" "$BUYER" "select public.food_create_order('$STORE','a','0800000000','b',null,'"'[{"menu_item_id":"'$KAPRAO'","selected_options":[{"group_id":"FAKE","choice_id":"x"}]}]'"'::jsonb)" "invalid menu option"

# --- Rate limit -------------------------------------------------------------
LINE_WATER='[{"menu_item_id":"'$WATER'","quantity":1}]'
run -c "delete from public.food_order_items; delete from public.food_orders;" >/dev/null
for i in 1 2 3; do [ -n "$(order "$BUYER" "$STORE" "$LINE_WATER")" ] || fail "pending order $i"; done
expect_error "4th order waiting at the same store refused" "$BUYER" "select public.food_create_order('$STORE','a','0800000000','b',null,'$LINE_WATER'::jsonb)" "too many pending orders"
[ -n "$(order "$BUYER" "$STORE2" '[{"menu_item_id":"'$NOODLE'","quantity":1}]')" ] || fail "other store still allowed"
pass "pending limit is per store"
run -c "update public.food_orders set status='preparing'" >/dev/null
[ -n "$(order "$BUYER" "$STORE" "$LINE_WATER")" ] || fail "5th order in 10 minutes"
expect_error "6th order in 10 minutes refused" "$BUYER" "select public.food_create_order('$STORE','a','0800000000','b',null,'$LINE_WATER'::jsonb)" "too many orders, try again later"
run -c "update public.food_orders set created_at = now() - interval '11 minutes'" >/dev/null
[ -n "$(order "$BUYER" "$STORE" "$LINE_WATER")" ] || fail "older orders do not count"
pass "orders older than 10 minutes do not count"
for i in 1 2 3 4 5 6; do [ -n "$(order "$DEV" "$STORE" "$LINE_WATER")" ] || fail "developer order $i"; done
pass "developer accounts are exempt from the order limit"

# --- Payment slip -----------------------------------------------------------
P=$(order "$BUYER2" "$STORE" "$LINE_WATER")
SLIP="$BUYER2/slips/$P/a.jpg"
submit="select public.food_submit_payment('$P','$SLIP')"
[ -z "$(as_user "$BUYER2" "$submit")" ] || fail "slip accepted while pending"
pass "slip accepted while payment is pending"
expect_error "second slip while submitted refused" "$BUYER2" "$submit" "payment already submitted"
for st in paid refunded; do
  run -c "update public.food_orders set payment_status='$st', payment_verified_at=now() where id='$P'" >/dev/null
  expect_error "slip after store marked $st refused" "$BUYER2" "$submit" "payment already submitted"
  [ "$(val "select payment_status from public.food_orders where id='$P'")" = "$st" ] || fail "$st status kept"
done
run -c "update public.food_orders set payment_status='issue' where id='$P'" >/dev/null
[ -z "$(as_user "$BUYER2" "$submit")" ] || fail "slip accepted again after issue"
pass "slip accepted again when the store reports an issue"
expect_error "other buyer cannot submit" "$BUYER" "$submit" "order not found"

# --- Privileges -------------------------------------------------------------
[ "$(val "select has_function_privilege('authenticated','internal.food_resolve_menu_options(jsonb,jsonb)','execute')")" = "f" ] \
  || fail "resolver is internal only"
for f in "food_quote_order(uuid,jsonb,double precision,double precision)" \
         "food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision)" \
         "food_submit_payment(uuid,text)"; do
  [ "$(val "select has_function_privilege('anon','public.$f','execute')")" = "f" ] || fail "anon cannot run $f"
  [ "$(val "select has_function_privilege('authenticated','public.$f','execute')")" = "t" ] || fail "authenticated can run $f"
done
pass "privileges: internal resolver, RPCs for signed-in users only"

echo "All WYN-218 food order options tests passed."
