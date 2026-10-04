#!/usr/bin/env bash
# WYN-213 behaviour test: merchant access hardening.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_merchant_access_hardening_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_merchant_access_hardening_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
OWNER=00000000-0000-0000-0000-0000000000d1
MANAGER=00000000-0000-0000-0000-0000000000d2
DEV=00000000-0000-0000-0000-0000000000d5
L_OWNER=00000000-0000-0000-0000-0000000000e1
L_STAFF=00000000-0000-0000-0000-0000000000e2
L_RIDER=00000000-0000-0000-0000-0000000000e3
BUYER=00000000-0000-0000-0000-0000000000c0
ACCOUNT=00000000-0000-0000-0000-0000000000f0
STORE=00000000-0000-0000-0000-0000000000f1

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, platform_role text not null default 'user');
create function internal.current_platform_role() returns text language sql stable security definer set search_path = public as
  \$\$ select platform_role from public.profiles where id = auth.uid() \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, event_type text, target_id uuid, detail jsonb);
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void language sql security definer as
  \$\$ insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.notifications(id bigserial primary key, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.developer_accounts(user_id uuid primary key);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, primary key (merchant_account_id, user_id));
create table public.food_stores(id uuid primary key, name text, merchant_account_id uuid);
create table public.food_staff(store_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_orders(id uuid primary key, store_id uuid, buyer_id uuid, status text, payment_status text, refund_status text default 'none');
create table public.food_platform_settlements(id uuid primary key default gen_random_uuid(), store_id uuid, amount numeric, order_count integer,
  reference text, note text, settled_by uuid, created_at timestamptz default now());
create table public.food_order_campaigns(order_id uuid, platform_campaign_id uuid, platform_funded numeric default 0, released_at timestamptz,
  settlement_id uuid);
create table public.food_ad_topups(id uuid primary key default gen_random_uuid(), store_id uuid, amount numeric, slip_path text not null, status text default 'pending');
create function public.food_path_uuid(p_segment text) returns uuid language sql immutable as
  \$\$ select case when p_segment ~ '^[0-9a-f-]{36}\$' then p_segment::uuid end \$\$;
create function storage.foldername(name text) returns text[] language sql immutable as
  \$\$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] \$\$;
grant usage on schema public, auth, internal, storage to authenticated, anon;

insert into auth.users values ('$ADMIN'),('$MOD'),('$OWNER'),('$MANAGER'),('$DEV'),('$L_OWNER'),('$L_STAFF'),('$L_RIDER'),('$BUYER');
insert into public.profiles(id, platform_role) values ('$ADMIN','admin'),('$MOD','moderator');
insert into public.developer_accounts values ('$DEV');
insert into public.food_stores values ('$STORE','ร้านทดสอบ','$ACCOUNT');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true), ('$ACCOUNT','$MANAGER','manager',true);
insert into public.food_staff values ('$STORE','$L_OWNER','owner',true), ('$STORE','$L_STAFF','staff',true), ('$STORE','$L_RIDER','delivery',true);
-- WYNOS-funded orders: paid+delivered (owed), slip waiting, refunded, self-order by the owner.
insert into public.food_orders values
  ('00000000-0000-0000-0000-000000000101','$STORE','$BUYER','delivered','paid','none'),
  ('00000000-0000-0000-0000-000000000102','$STORE','$BUYER','delivered','submitted','none'),
  ('00000000-0000-0000-0000-000000000103','$STORE','$BUYER','delivered','refunded','refunded'),
  ('00000000-0000-0000-0000-000000000104','$STORE','$OWNER','delivered','paid','none'),
  ('00000000-0000-0000-0000-000000000105','$STORE','$L_RIDER','delivered','paid','none');
