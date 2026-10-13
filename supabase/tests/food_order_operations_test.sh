#!/usr/bin/env bash
# Order operations regression tests; synthetic data in a disposable local DB.
# PSQL must point at a LOCAL PostgreSQL client/wrapper, never a hosted database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_operations_test_$$"
$PSQL -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -X -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
expect_db() { [ "$(val "$1")" = "$2" ] || fail "$3"; pass "$3"; }
as_user() { run -At -c "set role authenticated; set test.uid='$1'; $2"; }
expect_error() {
  local output
  if output=$(as_user "$2" "$3" 2>&1); then fail "$1 (unexpected success)"; fi
  [[ "$output" == *"$4"* ]] || fail "$1 (got $output)"
  pass "$1"
}
OWNER=00000000-0000-0000-0000-000000000001
BUYER=00000000-0000-0000-0000-000000000002
OTHER=00000000-0000-0000-0000-000000000003
STORE=00000000-0000-0000-0000-000000000011
STORE2=00000000-0000-0000-0000-000000000012
ORDER=00000000-0000-0000-0000-000000000021
PAID=00000000-0000-0000-0000-000000000022
PROPOSAL_ORDER=00000000-0000-0000-0000-000000000023
ITEM=00000000-0000-0000-0000-000000000031
KEY=00000000-0000-0000-0000-000000000041
KEY2=00000000-0000-0000-0000-000000000042

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as
  \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, developer boolean not null default false);
create table public.food_stores(id uuid primary key, is_open boolean not null default true,
  prep_time_min_minutes integer not null default 15, prep_time_max_minutes integer not null default 30,
  temporary_closed_until timestamptz, temporary_closed_reason text,
  constraint prep_range check (prep_time_min_minutes between 1 and 240
    and prep_time_max_minutes between prep_time_min_minutes and 240));
create table public.test_store_roles(store_id uuid, user_id uuid, role text);
create function public.is_developer_account() returns boolean language sql stable security definer
set search_path='' as \$\$ select coalesce((select developer from public.profiles where id=auth.uid()),false) \$\$;
create function public.merchant_has_store_role(p_store_id uuid,p_roles text[]) returns boolean
language sql stable security definer set search_path='' as \$\$
  select exists(select 1 from public.test_store_roles where store_id=p_store_id
    and user_id=auth.uid() and role=any(p_roles)) \$\$;
create table public.food_development_features(name text primary key, enabled boolean not null default false,
  developer_only boolean not null default true);
alter table public.food_development_features enable row level security;
revoke all on public.food_development_features from public,anon,authenticated;
create function internal.food_development_feature_enabled(p_name text) returns boolean
language sql stable security definer set search_path='' as \$\$
  select coalesce((select enabled and (not developer_only or public.is_developer_account())
    from public.food_development_features where name=p_name),false) \$\$;
revoke all on function internal.food_development_feature_enabled(text) from public,anon,authenticated;
create table public.food_orders(id uuid primary key default gen_random_uuid(), store_id uuid references public.food_stores(id),
  buyer_id uuid references public.profiles(id), status text not null default 'pending_acceptance'
    check(status in ('pending_acceptance','preparing','ready_for_delivery','out_for_delivery','delivered','cancelled')),
  payment_status text not null default 'pending'
    check(payment_status in ('pending','submitted','paid','issue','refunded')),
  refund_status text not null default 'none' check(refund_status in ('none','pending','refunded','failed')),
  eta_minutes integer, accepted_at timestamptz, ready_at timestamptz, out_for_delivery_at timestamptz,
  delivered_at timestamptz, cancelled_at timestamptz, paid_at timestamptz, refund_requested_at timestamptz,
  total numeric(10,2) not null default 120, created_at timestamptz default now());
create table public.food_order_items(id uuid primary key, order_id uuid references public.food_orders(id),
  item_name text not null, unit_price numeric(10,2) not null, quantity integer not null,
  selected_options jsonb not null default '[]');
create table public.food_order_events(id bigint generated always as identity primary key,
  order_id uuid, event_type text, from_status text,to_status text,note text,actor_id uuid);
create function public.food_can_view_order(p_order_id uuid) returns boolean
language sql stable security definer set search_path='' as \$\$
  select exists(select 1 from public.food_orders where id=p_order_id
    and (buyer_id=auth.uid() or public.merchant_has_store_role(store_id,array['owner','admin','manager','orders']))) \$\$;
