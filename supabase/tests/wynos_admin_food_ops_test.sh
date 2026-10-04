#!/usr/bin/env bash
# WYN-203 behaviour test: WYNOS Admin store / order operations.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_admin_food_ops_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_admin_food_ops_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
USER=00000000-0000-0000-0000-0000000000c0
OWNER=00000000-0000-0000-0000-0000000000d1
MANAGER=00000000-0000-0000-0000-0000000000d2
ACCOUNT=00000000-0000-0000-0000-0000000000e1
STORE=00000000-0000-0000-0000-0000000000f1
ORDER=00000000-0000-0000-0000-000000000101

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, username text, display_name text, platform_role text not null default 'user');
create function internal.current_platform_role() returns text language sql stable security definer set search_path = public as
  \$\$ select platform_role from public.profiles where id = auth.uid() \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, actor_username_snapshot text, event_type text not null, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned', 'admin_merchant_application_approved')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void language sql security definer as
  \$\$ insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.notifications(id bigserial primary key, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_accounts(id uuid primary key);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true,
  created_at timestamptz default now(), updated_at timestamptz default now(), primary key (merchant_account_id, user_id));
create table public.food_stores(id uuid primary key, slug text, name text, phone text, address text, business_hours text,
  merchant_account_id uuid, is_open boolean default false, is_published boolean default false,
  created_at timestamptz default now(), updated_at timestamptz default now());
