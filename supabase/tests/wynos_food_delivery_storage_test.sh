#!/usr/bin/env bash
# WYN-193 / WYN-194 behaviour tests on a throwaway local PostgreSQL database.
# Supabase objects the migrations depend on (auth.uid, storage.objects,
# storage.foldername, Food tables and helpers) are stubbed with the same
# semantics; the two migrations under test are applied unchanged.
#
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_delivery_storage_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_delivery_storage_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema storage; create schema internal;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create function storage.foldername(name text) returns text[] language sql immutable as
  $$ select (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1] $$;
create table storage.objects(bucket_id text, name text);
alter table storage.objects enable row level security;
create table public.developer_accounts(user_id uuid);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean);
create table public.food_stores(id uuid primary key, merchant_account_id uuid);
create table public.food_staff(store_id uuid, user_id uuid, active boolean);
create table public.food_orders(id uuid primary key, store_id uuid, buyer_id uuid, order_number int,
  status text, payment_slip_path text, delivered_at timestamptz);
create table public.food_delivery_proofs(order_id uuid unique, method text not null, location_note text,
  image_path text, delivered_by uuid, created_at timestamptz default now());
create table public.food_order_events(order_id uuid, event_type text, from_status text, to_status text, note text, actor_id uuid);
create table public.notifications(recipient_id uuid, actor_id uuid, type text, reason text);
create function public.food_customer_access_enabled() returns boolean language sql as $$ select auth.uid() is not null $$;
create function public.food_has_merchant_access(p_store_id uuid default null) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (select 1 from public.developer_accounts d where d.user_id = auth.uid())
    or exists (select 1 from public.food_stores s join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
      where mm.user_id = auth.uid() and mm.active and (p_store_id is null or s.id = p_store_id))
    or exists (select 1 from public.food_staff fs where fs.user_id = auth.uid() and fs.active and (p_store_id is null or fs.store_id = p_store_id)));
$$;
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and (
    exists (select 1 from public.developer_accounts d where d.user_id = (select auth.uid()))
    or exists (select 1 from public.food_stores s join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
      where s.id = p_store_id and mm.user_id = (select auth.uid()) and mm.active and (p_roles is null or mm.role = any(p_roles)))
    or exists (select 1 from public.food_staff fs where fs.store_id = p_store_id and fs.user_id = (select auth.uid()) and fs.active));
$$;
grant usage on schema storage, auth to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on public.food_orders, public.food_stores to authenticated;

-- Store A (owner a1, delivery a2), store B (owner b1), buyer c1.
insert into food_stores values ('aaaaaaaa-0000-0000-0000-000000000000','a0000000-0000-0000-0000-00000000000a'),
                               ('bbbbbbbb-0000-0000-0000-000000000000','b0000000-0000-0000-0000-00000000000b');
insert into merchant_memberships values
  ('a0000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-0000000000a1','owner',true),
  ('a0000000-0000-0000-0000-00000000000a','00000000-0000-0000-0000-0000000000a2','delivery',true),
  ('b0000000-0000-0000-0000-00000000000b','00000000-0000-0000-0000-0000000000b1','owner',true);
insert into food_orders values
  ('11111111-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1',101,'out_for_delivery',
   '00000000-0000-0000-0000-0000000000c1/slips/11111111-0000-0000-0000-000000000000/s.jpg',null),
  ('22222222-0000-0000-0000-000000000000','bbbbbbbb-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1',102,'out_for_delivery',
   '00000000-0000-0000-0000-0000000000c1/slips/22222222-0000-0000-0000-000000000000/s.jpg',null),
  ('33333333-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1',103,'preparing',
   '00000000-0000-0000-0000-0000000000c1/slips/legacy.jpg',null);
insert into storage.objects values
  ('food-private','00000000-0000-0000-0000-0000000000c1/slips/11111111-0000-0000-0000-000000000000/s.jpg'),
  ('food-private','00000000-0000-0000-0000-0000000000c1/slips/22222222-0000-0000-0000-000000000000/s.jpg'),
  ('food-private','delivery/22222222-0000-0000-0000-000000000000/d.jpg'),
  ('food-private','00000000-0000-0000-0000-0000000000c1/slips/legacy.jpg'),
  ('food-public','stores/aaaaaaaa-0000-0000-0000-000000000000/payment/qr.png'),
  ('food-public','stores/bbbbbbbb-0000-0000-0000-000000000000/payment/qr.png');
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_food_storage_store_isolation_v1.sql" 2>&1
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_delivery_photo_required_v1.sql" 2>&1

# Each case runs as `authenticated` for one user and must match the expectation.
expect_ok()   { run -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" >/dev/null 2>&1 || { echo "FAIL (expected success): $3"; exit 1; }; }
# expect_fail <uid> <sql> <description> <expected error substring>
expect_fail() { local err; if err="$(run -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" 2>&1 >/dev/null)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }
expect_eq()   { local got; got="$(run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" | tail -n1)";
                [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }

A1=00000000-0000-0000-0000-0000000000a1; A2=00000000-0000-0000-0000-0000000000a2
B1=00000000-0000-0000-0000-0000000000b1; C1=00000000-0000-0000-0000-0000000000c1
O1=11111111-0000-0000-0000-000000000000; O2=22222222-0000-0000-0000-000000000000; O3=33333333-0000-0000-0000-000000000000
PRIV="select count(*) from storage.objects where bucket_id='food-private'"