grant usage on schema public,auth,internal to authenticated,anon;
insert into public.profiles values ('$OWNER',true),('$BUYER',true),('$OTHER',false);
insert into public.food_stores(id) values ('$STORE'),('$STORE2');
insert into public.test_store_roles values ('$STORE','$OWNER','owner'),('$STORE2','$OTHER','owner');
insert into public.food_orders(id,store_id,buyer_id) values ('$ORDER','$STORE','$BUYER');
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013050000_food_order_operations.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013050000_food_order_operations.sql"
pass "migration applies twice"
expect_db "select count(*) from public.food_development_features where enabled" "0" "all new feature flags default OFF"
expect_db "select auto_accept_enabled::text||'|'||(acceptance_timeout_minutes is null)::text from public.food_stores where id='$STORE'" "false|true" "auto-accept OFF and timeout unconfigured"
expect_db "select fulfillment_mode||'|'||(acceptance_due_at is null)::text from public.food_orders where id='$ORDER'" "merchant_delivery|true" "existing self-delivery order stays compatible without retroactive timeout"

expect_error "cross-store access rejected" "$OTHER" "select public.food_transition_order('$ORDER','preparing',20)" "order management role required"
expect_error "null target status rejected" "$OWNER" "select public.food_transition_order('$ORDER',null,20)" "invalid order transition"
expect_error "unpaid acceptance rejected" "$OWNER" "select public.food_transition_order('$ORDER','preparing',20)" "payment must be verified first"
expect_error "skip to ready rejected" "$OWNER" "select public.food_transition_order('$ORDER','ready_for_delivery')" "invalid order transition"
expect_error "strict rejection requires reason" "$OWNER" "select public.food_reject_order('$ORDER',E' \t\n')" "rejection reason is required"
expect_error "invalid ETA rejected" "$OWNER" "select public.food_transition_order('$ORDER','preparing',0)" "invalid ETA"
run -c "update public.food_orders set payment_status='paid' where id='$ORDER'" >/dev/null
as_user "$OWNER" "select public.food_transition_order('$ORDER','preparing',25)" >/dev/null
expect_db "select status||'|'||eta_minutes||'|'||(accepted_at is not null)::text from public.food_orders where id='$ORDER'" "preparing|25|true" "paid order accepted with preparation time"
expect_error "null prep-time update rejected" "$OWNER" "select public.food_adjust_preparation_time('$ORDER',null)" "invalid ETA"
as_user "$OWNER" "select public.food_adjust_preparation_time('$ORDER',35)" >/dev/null
expect_db "select eta_minutes from public.food_orders where id='$ORDER'" "35" "preparation-time update succeeds"
expect_db "select count(*) from public.food_order_events where order_id='$ORDER' and event_type='preparation_time_changed'" "1" "preparation-time update audited"
as_user "$OWNER" "select public.food_transition_order('$ORDER','ready_for_delivery'); select public.food_transition_order('$ORDER','out_for_delivery')" >/dev/null
expect_error "prep update after dispatch rejected" "$OWNER" "select public.food_adjust_preparation_time('$ORDER',15)" "order is not preparing"
run -c "update public.food_orders set status='delivered',delivered_at=now() where id='$ORDER'" >/dev/null
expect_error "terminal order cannot reopen" "$OWNER" "select public.food_transition_order('$ORDER','preparing',20)" "invalid order transition"
if run -c "update public.food_orders set status='pending_acceptance' where id='$ORDER'" >/dev/null 2>&1; then fail "privileged direct transition bypass"; fi
pass "state guard also blocks privileged invalid update"

run -c "set test.uid='$OWNER'; update public.food_development_features set enabled=true where name='acceptance_timeout_reporting'; update public.food_stores set acceptance_timeout_minutes=17 where id='$STORE';
  insert into public.food_orders(id,store_id,buyer_id,payment_status,paid_at)
  values ('$PAID','$STORE','$BUYER','paid',now())" >/dev/null
