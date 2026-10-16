#!/usr/bin/env bash
# Food payment slip hardening on disposable Postgres, using actual migrated RPC.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="wyn_slip_object_test_$$"
psql -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap 'psql -q -X -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run(){ psql -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
as_user(){ run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2"; }
fail(){ echo "FAIL: $*" >&2; exit 1; }
deny(){ local output; if output="$(as_user "$1" "$2" 2>&1)"; then fail "$3 was allowed"; fi
  [[ "$output" == *"$4"* ]] || fail "$3: expected $4, got $output"; echo "ok - $3"; }
ok(){ as_user "$1" "$2" >/dev/null || fail "$3"; echo "ok - $3"; }
val(){ run -At -c "$1" | tail -1; }
USER_A=00000000-0000-0000-0000-0000000000a1
USER_B=00000000-0000-0000-0000-0000000000b1
ORDER=00000000-0000-0000-0000-0000000000f1
CANCEL=00000000-0000-0000-0000-0000000000f2
STRIPE=00000000-0000-0000-0000-0000000000f3
run >/dev/null <<SQL
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema storage;
create function auth.uid() returns uuid language sql stable as
  \$\$select nullif(current_setting('test.uid',true),'')::uuid\$\$;
grant usage on schema auth,storage to authenticated;
create table storage.objects(bucket_id text, name text);
create table public.food_orders(
  id uuid primary key,buyer_id uuid,status text default 'pending_acceptance',
  payment_status text default 'pending',stripe_checkout_session_id text,
  payment_slip_path text,payment_note text,payment_verification_status text,
  payment_provider text,payment_provider_code text,payment_transaction_ref text,
  payment_verified_at timestamptz,payment_verification_note text
);
create table public.food_order_events(order_id uuid,event_type text,note text,actor_id uuid);
create function public.food_is_permanent_account() returns boolean language sql stable
  as \$\$select auth.uid() is not null\$\$;
insert into public.food_orders(id,buyer_id) values('$ORDER','$USER_A');
insert into public.food_orders(id,buyer_id,status) values('$CANCEL','$USER_A','cancelled');
insert into public.food_orders(id,buyer_id,stripe_checkout_session_id)
  values('$STRIPE','$USER_A','cs_test_open');
SQL
# Extract real implementation. Fail if the selected migration body isn't present.
awk '
  /^create or replace function public\.food_submit_payment\(/ { reading=1 }
  reading { print }
  reading && /^\$\$;[[:space:]]*$/ { done=1; exit }
  END { if (!done) exit 42 }
' "$ROOT/supabase/migrations/20261008234500_food_verify_uploaded_payment_slip.sql" | run >/dev/null

SLIP="$USER_A/slips/$ORDER/paid.png"
deny "$USER_B" "select public.food_submit_payment('$ORDER','$USER_B/slips/$ORDER/paid.png')" \
 "other buyer cannot submit" "order not found"
deny "$USER_A" "select public.food_submit_payment('$ORDER','$SLIP')" \
 "path without upload fails" "payment slip file not uploaded"
[[ "$(val "select payment_status from food_orders where id='$ORDER'")" == "pending" ]] || fail "missing object changed order"
run -c "insert into storage.objects values('food-public','$SLIP')" >/dev/null
deny "$USER_A" "select public.food_submit_payment('$ORDER','$SLIP')" \
 "object in public bucket is not proof" "payment slip file not uploaded"
run -c "insert into storage.objects values('food-private','$SLIP')" >/dev/null
deny "$USER_A" "select public.food_submit_payment('$ORDER','$USER_B/slips/$ORDER/foreign.png')" \
 "foreign slip path refused" "invalid slip path"
ok "$USER_A" "select public.food_submit_payment('$ORDER','$SLIP')" \
 "actual private upload accepted"
[[ "$(val "select payment_status||'|'||payment_slip_path from food_orders where id='$ORDER'")" == "submitted|$SLIP" ]] || fail "valid upload not saved"
[[ "$(val "select count(*) from food_order_events where order_id='$ORDER' and event_type='payment_submitted'")" == 1 ]] || fail "event not recorded exactly once"
deny "$USER_A" "select public.food_submit_payment('$ORDER','$SLIP')" \
 "second submission refused" "payment already submitted"
deny "$USER_A" "select public.food_submit_payment('$CANCEL','$USER_A/slips/$CANCEL/paid.png')" \
 "cancelled order cannot accept slip" "order is closed"
deny "$USER_A" "select public.food_submit_payment('$STRIPE','$USER_A/slips/$STRIPE/paid.png')" \
 "open Stripe session blocks slip" "cancel stripe checkout before submitting slip"
echo "PASS: private Storage object presence, owner, bucket, status, Stripe fallback and duplicate submit"