create table public.food_staff(store_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_orders(id uuid primary key default gen_random_uuid(), order_number text, store_id uuid, buyer_id uuid,
  status text default 'pending_acceptance', payment_status text default 'pending', refund_status text default 'none',
  recipient_name text, recipient_phone text, total numeric default 0, created_at timestamptz default now(), delivered_at timestamptz);
create table public.food_order_items(order_id uuid, item_name text, quantity int, unit_price numeric, item_note text, created_at timestamptz default now());
create table public.food_order_events(order_id uuid, event_type text, from_status text, to_status text, note text, actor_id uuid, created_at timestamptz default now());
create table public.food_delivery_proofs(order_id uuid, method text, location_note text, image_path text, created_at timestamptz default now());
create table storage.objects(bucket_id text, name text);
alter table storage.objects enable row level security;
grant usage on schema public, auth, internal, storage to authenticated, anon;
grant select, update on public.food_stores to authenticated;
grant insert, select on public.food_orders to authenticated;

insert into auth.users values ('$ADMIN'), ('$MOD'), ('$USER'), ('$OWNER'), ('$MANAGER');
insert into public.profiles values
  ('$ADMIN','admin1','Admin','admin'), ('$MOD','mod1','Mod','moderator'), ('$USER','user1','User','user'),
  ('$OWNER','owner1','Owner','user'), ('$MANAGER','manager1','Manager','user');
insert into public.merchant_accounts values ('$ACCOUNT');
insert into public.merchant_memberships(merchant_account_id, user_id, role) values ('$ACCOUNT','$OWNER','owner'), ('$ACCOUNT','$MANAGER','manager');
insert into public.food_stores(id, slug, name, merchant_account_id, is_open, is_published) values ('$STORE','main','ร้านทดสอบ','$ACCOUNT', true, true);
insert into public.food_staff values ('$STORE','$MANAGER','manager',true);
insert into public.food_orders(id, order_number, store_id, buyer_id, recipient_name, recipient_phone, total, status, delivered_at)
  values ('$ORDER','1001','$STORE','$USER','คุณลูกค้า','0812345678', 150, 'delivered', now());
insert into public.food_order_items values ('$ORDER','ข้าวผัด',1,150,null);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_admin_food_ops_v1.sql"

# as <uid> <sql>: run as an authenticated user, last output line only.
as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_db()   { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

# Read access: admin and moderator see store data; regular users see nothing.
expect_eq "$MOD" "select (public.admin_food_overview()->>'stores_total')" "1" "moderator sees the overview"
expect_eq "$MOD" "select owner_username || '|' || staff_count || '|' || orders_total from public.admin_food_stores()" "owner1|2|1" "moderator sees the store list with owner and counts"
expect_eq "$MOD" "select jsonb_array_length(public.admin_food_store_detail('$STORE')->'team')" "2" "moderator sees the store team"
expect_fail "$USER" "select public.admin_food_overview()" "regular user cannot read the overview" "Not authorized"
expect_fail "$USER" "select * from public.admin_food_stores()" "regular user cannot list stores" "Not authorized"

# Customer data and changes are admin only.
expect_fail "$MOD" "select * from public.admin_food_orders()" "moderator cannot list orders" "Only admins can view Food orders"
expect_fail "$MOD" "select public.admin_food_order_detail('$ORDER')" "moderator cannot open an order" "Only admins can view Food orders"
expect_fail "$MOD" "select public.admin_set_food_store_suspension('$STORE', true, 'x')" "moderator cannot suspend" "Only admins can suspend stores"
expect_fail "$MOD" "select public.admin_set_food_store_member_active('$STORE','$MANAGER', false)" "moderator cannot change the team" "Only admins can change store teams"
expect_eq "$ADMIN" "select count(*) from public.admin_food_orders(null, null, '0812')" "1" "admin finds an order by phone"
expect_eq "$ADMIN" "select count(*) from public.admin_food_orders('$STORE', 'active')" "0" "active filter skips delivered orders"
expect_eq "$ADMIN" "select public.admin_food_order_detail('$ORDER')->'items'->0->>'item_name'" "ข้าวผัด" "admin opens an order with its items"
expect_db "select count(*) from public.audit_log where event_type = 'admin_food_order_viewed'" "1" "opening an order is audited"
expect_db "insert into public.audit_log(event_type) values ('admin_user_unbanned') returning 1" "1" "existing audit event types still allowed"

# Suspension.
expect_fail "$ADMIN" "select public.admin_set_food_store_suspension('$STORE', true, '  ')" "suspension needs a reason" "suspension reason is required"
expect_eq "$ADMIN" "select public.admin_set_food_store_suspension('$STORE', true, 'ร้องเรียนซ้ำ')::text" "" "admin suspends a store"
expect_db "select is_published::text || is_open::text || (admin_suspended_at is not null)::text from public.food_stores" "falsefalsetrue" "suspended store is unpublished and closed"
expect_db "select count(*) from public.notifications where recipient_id = '$OWNER'" "1" "the owner is notified"
expect_db "select count(*) from public.audit_log where event_type = 'admin_food_store_suspended'" "1" "suspension is audited"
expect_fail "$MANAGER" "update public.food_stores set admin_suspended_at = null" "store staff cannot lift a suspension" "store suspension can only be changed by WYNOS admin"
expect_fail "$MANAGER" "update public.food_stores set is_open = true" "store staff cannot reopen a suspended store" "store is suspended"
expect_fail "$USER" "insert into public.food_orders(store_id, order_number) values ('$STORE', '1002')" "suspended store takes no new orders" "store is not accepting orders"
expect_eq "$ADMIN" "select public.admin_set_food_store_suspension('$STORE', false)::text" "" "admin lifts the suspension"
expect_db "select (admin_suspended_at is null)::text || is_published::text from public.food_stores" "truefalse" "lifting keeps the store unpublished until the owner publishes"
expect_eq "$USER" "insert into public.food_orders(store_id, order_number) values ('$STORE', '1003') returning 1" "1" "orders work again after lifting"

# Team.
expect_fail "$ADMIN" "select public.admin_set_food_store_member_active('$STORE','$OWNER', false)" "the only owner cannot be deactivated" "cannot deactivate the only owner"
expect_eq "$ADMIN" "select public.admin_set_food_store_member_active('$STORE','$MANAGER', false)::text" "" "admin deactivates a manager"
expect_db "select (select active from public.merchant_memberships where user_id = '$MANAGER')::text || (select active from public.food_staff where user_id = '$MANAGER')::text" "falsefalse" "membership and legacy staff row are both deactivated"
expect_db "select count(*) from public.audit_log where event_type = 'admin_food_staff_updated'" "1" "team change is audited"
expect_db "select has_function_privilege('anon', 'public.admin_food_orders(uuid,text,text,integer)', 'execute')::text" "false" "anon cannot call the orders RPC"

echo "PASS: WYNOS Admin store and order operations are role-checked, audited and enforced"