expect_db "select (acceptance_due_at between now()+interval '16 minutes' and now()+interval '18 minutes')::text from public.food_orders where id='$PAID'" "true" "explicitly configured acceptance deadline snapshotted for newly paid order"
expect_db "select (acceptance_due_at is null)::text from public.food_orders where id='$ORDER'" "true" "older paid order is not backfilled"
if run -c "set wynos.food_auto_cancel='on'; update public.food_orders set status='cancelled' where id='$PAID'" >/dev/null 2>&1; then fail "paid auto-timeout cancellation"; fi
pass "automatic cancellation of paid order blocked"
as_user "$OWNER" "select public.food_reject_order('$PAID','  อาหารหมด  ')" >/dev/null
expect_db "select status||'|'||payment_status||'|'||refund_status||'|'||cancellation_reason from public.food_orders where id='$PAID'" "cancelled|paid|pending|อาหารหมด" "paid rejection records reason and pending refund without claiming money returned"
if run -c "insert into public.food_orders(store_id,buyer_id,fulfillment_mode) values ('$STORE','$BUYER','customer_pickup')" >/dev/null 2>&1; then fail "unimplemented pickup enabled"; fi
pass "unimplemented pickup cannot be selected"
run -c "update public.food_development_features set enabled=true where name='wynos_rider'" >/dev/null
if run -c "insert into public.food_orders(store_id,buyer_id,fulfillment_mode) values ('$STORE','$BUYER','wynos_rider')" >/dev/null 2>&1; then fail "unimplemented rider flag bypass"; fi
pass "flag alone cannot activate unimplemented rider"
expect_error "busy mode feature flag enforced" "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','prep',25,45)" "busy mode is not enabled"
run -c "update public.food_development_features set enabled=true where name='busy_mode'" >/dev/null
expect_error "busy mode developer restriction enforced" "$OTHER" "select public.merchant_set_food_busy_mode('$STORE2','prep',25,45)" "busy mode is not enabled"
as_user "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','prep',25,45)" >/dev/null
expect_db "select busy_mode||'|'||prep_time_min_minutes||'|'||prep_time_max_minutes||'|'||is_open::text from public.food_stores where id='$STORE'" "prep|25|45|true" "busy prep reuses canonical range without closing shop"
expect_error "busy preparation cannot decrease" "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','prep',15,30)" "must not decrease"
expect_error "busy pause needs explicit future deadline" "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','pause')" "future pause deadline required"
as_user "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','pause',null,null,now()+interval '20 minutes')" >/dev/null
expect_db "select busy_mode||'|'||(temporary_closed_until>now())::text from public.food_stores where id='$STORE'" "pause|true" "busy pause uses existing closure observed by Food guards"
as_user "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','off',15,30)" >/dev/null
expect_db "select busy_mode||'|'||(temporary_closed_until is null)::text||'|'||prep_time_max_minutes from public.food_stores where id='$STORE'" "off|true|30" "busy resume clears its closure and restores explicit prep range"
run -c "update public.food_stores set temporary_closed_until=now()+interval '1 hour',temporary_closed_reason='วันหยุดพิเศษ' where id='$STORE'" >/dev/null
expect_error "busy mode preserves manual temporary closure" "$OWNER" "select public.merchant_set_food_busy_mode('$STORE','pause',null,null,now()+interval '20 minutes')" "store already has a temporary closure"

run -c "insert into public.food_orders(id,store_id,buyer_id,status,payment_status,paid_at)
  values ('$PROPOSAL_ORDER','$STORE','$BUYER','preparing','paid',now());
  insert into public.food_order_items values ('$ITEM','$PROPOSAL_ORDER','ข้าวกะเพรา',60,2,'[]')" >/dev/null
