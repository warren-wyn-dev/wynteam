#!/usr/bin/env bash
# WYNOS Food payment integrity regression (P1 paid-after-cancel, P2 pinned
# guards, P3 merchant payment status, webhook duplicates and ordering).
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/food_payment_integrity_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_payment_integrity_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1" | tail -1; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
# Runs SQL as a role (and user) and prints the error message, empty on success.
err() { # role uid sql
  run -At -c "set role $1; set test.uid='$2'; $3" 2>&1 | sed -n 's/^ERROR: *//p' | head -1 || true
}
expect_error() { # label role uid sql expected
  local got; got=$(err "$2" "$3" "$4")
  [ "$got" = "$5" ] || fail "$1 (expected '$5', got '$got')"
  pass "$1"
}
expect_ok() { # label role uid sql
  local got; got=$(err "$2" "$3" "$4")
  [ -z "$got" ] || fail "$1 (unexpected error '$got')"
  pass "$1"
}

OWNER=00000000-0000-0000-0000-000000000011
BUYER=00000000-0000-0000-0000-000000000022
STORE=00000000-0000-0000-0000-000000000033
ACCOUNT=00000000-0000-0000-0000-000000000044
ORDER=00000000-0000-0000-0000-000000000055

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table auth.users(id uuid primary key);
create table public.profiles(id uuid primary key);
create table public.merchant_accounts(id uuid primary key);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true);
create table public.merchant_notifications(merchant_account_id uuid, recipient_user_id uuid, type text, reason text);
create table public.notifications(recipient_id uuid, actor_id uuid, type text, reason text);
create table public.food_stores(id uuid primary key, merchant_account_id uuid, name text, latitude double precision,
  longitude double precision, promptpay_id text, is_published boolean default true);
create table public.food_menu_items(id uuid primary key, store_id uuid);
create table public.food_orders(
  id uuid primary key, order_number text, store_id uuid, buyer_id uuid, total numeric(10,2),
  source text default 'app', status text default 'pending_acceptance', payment_status text default 'pending',
  payment_provider text, payment_provider_code text, payment_transaction_ref text, payment_verified_at timestamptz,
  payment_verification_status text default 'not_started', payment_verification_note text, payment_note text,
  payment_slip_path text, paid_at timestamptz, eta_minutes integer, accepted_at timestamptz, ready_at timestamptz,
  out_for_delivery_at timestamptz, cancelled_at timestamptz, refund_status text not null default 'none',
  refund_note text, refund_requested_at timestamptz, refunded_at timestamptz, refund_updated_by uuid);
create table public.food_order_events(order_id uuid, event_type text, from_status text, to_status text, note text, actor_id uuid);
create function public.food_is_permanent_account() returns boolean language sql stable as \$\$ select auth.uid() is not null \$\$;
create function public.food_customer_access_enabled() returns boolean language sql stable as \$\$ select auth.uid() is not null \$\$;
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path='' as \$\$
  select exists(select 1 from public.food_stores s
    join public.merchant_memberships m on m.merchant_account_id=s.merchant_account_id
    where s.id=p_store_id and m.user_id=auth.uid() and m.active and (p_roles is null or m.role=any(p_roles)))
\$\$;
grant usage on schema public, auth, internal to authenticated, anon, service_role;
grant select on all tables in schema public to authenticated;
insert into auth.users values ('$OWNER'),('$BUYER');
insert into public.profiles values ('$OWNER'),('$BUYER');
insert into public.merchant_accounts values ('$ACCOUNT');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true);
insert into public.food_stores(id,merchant_account_id,name) values ('$STORE','$ACCOUNT','ร้านทดสอบ');
SQL

# Live predecessors: Stripe core, the customer cancel RPC and the store
# transition RPC, exactly as the repo defines them.
run >/dev/null < "$ROOT/supabase/migrations_wynos_stripe_payment_core_v1.sql"
awk '/^create or replace function public.food_cancel_order/,/^\$\$;/' \
  "$ROOT/supabase/migrations_wynos_food_customer_access_gate_v2.sql" | run >/dev/null
awk '/^create or replace function public.food_transition_order/,/^\$\$;/' \
  "$ROOT/supabase/migrations_wynos_merchant_core_completion_v1.sql" | run >/dev/null