insert into public.food_order_campaigns(order_id, platform_funded) values
  ('00000000-0000-0000-0000-000000000101',10), ('00000000-0000-0000-0000-000000000102',20),
  ('00000000-0000-0000-0000-000000000103',30), ('00000000-0000-0000-0000-000000000104',40), ('00000000-0000-0000-0000-000000000105',50);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_access_hardening_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_access_hardening_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_db()   { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

MGR="array['owner','admin','manager']"
OA="array['owner','admin']"

# 1. Developer accounts need a membership.
expect_eq "$DEV" "select public.merchant_has_store_role('$STORE', $MGR)" "f" "developer outside the store is not a manager"
expect_eq "$DEV" "select public.merchant_has_store_role('$STORE', null)" "f" "developer outside the store has no access"
expect_eq "$DEV" "select public.food_has_merchant_access('$STORE')" "f" "developer has no merchant access to the store"
expect_eq "$DEV" "select public.food_has_merchant_access(null)" "f" "developer has no merchant access at all"
expect_eq "$DEV" "select public.food_store_media_writable('stores/$STORE/logo.jpg')" "f" "developer cannot replace store media"

# 2. Real members and legacy staff by role.
expect_eq "$OWNER" "select public.merchant_has_store_role('$STORE', $OA)" "t" "owner manages the store"
expect_eq "$MANAGER" "select public.merchant_has_store_role('$STORE', $MGR)" "t" "manager is a manager"
expect_eq "$MANAGER" "select public.merchant_has_store_role('$STORE', $OA)" "f" "manager is not owner/admin"
expect_eq "$L_OWNER" "select public.merchant_has_store_role('$STORE', $OA)" "t" "legacy owner is owner"
expect_eq "$L_RIDER" "select public.merchant_has_store_role('$STORE', $OA)" "f" "legacy delivery is NOT owner/admin"
expect_eq "$L_RIDER" "select public.merchant_has_store_role('$STORE', $MGR)" "f" "legacy delivery is NOT a manager"
expect_eq "$L_RIDER" "select public.merchant_has_store_role('$STORE', array['delivery'])" "t" "legacy delivery is delivery"
expect_eq "$L_STAFF" "select public.merchant_has_store_role('$STORE', array['orders'])" "t" "legacy staff handles orders"
expect_eq "$L_STAFF" "select public.merchant_has_store_role('$STORE', $OA)" "f" "legacy staff is NOT owner/admin"
expect_eq "$L_RIDER" "select public.food_has_merchant_access('$STORE')" "t" "legacy delivery still opens the merchant app"
expect_eq "$L_OWNER" "select public.food_store_media_writable('stores/$STORE/logo.jpg')" "t" "legacy owner can change store media"
expect_eq "$L_RIDER" "select public.food_store_media_writable('stores/$STORE/qr.jpg')" "f" "legacy delivery cannot replace the PromptPay QR"

# 4. WYNOS owes only paid, delivered, not refunded, non-team orders.
expect_db "select string_agg(right(order_id::text, 3), ',' order by order_id) from internal.food_platform_owed_rows('$STORE')" "101" "only the real customer's paid order is owed"

# 5. Payouts need the amount the admin saw.
SETTLE="public.admin_settle_platform_store('$STORE', 'KBANK-1'"
expect_fail "$MOD" "select $SETTLE, 10, 1)" "moderator cannot record payouts" "Only admins can record WYNOS campaign payouts"
expect_fail "$ADMIN" "select $SETTLE, 25, 2)" "a stale amount is refused" "owed amount changed, reload and check before recording"
expect_fail "$ADMIN" "select $SETTLE, null, null)" "the amount is required" "owed amount changed, reload and check before recording"
expect_eq "$ADMIN" "select $SETTLE, 10, 1) is not null" "t" "matching amount is recorded"
expect_db "select amount || '/' || order_count from public.food_platform_settlements" "10/1" "settlement holds what was transferred"
expect_fail "$ADMIN" "select $SETTLE, 10, 1)" "cannot settle twice" "nothing to settle"
expect_db "select count(*) from pg_proc where proname = 'admin_settle_platform_store' and pronargs = 3" "0" "old 3-argument payout function is gone"
expect_db "select has_function_privilege('anon', 'public.admin_settle_platform_store(uuid,text,numeric,integer,text)', 'execute')" "f" "anon cannot record payouts"

# 6. One slip, one top-up.
run -q -c "insert into public.food_ad_topups(store_id, amount, slip_path) values ('$STORE', 100, 'ads/$STORE/slip.jpg')" >/dev/null
if run -q -c "insert into public.food_ad_topups(store_id, amount, slip_path) values ('$STORE', 100, 'ads/$STORE/slip.jpg')" >/dev/null 2>&1; then
  echo "FAIL: the same slip was accepted twice"; exit 1
fi

echo "PASS: WYN-213 merchant access hardening"
