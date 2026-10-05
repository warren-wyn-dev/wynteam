#!/usr/bin/env bash
# WYNOS Merchant production-readiness integration test.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_merchant_readiness_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_db() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "$1" 2>&1)"; then echo "FAIL (expected error): $2"; exit 1; fi; [[ "$err" == *"$3"* ]] || { echo "FAIL: $2 (wrong error: $err)"; exit 1; }; }

STORE=00000000-0000-0000-0000-000000000101
ITEM=00000000-0000-0000-0000-000000000201
ORDER1=00000000-0000-0000-0000-000000000301
ORDER2=00000000-0000-0000-0000-000000000302
ACTOR=00000000-0000-0000-0000-000000000401

run >/dev/null <<'SQL'
create extension if not exists pgcrypto;
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth;
create schema internal;

create function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('test.uid',true),'')::uuid $$;

create table public.food_stores(
  id uuid primary key,
  name text not null,
  description text,
  phone text,
  address text,
  logo_path text,
  cover_path text,
  business_hours text,
  delivery_area text,
  delivery_fee numeric not null default 0,
  minimum_order numeric not null default 0,
  latitude double precision,
  longitude double precision,
  pickup_latitude double precision,
  pickup_longitude double precision,
  pickup_note text,
  delivery_radius_km numeric not null default 5,
  delivery_base_km numeric not null default 2,
  delivery_fee_per_km numeric not null default 0,
  promptpay_name text,
  promptpay_id text,
  bank_name text,
  bank_account_name text,
  bank_account_number text,
  payment_qr_path text,
  is_open boolean not null default false,
  is_published boolean not null default false,
  admin_suspended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.food_menu_items(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  category text not null default 'อาหาร',
  name text not null,
  description text,
  price numeric not null default 0,
  image_path text,
  options jsonb not null default '[]'::jsonb,
  is_available boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.food_orders(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id),
  status text not null default 'pending_acceptance',
  created_at timestamptz not null default now()
);

create table public.food_order_items(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id),
  menu_item_id uuid references public.food_menu_items(id),
  quantity integer not null
);

create table public.audit_log(
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  actor_username_snapshot text,
  event_type text not null,
  target_id uuid,
  detail jsonb,
  created_at timestamptz not null default now(),
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned'))
);

create function public.food_has_merchant_access(p_store_id uuid default null)
returns boolean language sql stable as $$ select true $$;
create function public.food_is_platform_admin()
returns boolean language sql stable as $$ select false $$;

create function internal.food_distance_km(
  p_lat1 double precision,p_lng1 double precision,
  p_lat2 double precision,p_lng2 double precision
) returns numeric language sql immutable as
$$ select round((6371 * 2 * asin(least(1, sqrt(
 power(sin(radians(p_lat2-p_lat1)/2),2)
 + cos(radians(p_lat1))*cos(radians(p_lat2))*power(sin(radians(p_lng2-p_lng1)/2),2)
))))::numeric,2) $$;

create function internal.log_audit_event(
  p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb
) returns void language sql security definer as $$
  insert into public.audit_log(actor_id,actor_username_snapshot,event_type,target_id,detail)
  values(p_actor_id,'merchant-test',p_event_type,p_target_id,p_detail)
$$;

grant usage on schema public,internal,auth to authenticated;
grant select,insert,update,delete on public.food_stores,public.food_menu_items,public.food_orders,public.food_order_items,public.audit_log to authenticated;
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_merchant_production_readiness_v1.sql"
# Migration is intentionally idempotent.
run >/dev/null < "$ROOT/supabase/migrations_wynos_merchant_production_readiness_v1.sql"

run >/dev/null <<SQL
select set_config('test.uid','$ACTOR',false);
insert into public.food_stores(
  id,name,description,phone,address,logo_path,cover_path,
  latitude,longitude,promptpay_id,is_open
) values (
  '$STORE','ร้านทดสอบ','อาหารตามสั่ง','0812345678','1 ถนนทดสอบ',
  'stores/logo.jpg','stores/cover.jpg',16.18,103.30,'0812345678',true
);
SQL

expect_db "select (public.food_store_publish_readiness('$STORE')->>'ready')::boolean::text" "false" "store is incomplete before schedule/menu"
expect_fail "update public.food_stores set is_published=true where id='$STORE';" "publish gate rejects incomplete store" "store is not ready to publish"

run >/dev/null <<SQL
update public.food_stores
set business_schedule='{"weekly":{
  "mon":{"enabled":true,"open":"00:00","close":"00:00"},
  "tue":{"enabled":true,"open":"00:00","close":"00:00"},
  "wed":{"enabled":true,"open":"00:00","close":"00:00"},
  "thu":{"enabled":true,"open":"00:00","close":"00:00"},
  "fri":{"enabled":true,"open":"00:00","close":"00:00"},
  "sat":{"enabled":true,"open":"00:00","close":"00:00"},
  "sun":{"enabled":true,"open":"00:00","close":"00:00"}
}}'::jsonb,
prep_time_min_minutes=10, prep_time_max_minutes=25
where id='$STORE';

insert into public.food_menu_items(id,store_id,name,category,price,is_available,daily_stock_limit)
values('$ITEM','$STORE','ข้าวผัด','อาหารจานหลัก',50,true,1);
SQL

expect_db "select (public.food_store_publish_readiness('$STORE')->>'ready')::boolean::text" "true" "complete store becomes publish-ready"
run >/dev/null -c "update public.food_stores set is_published=true where id='$STORE';"
expect_db "select (public.food_store_open_status('$STORE')->>'open')::boolean::text" "true" "24-hour schedule is effectively open"

run >/dev/null -c "update public.food_stores set temporary_closed_until=now()+interval '30 minutes', temporary_closed_reason='พักร้าน' where id='$STORE';"
expect_db "select (public.food_store_open_status('$STORE')->>'open')::boolean::text" "false" "temporary close overrides schedule"
run >/dev/null -c "update public.food_stores set temporary_closed_until=null where id='$STORE';"

run >/dev/null <<SQL
insert into public.food_orders(id,store_id,status) values('$ORDER1','$STORE','pending_acceptance');
insert into public.food_orders(id,store_id,status) values('$ORDER2','$STORE','pending_acceptance');
insert into public.food_order_items(order_id,menu_item_id,quantity) values('$ORDER1','$ITEM',1);
SQL
expect_fail "insert into public.food_order_items(order_id,menu_item_id,quantity) values('$ORDER2','$ITEM',1);" "daily stock limit blocks excess orders" "menu item daily stock exceeded"

expect_db "select (public.food_store_location_quality('$STORE',16.18,103.30,'ร้านทดสอบ')->>'score')::int > 0" "t" "location quality RPC returns a score"
expect_db "select count(*) > 0 from public.audit_log where target_id='$STORE' and event_type like 'merchant_%'" "t" "merchant changes are audited"
expect_db "select count(*) > 0 from public.merchant_store_audit_history('$STORE',50)" "t" "merchant can read audit history"

echo "PASS: Merchant readiness, hours, publish gate, stock, location quality and audit are enforced"
