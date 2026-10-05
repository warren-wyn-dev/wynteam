#!/usr/bin/env bash
# WYNOS Food customer menu options regression.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_item_options_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

USER_ID=00000000-0000-0000-0000-0000000000c0
STORE_ID=00000000-0000-0000-0000-0000000000f1
MENU_ID=00000000-0000-0000-0000-000000000101

run >/dev/null <<SQL
create extension if not exists pgcrypto;
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select '$USER_ID'::uuid \$\$;
create function public.food_customer_access_enabled() returns boolean language sql stable as \$\$ select true \$\$;
create function public.is_developer_account() returns boolean language sql stable as \$\$ select true \$\$;
create function public.food_public_access_enabled() returns boolean language sql stable as \$\$ select true \$\$;

create table public.food_stores(
  id uuid primary key,
  is_open boolean not null default true,
  is_published boolean not null default true,
  minimum_order numeric not null default 0,
  latitude double precision,
  delivery_fee numeric not null default 0,
  delivery_radius_km numeric not null default 5
);
create table public.food_menu_items(
  id uuid primary key,
  store_id uuid not null,
  name text not null,
  price numeric not null,
  options jsonb not null default '[]'::jsonb,
  is_available boolean not null default true
);
create table public.food_campaigns(
  id uuid primary key,
  usage_count integer not null default 0
);
create table public.food_orders(
  id uuid primary key default gen_random_uuid(),
  store_id uuid, buyer_id uuid, created_by uuid, source text, status text, payment_status text,
  recipient_name text, recipient_phone text, shipping_address text, customer_note text,
  subtotal numeric, delivery_fee numeric, campaign_id uuid, campaign_name text,
  campaign_discount numeric, delivery_discount numeric, total numeric,
  delivery_latitude double precision, delivery_longitude double precision, delivery_distance_km numeric
);
create table public.food_order_items(
  id uuid primary key default gen_random_uuid(),
  order_id uuid, menu_item_id uuid, item_name text, unit_price numeric, quantity integer,
  selected_options jsonb, item_note text
);
create table public.food_order_campaigns(
  order_id uuid, campaign_id uuid, campaign_name text, campaign_type text,
  campaign_discount numeric, delivery_discount numeric
);
create table public.food_order_events(
  order_id uuid, event_type text, to_status text, note text, actor_id uuid
);

create function internal.food_delivery_fee(uuid,double precision,double precision)
returns table(distance_km numeric, delivery_fee numeric)
language sql stable as \$\$ select 1.0::numeric, 0::numeric \$\$;

create function internal.food_campaign_candidates(uuid,numeric,numeric,jsonb)
returns table(campaign_id uuid,campaign_name text,campaign_type text,campaign_discount numeric,delivery_discount numeric)
language sql stable as \$\$ select null::uuid,null::text,null::text,0::numeric,0::numeric where false \$\$;

insert into public.food_stores(id) values ('$STORE_ID');
insert into public.food_menu_items(id,store_id,name,price,options)
values (
  '$MENU_ID',
  '$STORE_ID',
  'ตำลาว',
  50,
  '[
    {"id":"spice","name":"ระดับความเผ็ด","required":true,"max_select":1,"choices":[
      {"id":"mild","name":"ไม่เผ็ด","price":0},
      {"id":"hot","name":"เผ็ดมาก","price":5}
    ]},
    {"id":"extra","name":"เพิ่มเครื่อง","required":false,"max_select":2,"choices":[
      {"id":"egg","name":"ไข่ดาว","price":15},
      {"id":"sausage","name":"กุนเชียง","price":20}
    ]}
  ]'::jsonb
);
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_food_customer_menu_options_v1.sql"

db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_db() {
  local got
  got="$(db "$1")"
  [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }
}
expect_fail() {
  local sql="$1" contains="$2" label="$3" output
  set +e
  output="$(run -c "$sql" 2>&1)"
  status=$?
  set -e
  [[ "$status" -ne 0 && "$output" == *"$contains"* ]] || { echo "FAIL: $label"; echo "$output"; exit 1; }
}

ITEMS_OK="[{\"menu_item_id\":\"$MENU_ID\",\"quantity\":1,\"selected_options\":[{\"group_id\":\"spice\",\"choice_id\":\"hot\",\"price\":999},{\"group_id\":\"extra\",\"choice_id\":\"egg\",\"price\":999}]}]"
ITEMS_HOT="[{\"menu_item_id\":\"$MENU_ID\",\"quantity\":1,\"selected_options\":[{\"group_id\":\"spice\",\"choice_id\":\"hot\",\"price\":999}]}]"
ITEMS_MISSING="[{\"menu_item_id\":\"$MENU_ID\",\"quantity\":1,\"selected_options\":[]}]"
ITEMS_TOO_MANY="[{\"menu_item_id\":\"$MENU_ID\",\"quantity\":1,\"selected_options\":[{\"group_id\":\"spice\",\"choice_id\":\"mild\"},{\"group_id\":\"extra\",\"choice_id\":\"egg\"},{\"group_id\":\"extra\",\"choice_id\":\"sausage\"},{\"group_id\":\"extra\",\"choice_id\":\"third\"}]}]"

expect_db "select (public.food_quote_order('$STORE_ID', '$ITEMS_OK'::jsonb)->>'subtotal')::numeric" "70.00" "quote includes server-resolved option prices"
expect_db "select (public.food_quote_order('$STORE_ID', '$ITEMS_HOT'::jsonb)->>'subtotal')::numeric" "55.00" "client-forged option price is ignored"
expect_fail "select public.food_quote_order('$STORE_ID', '$ITEMS_MISSING'::jsonb)" "required menu option missing" "required option is enforced"
expect_fail "select public.food_quote_order('$STORE_ID', '$ITEMS_TOO_MANY'::jsonb)" "invalid menu option selection" "unknown/overflow option is rejected"

ORDER_ID="$(db "select public.food_create_order('$STORE_ID','Tester','0800000000','Test address','', '$ITEMS_OK'::jsonb)")"
expect_db "select unit_price::numeric from public.food_order_items where order_id='$ORDER_ID'" "70.00" "order snapshot stores option-adjusted unit price"
expect_db "select selected_options->0->>'choice_name' || '|' || selected_options->0->>'price' || '|' || selected_options->1->>'choice_name' || '|' || selected_options->1->>'price' from public.food_order_items where order_id='$ORDER_ID'" "เผ็ดมาก|5.00|ไข่ดาว|15.00" "order stores normalized server option snapshot"

echo "PASS: WYNOS Food menu options are validated and priced server-side"
