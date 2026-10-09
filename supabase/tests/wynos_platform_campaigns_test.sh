#!/usr/bin/env bash
# WYN-206 behaviour test: WYNOS campaigns (Admin designs, stores join, hybrid funding).
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs and
# the real Campaign Center migration underneath.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_platform_campaigns_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_platform_campaigns_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
OWNER=00000000-0000-0000-0000-0000000000d1
MANAGER=00000000-0000-0000-0000-0000000000d2
RIDER=00000000-0000-0000-0000-0000000000d3
BUYER=00000000-0000-0000-0000-0000000000c0
ACCOUNT=00000000-0000-0000-0000-0000000000e1
STORE=00000000-0000-0000-0000-0000000000f1
O1=00000000-0000-0000-0000-000000000101
O2=00000000-0000-0000-0000-000000000102

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, username text, display_name text, platform_role text not null default 'user');
create function internal.current_platform_role() returns text language sql stable security definer set search_path = public as
  \$\$ select platform_role from public.profiles where id = auth.uid() \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, event_type text not null, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned', 'admin_food_order_viewed')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void language sql security definer as
  \$\$ insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.notifications(id bigserial primary key, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_accounts(id uuid primary key);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, primary key (merchant_account_id, user_id));
create table public.food_stores(id uuid primary key, slug text, name text, merchant_account_id uuid, is_open boolean default true, is_published boolean default true,
  admin_suspended_at timestamptz, promptpay_name text, promptpay_id text, bank_name text, bank_account_name text, bank_account_number text);
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null) returns boolean language sql stable security definer set search_path = '' as \$\$
  select exists (select 1 from public.food_stores s join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
    where s.id = p_store_id and m.user_id = auth.uid() and m.active and (p_roles is null or m.role = any(p_roles))) \$\$;
create table public.food_menu_items(id uuid primary key, store_id uuid);
create table public.food_orders(id uuid primary key, order_number text, store_id uuid, status text default 'pending_acceptance',
  payment_status text default 'paid', subtotal numeric(10,2) default 0, delivery_fee numeric(10,2) default 0, total numeric(10,2) default 0);
grant usage on schema public, auth, internal to authenticated, anon;

insert into auth.users values ('$ADMIN'), ('$MOD'), ('$OWNER'), ('$MANAGER'), ('$RIDER'), ('$BUYER');
insert into public.profiles(id, username, platform_role) values ('$ADMIN','admin1','admin'), ('$MOD','mod1','moderator'),
  ('$OWNER','owner1','user'), ('$MANAGER','manager1','user'), ('$RIDER','rider1','user'), ('$BUYER','buyer1','user');
insert into public.merchant_accounts values ('$ACCOUNT');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true), ('$ACCOUNT','$MANAGER','manager',true), ('$ACCOUNT','$RIDER','delivery',true);
insert into public.food_stores(id, slug, name, merchant_account_id, promptpay_name, promptpay_id) values ('$STORE','main','ร้านทดสอบ','$ACCOUNT','ร้านทดสอบ','0812345678');
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_campaign_center_v1.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_platform_campaigns_v1.sql"
# The apply workflow can be dispatched again; a re-run must keep every audit type.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_platform_campaigns_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_db()   { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