ITEMS='[{"order_item_id":"'$ITEM'","quantity":1,"unit_price":0}]'
PROPOSE="select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY','อาหารเหลือหนึ่งจาน','$ITEMS')"
expect_error "proposal feature flag enforced" "$OWNER" "$PROPOSE" "order modifications are not enabled"
run -c "update public.food_development_features set enabled=true where name='order_modifications'" >/dev/null
expect_error "cross-store proposal rejected" "$OTHER" "$PROPOSE" "order management role required"
expect_error "proposal cannot increase quantity" "$OWNER" "select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY','เพิ่ม','[{\"order_item_id\":\"$ITEM\",\"quantity\":3}]')" "only quantity reductions are supported"
expect_error "proposal validates ownership of item" "$OWNER" "select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY','หมด','[{\"order_item_id\":\"$KEY2\",\"quantity\":0}]')" "only quantity reductions are supported"
MOD=$(as_user "$OWNER" "$PROPOSE" | tail -1)
[ -n "$MOD" ] || fail "proposal created"
expect_db "select proposed_items->0->>'unit_price' from public.food_order_modifications where id='$MOD'" "60.00" "proposal ignores forged client price and snapshots real order price"
[ "$(as_user "$OWNER" "$PROPOSE" | tail -1)" = "$MOD" ] || fail "proposal retry idempotent"
pass "proposal retries return same request"
expect_error "idempotency key cannot change proposal" "$OWNER" "select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY','เปลี่ยนเหตุผล','$ITEMS')" "request key was reused with different input"
expect_error "second active proposal blocked" "$OWNER" "select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY2','หมด','$ITEMS')" "already has an active modification"
expect_error "other buyer cannot answer" "$OTHER" "select public.food_respond_order_modification('$MOD',false)" "modification not found"
expect_error "customer decision cannot be null" "$BUYER" "select public.food_respond_order_modification('$MOD',null)" "customer decision is required"
[ "$(as_user "$BUYER" "select public.food_respond_order_modification('$MOD',false)" | tail -1)" = "rejected" ] || fail "buyer rejection"
pass "customer can reject request"
[ "$(as_user "$BUYER" "select public.food_respond_order_modification('$MOD',false)" | tail -1)" = "rejected" ] || fail "response retry"
pass "customer response retries idempotent"
expect_error "customer cannot reverse rejection" "$BUYER" "select public.food_respond_order_modification('$MOD',true)" "already answered"
expect_db "select quantity||'|'||unit_price from public.food_order_items where id='$ITEM'" "2|60.00" "rejection leaves order items unchanged"
MOD2=$(as_user "$OWNER" "select public.merchant_propose_food_order_modification('$PROPOSAL_ORDER','$KEY2','หมด','$ITEMS')" | tail -1)
[ "$(as_user "$BUYER" "select public.food_respond_order_modification('$MOD2',true)" | tail -1)" = "accepted_pending_execution" ] || fail "consent record"
pass "customer consent remains explicitly unapplied"
expect_db "select total||'|'||payment_status from public.food_orders where id='$PROPOSAL_ORDER'" "120.00|paid" "consent does not reprice or charge paid order"
expect_db "select quantity from public.food_order_items where id='$ITEM'" "2" "consent does not modify order items"
expect_db "select count(*) from public.food_order_events where order_id='$PROPOSAL_ORDER' and event_type like 'modification_%'" "4" "proposal and response audit events recorded"
expect_db "select has_table_privilege('authenticated','public.food_order_modifications','INSERT')::text" "false" "proposal direct writes denied"
expect_db "select has_function_privilege('anon','public.food_reject_order(uuid,text)','EXECUTE')::text" "false" "anonymous rejection denied"
[ "$(as_user "$OTHER" "select count(*) from public.food_order_modifications" | tail -1)" = "0" ] || fail "RLS cross-store leak"
pass "RLS hides other store modification records"
[ "$(as_user "$BUYER" "select count(*) from public.food_order_modifications" | tail -1)" = "2" ] || fail "RLS customer visibility"
pass "RLS permits order buyer to view own modification records"
run -c "update public.food_development_features set enabled=false where name='acceptance_timeout_reporting'" >/dev/null
expect_error "overdue reporting feature gate enforced" "$OWNER" "select * from public.merchant_food_acceptance_overdue('$STORE')" "acceptance timeout reporting is not enabled"
run -c "update public.food_development_features set enabled=true where name='acceptance_timeout_reporting';
  insert into public.food_orders(store_id,buyer_id,payment_status,paid_at,acceptance_due_at)
  values ('$STORE','$BUYER','paid',now(),now()-interval '1 minute')" >/dev/null
[ "$(as_user "$OWNER" "select count(*) from public.merchant_food_acceptance_overdue('$STORE')" | tail -1)" = "1" ] || fail "overdue report"
pass "overdue reporting observes paid order without changing it"
expect_db "select count(*) from public.food_orders where status='pending_acceptance' and payment_status='paid' and acceptance_due_at<now()" "1" "paid overdue order remains active"
echo "All Food order operations tests passed."