# WYN-194 reads: each store sees only its own order evidence; the buyer sees all of theirs.
expect_eq "$A1" "$PRIV" 2 "owner A sees only store A slips, including a legacy slip path"
expect_eq "$B1" "$PRIV" 2 "owner B sees only store B slip and delivery photo"
expect_eq "$C1" "$PRIV" 4 "buyer sees own slips and delivery photos"
# WYN-194 writes across stores are rejected.
expect_fail "$B1" "insert into storage.objects values ('food-private','delivery/$O1/x.jpg')" "store B uploads into store A order" "row-level security"
expect_fail "$B1" "insert into storage.objects values ('food-public','stores/aaaaaaaa-0000-0000-0000-000000000000/payment/evil.png')" "store B adds store A QR" "row-level security"
expect_eq "$B1" "with u as (update storage.objects set name=name where name like 'stores/aaaaaaaa%' returning 1) select count(*) from u" 0 "store B overwrites store A QR"
expect_eq "$B1" "with d as (delete from storage.objects where name like 'stores/aaaaaaaa%' returning 1) select count(*) from d" 0 "store B deletes store A QR"
expect_ok   "$B1" "insert into storage.objects values ('food-public','stores/bbbbbbbb-0000-0000-0000-000000000000/menu/m.png')" "store B uploads own menu image"
expect_fail "$A2" "insert into storage.objects values ('food-public','stores/aaaaaaaa-0000-0000-0000-000000000000/payment/x.png')" "delivery role changes store media" "row-level security"
expect_fail "$A2" "insert into storage.objects values ('food-private','delivery/$O3/no.jpg')" "upload for an order not out for delivery" "row-level security"
expect_fail "$A2" "insert into storage.objects values ('food-private','delivery/$O1/sub/no.jpg')" "nested delivery path" "row-level security"
# Evidence cannot be edited or deleted through the API, by the store or the buyer.
expect_eq "$B1" "with d as (delete from storage.objects where name like 'delivery/%' returning 1) select count(*) from d" 0 "store deletes delivery evidence"
expect_eq "$C1" "with d as (delete from storage.objects where name like '%/slips/%' returning 1) select count(*) from d" 0 "buyer deletes submitted slip"
expect_eq "$C1" "with u as (update storage.objects set name=name where name like '%/slips/%' returning 1) select count(*) from u" 0 "buyer replaces submitted slip"
expect_ok   "$C1" "insert into storage.objects values ('food-private','$C1/slips/$O1/new.jpg')" "buyer uploads a new slip"
expect_fail "$C1" "insert into storage.objects values ('food-private','$A1/slips/x.jpg')" "buyer uploads into another user's folder" "row-level security"

# WYN-193: a delivery photo is required for every completed delivery.
DONE="select public.food_complete_delivery"
expect_ok   "$A2" "insert into storage.objects values ('food-private','delivery/$O1/a.jpg')" "delivery role uploads photo"
expect_fail "$B1" "$DONE('$O1','direct',null,'delivery/$O1/a.jpg')" "other store completes delivery" "delivery role required"
expect_fail "$A1" "$DONE('$O1','direct',null,null)" "direct without photo" "delivery photo is required"
expect_fail "$A1" "$DONE('$O1',null,null,'delivery/$O1/a.jpg')" "null method" "invalid delivery method"
expect_fail "$A1" "$DONE('$O1','direct',null,'delivery/$O2/d.jpg')" "photo of another order" "delivery photo is required"
expect_fail "$A1" "$DONE('$O1','direct',null,'delivery/$O1/missing.jpg')" "photo that was never uploaded" "delivery photo is required"
expect_fail "$A1" "$DONE('$O1','direct',null,'delivery/$O1/../$O2/d.jpg')" "path traversal" "delivery photo is required"
expect_fail "$A1" "$DONE('$O1','dropoff',E' \\t\\n ','delivery/$O1/a.jpg')" "dropoff with blank location" "dropoff location is required"
expect_ok   "$A1" "$DONE('$O1','direct','ignored','delivery/$O1/a.jpg')" "direct with photo"
expect_fail "$A1" "$DONE('$O1','direct',null,'delivery/$O1/a.jpg')" "completing twice" "order is not out for delivery"
expect_eq "$A1" "reset role; select status || '|' || (select image_path from food_delivery_proofs where order_id='$O1') || '|' || coalesce((select location_note from food_delivery_proofs where order_id='$O1'),'') from food_orders where id='$O1'" \
  "delivered|delivery/$O1/a.jpg|" "direct keeps the photo and drops the note"
expect_eq "$A1" "reset role; select count(*) from notifications where recipient_id='$C1' and reason like 'ออเดอร์ #101 ส่งถึงแล้ว%'" 1 "buyer notified once"
expect_ok   "$B1" "$DONE('$O2','dropoff','หน้าประตู','delivery/$O2/d.jpg')" "dropoff with photo and location"

echo "PASS: WYNOS Food delivery photo is required and Food storage is isolated per store"
