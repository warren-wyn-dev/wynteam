#!/usr/bin/env bash
# WYNOS Food Home v2 directory regression.
# Verifies the production migration compiles and returns the metadata used by
# the customer home without exposing underlying tables directly.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_home_v2_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

BUYER=00000000-0000-0000-0000-0000000000c0
STORE1=00000000-0000-0000-0000-0000000000f1
STORE2=00000000-0000-0000-0000-0000000000f2
MENU1=00000000-0000-0000-0000-000000000101
MENU2=00000000-0000-0000-0000-000000000102
CAMPAIGN=00000000-0000-0000-0000-000000000201

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth;
create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select '$BUYER'::uuid \$\$;
create function public.food_customer_access_enabled() returns boolean language sql stable security definer set search_path = '' as \$\$ select true \$\$;

create table public.food_stores(
  id uuid primary key,
  slug text not null,
  name text not null,
  logo_path text,
  cover_path text,
  address text,
  business_hours text,
  delivery_fee numeric not null default 0,
  latitude double precision,
  longitude double precision,
  prep_time_min_minutes integer not null default 15,
  prep_time_max_minutes integer not null default 30,
  is_open boolean not null default true,
  is_published boolean not null default true,
  admin_suspended_at timestamptz
);
create table public.food_menu_items(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id),
  category text not null,
  name text not null,
  is_available boolean not null default true
);
create table public.food_store_reviews(
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id),
  rating integer not null
);
create table public.food_orders(
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id),
  status text not null
);
create table public.food_campaigns(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id),
  name text not null,
  campaign_type text not null,
  discount_value numeric not null default 0,
  min_subtotal numeric not null default 0,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  usage_limit integer,
  usage_count integer not null default 0,
  is_active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
create function internal.food_store_effectively_open(p_store_id uuid, p_at timestamptz)
returns boolean language sql stable as \$\$ select coalesce((select is_open from public.food_stores where id=p_store_id), false) \$\$;
create function internal.food_ad_is_live(p_store_id uuid)
returns boolean language sql stable as \$\$ select p_store_id = '$STORE2'::uuid \$\$;

grant usage on schema public, auth, internal to authenticated, anon;
insert into public.food_stores(id,slug,name,address,business_hours,delivery_fee,latitude,longitude,prep_time_min_minutes,prep_time_max_minutes)
values
('$STORE1','noodle','ร้านก๋วยเตี๋ยว','มหาสารคาม','09:00-20:00',15,16.185,103.300,10,20),
('$STORE2','coffee','ร้านกาแฟ','มหาสารคาม','08:00-18:00',20,16.190,103.310,5,10);
insert into public.food_menu_items(id,store_id,category,name) values
('$MENU1','$STORE1','เส้น','ก๋วยเตี๋ยวหมู'),
('$MENU2','$STORE2','เครื่องดื่ม','มัทฉะลาเต้');
insert into public.food_store_reviews(store_id,rating) values
('$STORE1',5),('$STORE1',4),('$STORE2',5);
insert into public.food_orders(store_id,status) values
('$STORE1','delivered'),('$STORE1','delivered'),('$STORE2','cancelled');
insert into public.food_campaigns(id,store_id,name,campaign_type,discount_value,min_subtotal)
values ('$CAMPAIGN','$STORE1','ลดเปิดร้าน','percentage',10,100);
SQL

run < "$ROOT/supabase/migrations_wynos_food_home_directory_v2.sql" >/dev/null

db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_db() {
  local got
  if ! got="$(db "$1")"; then
    echo "FAIL: $3 (SQL execution failed)"
    run -c "$1" || true
    exit 1
  fi
  [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }
}

expect_db "select count(*) from public.food_store_directory()" "2" "directory returns published stores"
expect_db "select name from public.food_store_directory('มัทฉะ')" "ร้านกาแฟ" "search matches menu names"
expect_db "select name from public.food_store_directory('เส้น')" "ร้านก๋วยเตี๋ยว" "search matches menu categories"
expect_db "select rating_average || '|' || rating_count || '|' || delivered_order_count from public.food_store_directory() where id='$STORE1'" "4.5|2|2" "rating and popularity metadata are correct"
expect_db "select array_to_string(categories, ',') from public.food_store_directory() where id='$STORE1'" "เส้น" "menu categories are exposed"
expect_db "select promo_name || '|' || promo_type || '|' || promo_value || '|' || promo_min_subtotal from public.food_store_directory() where id='$STORE1'" "ลดเปิดร้าน|percentage|10|100" "promotion metadata is exposed"
expect_db "select name || '|' || is_ad from public.food_store_directory() limit 1" "ร้านกาแฟ|t" "live ads remain first"
expect_db "select has_function_privilege('authenticated','public.food_store_directory(text)','execute')::text || has_function_privilege('anon','public.food_store_directory(text)','execute')::text" "truefalse" "only authenticated customers can execute"

echo "PASS: WYNOS Food Home v2 directory metadata and search"