UPSERT="public.admin_upsert_platform_campaign"
# Admin designs a campaign: 20% off, max 100, WYNOS funds half.
CID="$(as "$ADMIN" "select $UPSERT(null, 'วันศุกร์ลดแรง', 'ลด 20% ทั้งร้าน', 'percentage', 20, 0, 100, now() - interval '1 hour', null, null, 50, true, true)")"
[[ "$CID" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: admin creates a campaign (got '$CID')"; exit 1; }
expect_fail "$MOD" "select $UPSERT(null, 'x campaign', null, 'fixed', 10, 0, null, now(), null, null, 0, true, true)" "moderator cannot design campaigns" "Only admins can manage WYNOS campaigns"
expect_fail "$ADMIN" "select $UPSERT(null, 'bad share', null, 'fixed', 10, 0, null, now(), null, null, 120, true, true)" "share is 0-100" "food_platform_campaigns_share_check"
expect_eq "$MOD" "select jsonb_array_length(public.admin_platform_campaigns())" "1" "moderator can read campaigns"
expect_fail "$OWNER" "select public.admin_platform_campaigns()" "a store cannot read the admin list" "Not authorized"
expect_db "select count(*) from public.audit_log where event_type = 'admin_platform_campaign_saved'" "1" "saving is audited"
expect_db "insert into public.audit_log(event_type) values ('admin_food_order_viewed') returning 1" "1" "existing audit types still allowed"

# Stores see open campaigns and join; delivery staff cannot.
expect_eq "$RIDER" "select (public.merchant_platform_campaigns('$STORE')->'campaigns'->0->>'joined')" "false" "store staff see the open campaign"
expect_fail "$RIDER" "select public.merchant_join_platform_campaign('$STORE', '$CID')" "delivery staff cannot join" "merchant manager access required"
expect_eq "$MANAGER" "select public.merchant_join_platform_campaign('$STORE', '$CID')::text" "" "manager joins"
expect_eq "$MANAGER" "select public.merchant_join_platform_campaign('$STORE', '$CID')::text" "" "joining twice is harmless"
expect_db "select count(*) || '|' || max(platform_share_percent) from public.food_campaigns where platform_campaign_id = '$CID' and deleted_at is null" "1|50.00" "one enrollment with the share"
expect_eq "$OWNER" "select jsonb_array_length(public.merchant_food_campaigns('$STORE')->'campaigns')" "0" "the store's own promotions list hides the WYNOS campaign"

# The store's own promotion tools cannot change a WYNOS campaign.
SCID="$(db "select id from public.food_campaigns where platform_campaign_id = '$CID'")"
expect_fail "$OWNER" "select public.merchant_set_food_campaign_active('$STORE', '$SCID', false)" "store cannot pause it with promotion tools" "WYNOS campaign terms are managed by WYNOS"
expect_fail "$OWNER" "select public.merchant_delete_food_campaign('$STORE', '$SCID')" "store cannot delete it with promotion tools" "WYNOS campaign terms are managed by WYNOS"

# Pricing uses the existing best-saving rule: 20% of 300 = 60.
expect_db "select campaign_discount from internal.food_campaign_candidates('$STORE', 300, 30, '{}'::jsonb) limit 1" "60.00" "the WYNOS campaign prices like any campaign"

# Orders snapshot WYNOS's half; only delivered orders are owed.
run -q -c "insert into public.food_orders(id, order_number, store_id, subtotal, delivery_fee, total) values ('$O1','1001','$STORE',300,30,270), ('$O2','1002','$STORE',300,30,270);
  insert into public.food_order_campaigns(order_id, campaign_id, campaign_name, campaign_type, campaign_discount, delivery_discount)
    values ('$O1','$SCID','วันศุกร์ลดแรง','percentage',60,0), ('$O2','$SCID','วันศุกร์ลดแรง','percentage',60,0);" >/dev/null
expect_db "select sum(platform_funded) from public.food_order_campaigns" "60.00" "each order records WYNOS's 50% (30 each)"
expect_eq "$OWNER" "select public.merchant_platform_campaigns('$STORE')->>'owed'" "0" "nothing owed before delivery"
run -q -c "update public.food_orders set status = 'delivered' where id = '$O1'; update public.food_orders set status = 'cancelled' where id = '$O2';" >/dev/null
expect_eq "$OWNER" "select public.merchant_platform_campaigns('$STORE')->>'owed'" "30.00" "a delivered order is owed, a cancelled one is not"

# Admin edits terms: joined stores follow for new orders; past orders keep their share.
expect_eq "$ADMIN" "select $UPSERT('$CID', 'วันศุกร์ลดแรง', null, 'percentage', 10, 0, null, now() - interval '1 hour', null, null, 100, true, true) = '$CID'" "t" "admin edits the campaign"
expect_db "select discount_value || '|' || platform_share_percent from public.food_campaigns where id = '$SCID'" "10.00|100.00" "the enrollment follows the new terms"
expect_db "select sum(platform_funded) from public.food_order_campaigns" "60.00" "past orders keep their recorded share"

# Payouts: admin only, need a reference, settle once.
expect_fail "$MOD" "select public.admin_platform_owed()" "moderator cannot see payouts" "Only admins can view WYNOS campaign payouts"
expect_eq "$ADMIN" "select public.admin_platform_owed()->0->>'owed'" "30.00" "admin sees what is owed"
expect_fail "$ADMIN" "select public.admin_settle_platform_store('$STORE', '  ')" "a transfer reference is required" "transfer reference is required"
expect_eq "$ADMIN" "select public.admin_settle_platform_store('$STORE', 'KBANK-123') is not null" "t" "admin records the transfer"
expect_eq "$OWNER" "select (public.merchant_platform_campaigns('$STORE')->>'owed') || '|' || jsonb_array_length(public.merchant_platform_campaigns('$STORE')->'settlements')" "0|1" "the store sees it settled"
expect_fail "$ADMIN" "select public.admin_settle_platform_store('$STORE', 'KBANK-124')" "the same orders cannot be settled twice" "nothing to settle"
expect_db "select count(*) from public.notifications where recipient_id = '$OWNER'" "1" "the owner is notified of the transfer"
expect_db "select count(*) from public.audit_log where event_type = 'admin_platform_campaign_settled'" "1" "settling is audited"

# Food badges, leaving, and access.
expect_eq "$BUYER" "select campaign_name from public.food_platform_campaign_badges()" "วันศุกร์ลดแรง" "customers see the campaign badge"
expect_eq "$MANAGER" "select public.merchant_leave_platform_campaign('$STORE', '$CID')::text" "" "manager leaves"
expect_eq "$BUYER" "select count(*) from public.food_platform_campaign_badges()" "0" "no badge after leaving"
expect_db "select count(*) from internal.food_campaign_candidates('$STORE', 300, 30, '{}'::jsonb)" "0" "no discount after leaving"
expect_db "select has_function_privilege('anon', 'public.admin_settle_platform_store(uuid,text,text)', 'execute')::text || has_function_privilege('anon', 'public.food_platform_campaign_badges()', 'execute')::text" "falsefalse" "anon cannot call the RPCs"

echo "PASS: WYNOS campaigns are Admin-designed, store-joined, hybrid-funded and settled once"


# Internal pricing candidates are server-only; use privileged test execution
# while supplying the buyer identity, rather than granting clients access.
as_internal() { run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1 | tail -n1; }
expect_internal_eq() {
  local got
  got="$(as_internal "$1" "$2")"
  [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }
}

expect_internal_fail() {
  local err
  if err="$(run -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
    echo "FAIL (expected server rejection): $3"
    exit 1
  fi
  [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }
}

# First-order fixed offer integration: exercise the actual additive migration
# on this throwaway PostgreSQL DB, not on Production.
run >/dev/null <<SQL
alter table public.food_orders add column if not exists buyer_id uuid;
alter table public.food_platform_campaigns add column if not exists coupon_required boolean not null default false;
create table public.food_coupon_codes (
  id uuid primary key, platform_campaign_id uuid, code text,
  is_active boolean not null default true, starts_at timestamptz default now(),
  ends_at timestamptz, max_total_uses integer, max_uses_per_user integer
);
create table public.food_coupon_redemptions(order_id uuid, coupon_id uuid, user_id uuid);
create function internal.food_coupon_usage_active(p_order_id uuid)
returns boolean language sql stable as \$\$ select false \$\$;
SQL
run < "$ROOT/supabase/migrations/20261009120000_food_first_order_merchant_funded.sql" >/dev/null
expect_db "select count(*) from public.food_platform_campaigns where first_order_only" "0" "first-order offer starts disabled and is not created by migration"
expect_fail "$MOD" "select public.admin_food_first_order_set_active(true)" "moderators cannot enable the offer" "Only admins"
FIRST_ID="$(as "$ADMIN" "select public.admin_food_first_order_set_active(true)")"
[[ "$FIRST_ID" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: first-order Admin activation returned '$FIRST_ID'"; exit 1; }
expect_db "select campaign_type || '|' || discount_value || '|' || min_subtotal || '|' || platform_share_percent from public.food_platform_campaigns where id='$FIRST_ID'" "fixed|20.00|120.00|0.00" "first-order offer terms are locked and merchant funded"
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "false" "cannot use offer before merchant joins"
expect_eq "$OWNER" "select public.merchant_join_platform_campaign('$STORE','$FIRST_ID')::text" "" "merchant opts in"
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "true" "new buyer eligible at joined store"
# Internal pricing is not directly executable by the authenticated API role:
# quote/create RPCs call it from SECURITY DEFINER. Test it as the DB owner
# while preserving the buyer JWT identity in test.uid.
buyer_db() { run -At -c "select set_config('test.uid','$BUYER',false);" -c "$1" 2>&1 | tail -n1; }
[[ "$(buyer_db "select campaign_discount from internal.food_campaign_candidates('$STORE',120,15,'{}'::jsonb) where campaign_name like 'โปรลูกค้าใหม่%' limit 1")" == "20.00" ]] || { echo "FAIL: threshold 120 discount 20"; exit 1; }
[[ "$(buyer_db "select count(*) from internal.food_campaign_candidates('$STORE',119,15,'{}'::jsonb) where campaign_name like 'โปรลูกค้าใหม่%'")" == "0" ]] || { echo "FAIL: below 120 no first-order discount"; exit 1; }

FIRST_STORE_ID="$(db "select id from public.food_campaigns where platform_campaign_id='$FIRST_ID' and deleted_at is null")"
O3=00000000-0000-0000-0000-000000000103
O4=00000000-0000-0000-0000-000000000104
O5=00000000-0000-0000-0000-000000000105
run -q -c "insert into public.food_orders(id,order_number,store_id,buyer_id,status,payment_status,subtotal,total)
  values ('$O3','1003','$STORE','$BUYER','pending_acceptance','pending',120,100);
  insert into public.food_order_campaigns(order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount)
  values ('$O3','$FIRST_STORE_ID','โปรลูกค้าใหม่','fixed',20,0);" >/dev/null
expect_db "select platform_funded from public.food_order_campaigns where order_id='$O3'" "0.00" "WYNOS bears no part of the discount"
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "false" "pending first order reserves first-order eligibility"
run -q -c "update public.food_orders set status='cancelled',payment_status='pending' where id='$O3';" >/dev/null
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "true" "unpaid cancelled order releases first-order eligibility"
run -q -c "insert into public.food_orders(id,order_number,store_id,buyer_id,status,payment_status,subtotal,total)
  values ('$O4','1004','$STORE','$BUYER','pending_acceptance','pending',120,100);
  insert into public.food_order_campaigns(order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount)
  values ('$O4','$FIRST_STORE_ID','โปรลูกค้าใหม่','fixed',20,0);" >/dev/null
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "false" "a second first-order redemption is ineligible"
expect_internal_fail "$BUYER" "insert into public.food_orders(id,order_number,store_id,buyer_id,status,payment_status,subtotal,total)
  values ('$O5','1005','$STORE','$BUYER','pending_acceptance','pending',120,100);
  insert into public.food_order_campaigns(order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount)
  values ('$O5','$FIRST_STORE_ID','โปรลูกค้าใหม่','fixed',20,0)" "second first-order redemption blocked at server" "first_order_already_used"
run -q -c "update public.food_orders set status='cancelled',payment_status='paid' where id='$O4';" >/dev/null
expect_eq "$BUYER" "select public.food_first_order_offer('$STORE')->>'eligible'" "false" "paid then cancelled order still consumes the one-time benefit"
expect_eq "$ADMIN" "select public.admin_food_first_order_set_active(false)='$FIRST_ID'" "t" "Admin can deactivate"
expect_db "select is_active::text from public.food_campaigns where id='$FIRST_STORE_ID'" "false" "deactivation disables joined store campaign"
echo "PASS: First-order fixed offer integration, merchant cost, cancellation and server redemption enforcement"