run >/dev/null -c "grant execute on function public.food_cancel_order(uuid,text), public.food_transition_order(uuid,text,integer,text) to authenticated;
  insert into public.food_stripe_accounts(store_id,stripe_account_id,status) values ('$STORE','acct_test','ready');"

A="$ROOT/supabase/migrations/20261012090000_food_payment_integrity_v1.sql"
B="$ROOT/supabase/migrations/20261012090100_food_cancel_requires_closed_checkout.sql"
for f in "$A" "$A" "$B" "$B"; do run >/dev/null < "$f"; done
pass "both migrations apply and re-apply"

reset_order() { # status payment_status session slip provider
  run >/dev/null -c "delete from public.food_order_events; delete from public.merchant_notifications;
    delete from public.notifications; delete from public.food_stripe_payments; delete from public.food_stripe_webhook_events;
    delete from public.food_orders;
    insert into public.food_orders(id,order_number,store_id,buyer_id,total,status,payment_status,stripe_checkout_session_id,payment_slip_path,payment_provider)
    values ('$ORDER','WF1','$STORE','$BUYER',125.50,'$1','$2',${3:-null},${4:-null},${5:-null});"
}
event() { # id type state amount [session]
  err service_role "" "select public.food_apply_stripe_event('$1','$2','$ORDER','acct_test','obj','${5:-cs_1}','${5:-cs_1}_pi','$4','thb','$3')"
}
state() { val "select status||'|'||payment_status||'|'||refund_status||'|'||coalesce(payment_provider,'-') from public.food_orders where id='$ORDER'"; }

# --- P1 prevention: no cancel while Checkout is open -------------------------
reset_order pending_acceptance pending "'cs_1'"
expect_error "buyer cannot cancel while Stripe Checkout is open" authenticated "$BUYER" \
  "select public.food_cancel_order('$ORDER','x')" "stripe checkout still open"
run >/dev/null -c "update public.food_orders set stripe_checkout_session_id=null where id='$ORDER'"
expect_ok "cancel works once food-stripe-cancel cleared the session" authenticated "$BUYER" \
  "select public.food_cancel_order('$ORDER','x')"
reset_order pending_acceptance pending "'cs_1'"
expect_ok "10-minute timeout worker stays exempt" postgres "" \
  "select set_config('wynos.food_auto_cancel','on',true); update public.food_orders set status='cancelled' where id='$ORDER'"
reset_order pending_acceptance pending "'cs_1'"
expect_ok "store cancel is not blocked (late payment is auto-refunded)" authenticated "$OWNER" \
  "select public.food_transition_order('$ORDER','cancelled',null,null)"
reset_order pending_acceptance paid "'cs_1'" null "'stripe'"
expect_ok "store can cancel a paid order (refund flow)" authenticated "$OWNER" \
  "select public.food_transition_order('$ORDER','cancelled',null,null)"

# --- P1 webhook side: paid after cancel is flagged for refund ----------------
reset_order cancelled pending "'cs_1'"
[ -z "$(event evt_1 checkout.session.completed paid 12550)" ] || fail "paid event on cancelled order applies"
[ "$(state)" = "cancelled|paid|pending|stripe" ] || fail "paid after cancel flags refund (got $(state))"
[ "$(val "select count(*) from public.food_order_events where event_type='paid_after_cancel'")" = "1" ] || fail "paid_after_cancel event"
[ "$(val "select count(*) from public.merchant_notifications where type='payment'")" = "1" ] || fail "store notified"
[ "$(val "select count(*) from public.notifications where recipient_id='$BUYER'")" = "1" ] || fail "buyer notified"
pass "paid after cancel: recorded, refund pending, event, store and buyer notified"
[ "$(val "set role service_role; select public.food_apply_stripe_event('evt_1','checkout.session.completed','$ORDER','acct_test','obj','cs_1','cs_1_pi',12550,'thb','paid')")" = "f" ] \
  || fail "duplicate event id is ignored"
[ "$(val "select count(*) from public.food_order_events where event_type='paid_after_cancel'")" = "1" ] || fail "no second event"
pass "duplicate webhook delivery is ignored"

