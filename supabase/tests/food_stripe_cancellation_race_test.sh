#!/usr/bin/env bash
# Real PostgreSQL regression for buyer cancellation, manual slips and out-of-order
# Stripe webhooks. Uses a disposable local database with synthetic rows only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
MIGRATION="${FOOD_PAYMENT_RACE_MIGRATION:-$ROOT/supabase/migrations/20261019174958_food_stripe_cancellation_payment_race_guard.sql}"
DB="wyn_food_payment_race_test_$$"

# Refuse accidental execution against a hosted database/service configuration.
if [[ -n "${PGSERVICE:-}" || -n "${PGHOSTADDR:-}" ]]; then
  echo "Use an explicit local PGHOST without PGSERVICE or PGHOSTADDR" >&2
  exit 1
fi
case "${PGHOST:-}" in
  /*|localhost|127.0.0.1|::1) ;;
  *) echo "Set PGHOST to a local Unix socket directory or loopback host" >&2; exit 1 ;;
esac

$PSQL -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -X -d postgres -c "drop database if exists $DB with (force)" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
expect_value() {
  local label="$1" sql="$2" expected="$3" actual
  actual=$(val "$sql")
  [[ "$actual" == "$expected" ]] || fail "$label (expected '$expected', got '$actual')"
  pass "$label"
}
expect_fail() {
  local label="$1" sql="$2" needle="$3" out
  if out=$(val "$sql" 2>&1); then fail "$label (unexpected success)"; fi
  [[ "$out" == *"$needle"* ]] || fail "$label (expected '$needle', got '$out')"
  pass "$label"
}

BUYER=00000000-0000-0000-0000-000000000022
OTHER=00000000-0000-0000-0000-000000000023
STORE=00000000-0000-0000-0000-000000000033
ORDER=00000000-0000-0000-0000-000000000055
AUTH="set role authenticated; set test.uid='$BUYER';"
SERVICE="set role service_role;"

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role bypassrls; exception when duplicate_object then null; end $$;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true),'')::uuid
$$;
create function public.food_customer_access_enabled() returns boolean language sql stable as $$ select true $$;
create function public.food_is_permanent_account() returns boolean language sql stable as $$ select auth.uid() is not null $$;
create table public.food_orders(
  id uuid primary key, store_id uuid, buyer_id uuid, total numeric(10,2),
  status text not null default 'pending_acceptance', payment_status text not null default 'pending',
  cancelled_at timestamptz, payment_provider text, payment_provider_code text,
  payment_transaction_ref text, payment_verified_at timestamptz,
  payment_verification_status text default 'not_started', payment_verification_note text,
  payment_note text, payment_slip_path text, paid_at timestamptz,
  refund_status text not null default 'none', refund_requested_at timestamptz, refunded_at timestamptz,
  stripe_checkout_session_id text, stripe_payment_intent_id text, stripe_refund_id text
);
create table public.food_order_events(order_id uuid,event_type text,from_status text,to_status text,note text,actor_id uuid);
create table public.food_stripe_accounts(store_id uuid primary key,stripe_account_id text);
create table public.food_stripe_webhook_events(event_id text primary key,event_type text,stripe_account_id text,order_id uuid,object_id text);
create table public.food_stripe_payments(
  order_id uuid primary key, store_id uuid, buyer_id uuid, stripe_account_id text,
  checkout_session_id text, payment_intent_id text, amount_satang bigint, currency text,
  status text not null check(status in ('pending','paid','failed','refunded')),
  payment_method text, paid_at timestamptz, refunded_at timestamptz, last_error text,
  updated_at timestamptz default now()
);
alter table public.food_orders enable row level security;
grant usage on schema public,auth to anon,authenticated,service_role;
insert into public.food_stripe_accounts values ('00000000-0000-0000-0000-000000000033','acct_fixture');
insert into public.food_orders(id,store_id,buyer_id,total) values (
  '00000000-0000-0000-0000-000000000055',
  '00000000-0000-0000-0000-000000000033',
  '00000000-0000-0000-0000-000000000022',100
);
SQL

run -f "$MIGRATION" >/dev/null
run -f "$MIGRATION" >/dev/null
pass "migration compiles and applies twice on PostgreSQL"

reset_order() {
  run -c "delete from public.food_stripe_webhook_events; delete from public.food_stripe_payments; delete from public.food_order_events;
    update public.food_orders set status='pending_acceptance',payment_status='pending',cancelled_at=null,
      stripe_checkout_session_id=null,stripe_payment_intent_id=null,stripe_refund_id=null,
      payment_provider=null,payment_provider_code=null,payment_slip_path=null,
      payment_transaction_ref=null,payment_verified_at=null,payment_verification_status='not_started',
      payment_verification_note=null,payment_note=null,paid_at=null,refund_status='none',
      refund_requested_at=null,refunded_at=null where id='$ORDER'" >/dev/null
}
event_sql() {
  local id="$1" state="$2" amount="${3:-10000}" account="${4:-acct_fixture}" currency="${5:-thb}"
  echo "select public.food_apply_stripe_event('$id','fixture.$state','$ORDER','$account','obj_fixture','cs_fixture','pi_fixture',$amount,'$currency','$state','card',null,'re_fixture'); reset role"
}

expect_value "buyer APIs remain authenticated-only and webhook remains service-role-only" \
  "select has_function_privilege('authenticated','public.food_cancel_order(uuid,text)','execute')
    and has_function_privilege('authenticated','public.food_submit_payment(uuid,text)','execute')
    and not has_function_privilege('anon','public.food_cancel_order(uuid,text)','execute')
    and not has_function_privilege('anon','public.food_submit_payment(uuid,text)','execute')
    and not has_function_privilege('authenticated','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute')
    and has_function_privilege('service_role','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute')" "t"
expect_fail "anonymous callers cannot cancel orders" "set role anon; select public.food_cancel_order('$ORDER',null)" "permission denied"
expect_fail "another buyer cannot cancel this order" "set role authenticated; set test.uid='$OTHER'; select public.food_cancel_order('$ORDER',null)" "order not found"
expect_fail "null identity cannot bypass ownership via SQL null comparison" "set role authenticated; set test.uid=''; select public.food_cancel_order('$ORDER',null)" "order not found"
expect_fail "authenticated clients cannot update order rows directly" "$AUTH update public.food_orders set status='cancelled' where id='$ORDER'" "permission denied"

run -c "update public.food_orders set stripe_checkout_session_id='cs_open' where id='$ORDER'" >/dev/null
expect_fail "an active Checkout blocks direct cancellation RPC" "$AUTH select public.food_cancel_order('$ORDER',null)" "cancel stripe checkout before cancelling order"
expect_value "blocked cancellation does not change status or create an event" "select status||'|'||(select count(*) from public.food_order_events) from public.food_orders where id='$ORDER'" "pending_acceptance|0"
expect_fail "an active Checkout blocks manual slip submission" "$AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg')" "cancel stripe checkout before submitting slip"
run -c "update public.food_orders set stripe_checkout_session_id=null where id='$ORDER'" >/dev/null
expect_fail "another buyer cannot submit this order's slip" "set role authenticated; set test.uid='$OTHER'; select public.food_submit_payment('$ORDER','$OTHER/slips/$ORDER/a.jpg')" "order not found"
expect_fail "a buyer cannot submit another buyer's slip path" "$AUTH select public.food_submit_payment('$ORDER','$OTHER/slips/$ORDER/a.jpg')" "invalid slip path"
val "$AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg')" >/dev/null
expect_value "owned manual slip succeeds only when no Checkout remains" "select payment_status||'|'||payment_verification_status from public.food_orders where id='$ORDER'" "submitted|manual_review"
expect_fail "a submitted slip cannot be reset by a second submission" "$AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/b.jpg')" "payment already submitted"

reset_order
val "$AUTH select public.food_cancel_order('$ORDER','fixture cancellation')" >/dev/null
expect_value "owned unpaid order cancels after Checkout cleanup" "select status||'|'||(cancelled_at is not null)::text||'|'||(select count(*) from public.food_order_events) from public.food_orders where id='$ORDER'" "cancelled|true|1"
expect_fail "closed order cannot be cancelled twice" "$AUTH select public.food_cancel_order('$ORDER',null)" "order cannot be cancelled by customer"
expect_value "late paid webhook queues refund without reopening a cancelled order" "$SERVICE $(event_sql evt_late_paid paid); select status||'|'||payment_status||'|'||refund_status||'|'||(refund_requested_at is not null)::text from public.food_orders where id='$ORDER'" $'t\ncancelled|paid|pending|true'
expect_value "exact webhook retry is idempotent" "$SERVICE $(event_sql evt_late_paid paid)" "f"
expect_value "a distinct late failure cannot demote confirmed payment" "$SERVICE $(event_sql evt_later_failed failed); select payment_status||'|'||(select status from public.food_stripe_payments where order_id='$ORDER') from public.food_orders where id='$ORDER'" $'t\npaid|paid'

reset_order
expect_value "full refund can arrive before payment confirmation" "$SERVICE $(event_sql evt_refund_first refunded); select payment_status||'|'||refund_status||'|'||payment_provider||'|'||stripe_payment_intent_id||'|'||stripe_refund_id from public.food_orders where id='$ORDER'" $'t\nrefunded|refunded|stripe|pi_fixture|re_fixture'
expect_value "a distinct paid webhook cannot resurrect a refunded order" "$SERVICE $(event_sql evt_paid_after_refund paid); select payment_status||'|'||(select status from public.food_stripe_payments where order_id='$ORDER') from public.food_orders where id='$ORDER'" $'t\nrefunded|refunded'
expect_value "a distinct failure cannot demote a refunded order" "$SERVICE $(event_sql evt_failure_after_refund failed); select payment_status||'|'||(select status from public.food_stripe_payments where order_id='$ORDER') from public.food_orders where id='$ORDER'" $'t\nrefunded|refunded'
expect_value "all distinct out-of-order events are recorded once" "select count(*) from public.food_stripe_webhook_events" "3"

# Older deployments could record a refund before updating an unpaid order.
# Do not let a later obsolete event turn that inconsistent legacy row paid.
reset_order
val "$SERVICE $(event_sql evt_legacy_refund refunded)" >/dev/null
run -c "update public.food_orders set payment_status='pending',refund_status='none' where id='$ORDER'" >/dev/null
expect_value "a delayed event cannot promote an inconsistent legacy refunded ledger to paid" "$SERVICE $(event_sql evt_legacy_late_paid paid); select payment_status||'|'||(select status from public.food_stripe_payments where order_id='$ORDER') from public.food_orders where id='$ORDER'" $'t\npending|refunded'

reset_order
expect_fail "wrong connected account is rejected" "$SERVICE $(event_sql evt_wrong_account paid 10000 acct_other)" "stripe account mismatch"
expect_fail "wrong paid amount is rejected" "$SERVICE $(event_sql evt_wrong_amount paid 1)" "amount mismatch"
expect_fail "wrong refund amount is rejected" "$SERVICE $(event_sql evt_wrong_refund refunded 1)" "amount mismatch"
expect_fail "wrong currency is rejected" "$SERVICE $(event_sql evt_wrong_currency paid 10000 acct_fixture usd)" "currency mismatch"
expect_value "rejected webhook transactions leave no idempotency tombstone" "select count(*) from public.food_stripe_webhook_events" "0"

# Synchronise on PostgreSQL's observed pg_sleep, rather than hoping two process
# sleeps overlap. Each holder has already performed its mutation and holds the
# order row lock when the competing request starts.
wait_for_holder() {
  local app="$1"
  for ((i=0; i<100; i++)); do
    if [[ "$(val "select exists(select 1 from pg_stat_activity where application_name='$app' and wait_event='PgSleep')")" == "t" ]]; then return; fi
    sleep .02
  done
  fail "concurrent lock holder did not become ready"
}

reset_order
PGAPPNAME=food_race_checkout_holder run -c "begin; update public.food_orders set stripe_checkout_session_id='cs_concurrent' where id='$ORDER'; select pg_sleep(2); commit" >/dev/null &
holder=$!
wait_for_holder food_race_checkout_holder
expect_fail "cancellation waits for concurrent Checkout assignment" "set lock_timeout='150ms'; $AUTH select public.food_cancel_order('$ORDER',null)" "lock timeout"
wait "$holder"
expect_fail "cancellation rechecks the committed session after waiting" "$AUTH select public.food_cancel_order('$ORDER',null)" "cancel stripe checkout before cancelling order"

reset_order
PGAPPNAME=food_race_paid_holder run -c "begin; $SERVICE $(event_sql evt_concurrent_paid paid); select pg_sleep(2); commit" >/dev/null &
holder=$!
wait_for_holder food_race_paid_holder
expect_fail "manual slip waits for concurrent payment confirmation" "set lock_timeout='150ms'; $AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg')" "lock timeout"
# This request must begin before the holder commits. Without SELECT FOR UPDATE
# it reads pending, waits only at UPDATE, and incorrectly overwrites paid.
expect_fail "manual slip rechecks paid state after waiting" "$AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg')" "payment already submitted"
wait "$holder"
expect_value "concurrent payment is not reset to manual review" "select payment_status||'|'||payment_provider from public.food_orders where id='$ORDER'" "paid|stripe"

reset_order
PGAPPNAME=food_race_slip_holder run -c "begin; $AUTH select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg'); select pg_sleep(2); commit" >/dev/null &
holder=$!
wait_for_holder food_race_slip_holder
expect_fail "payment webhook serializes behind manual slip submission" "set lock_timeout='150ms'; $SERVICE $(event_sql evt_after_slip paid)" "lock timeout"
wait "$holder"
expect_value "webhook retry safely confirms payment after slip commit" "$SERVICE $(event_sql evt_after_slip paid); select payment_status||'|'||payment_provider from public.food_orders where id='$ORDER'" $'t\npaid|stripe'

echo "All Food Stripe cancellation/payment race tests passed."