# --- Webhook ordering and amounts --------------------------------------------
reset_order pending_acceptance pending "'cs_1'"
[ -z "$(event evt_p checkout.session.completed paid 12550)" ] || fail "paid"
[ -z "$(event evt_f payment_intent.payment_failed failed 12550)" ] || fail "late failed"
[ "$(state)" = "pending_acceptance|paid|none|stripe" ] || fail "late failure keeps order paid"
[ "$(val "select status from public.food_stripe_payments where order_id='$ORDER'")" = "paid" ] || fail "late failure keeps ledger paid"
pass "late failure after payment downgrades neither order nor ledger"

reset_order pending_acceptance pending "'cs_1'"
[ "$(event evt_r refund.updated refunded 12550)" = "refund before payment recorded" ] || fail "early refund raises"
[ "$(val "select count(*) from public.food_stripe_webhook_events where event_id='evt_r'")" = "0" ] || fail "early refund not consumed"
[ -z "$(event evt_p2 checkout.session.completed paid 12550)" ] || fail "paid"
[ -z "$(event evt_r refund.updated refunded 12550)" ] || fail "redelivered refund applies"
[ "$(state)" = "pending_acceptance|refunded|refunded|stripe" ] || fail "refund applied after payment (got $(state))"
pass "refund that arrives before payment is retried, then applies"

reset_order pending_acceptance pending "'cs_1'"
[ "$(event evt_a checkout.session.completed paid 100)" = "amount mismatch" ] || fail "amount mismatch"
pass "amount mismatch is rejected"

# --- Slip under review + Stripe payment --------------------------------------
reset_order pending_acceptance submitted "'cs_1'" "'$BUYER/slips/$ORDER/a.webp'"
[ -z "$(event evt_d checkout.session.completed paid 12550)" ] || fail "paid on submitted"
[ "$(val "select count(*) from public.food_order_events where event_type='duplicate_payment_risk'")" = "1" ] || fail "duplicate risk event"
pass "Stripe payment during slip review is flagged duplicate_payment_risk"

# --- P2: slip guard pinned; legacy re-apply is detectable --------------------
reset_order pending_acceptance pending "'cs_1'"
expect_error "slip refused while Checkout is open" authenticated "$BUYER" \
  "select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.webp')" "cancel stripe checkout before submitting slip"
awk '/^create or replace function public.food_submit_payment/,/^\$\$;/' \
  "$ROOT/supabase/migrations_wynos_food_order_options_v1.sql" | run >/dev/null
[ "$(val "select pg_get_functiondef('public.food_submit_payment(uuid,text)'::regprocedure) like '%cancel stripe checkout before submitting slip%'")" = "f" ] \
  || fail "legacy re-apply drops the guard"
run >/dev/null < "$A"
[ "$(val "select pg_get_functiondef('public.food_submit_payment(uuid,text)'::regprocedure) like '%cancel stripe checkout before submitting slip%'")" = "t" ] \
  || fail "re-running the migration restores the guard"
pass "legacy re-apply drops the slip guard; re-running the migration restores it"

# --- P3: merchant payment status ---------------------------------------------
reset_order cancelled pending
expect_error "store cannot mark a cancelled order paid" authenticated "$OWNER" \
  "select public.food_set_payment_status('$ORDER','paid','x')" "order is cancelled"
reset_order pending_acceptance pending
expect_error "store cannot mark an unpaid order refunded" authenticated "$OWNER" \
  "select public.food_set_payment_status('$ORDER','refunded','x')" "order is not paid"
expect_ok "store can still confirm a manual payment" authenticated "$OWNER" \
  "select public.food_set_payment_status('$ORDER','paid','โอนแล้ว')"
reset_order pending_acceptance paid null null "'stripe'"
expect_error "store cannot touch a Stripe payment" authenticated "$OWNER" \
  "select public.food_set_payment_status('$ORDER','issue','x')" "stripe payment status is managed by webhook"
expect_error "buyer has no store role" authenticated "$BUYER" \
  "select public.food_set_payment_status('$ORDER','paid','x')" "order management role required"

# --- Privileges ----------------------------------------------------------------
[ "$(val "select has_function_privilege('anon','public.food_submit_payment(uuid,text)','execute')
        or has_function_privilege('anon','public.food_set_payment_status(uuid,text,text)','execute')
        or has_function_privilege('authenticated','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute')")" = "f" ] \
  || fail "privileges"
pass "anon cannot call payment RPCs; only service_role applies Stripe events"

echo "All food payment integrity tests passed."
