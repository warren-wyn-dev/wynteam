#!/usr/bin/env bash
# ZOKY Stripe jobs + automatic refund + Stripe-only policy
# (supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql,
#  20261023100200_food_stripe_only_activate.sql and the rollbacks).
#
#   1. Install is idempotent; new tables have RLS on and no client grants;
#      worker RPCs are service-role only; public RPCs return booleans only.
#   2. Jobs: expire_checkout on any cancel with a session (deduped), refund on
#      store cancel of a Stripe-paid order, paid-after-cancel stays cancelled
#      and is refunded, duplicate payment parked, manual orders untouched.
#   3. Claim: SKIP LOCKED + lease; attempts, backoff, max 8 -> failed with
#      order refund_status failed + notifications; refund_requested / refunded /
#      done outcomes; replays are no-ops.
#   4. merchant_retry_stripe_refund: role-checked, requeue only.
#   5. Policy off = legacy; policy on = order gate, slip/manual block, legacy
#      in-flight slip exception, manual orders excluded.
#   6. Vault cron key + tick; rollback keeps tables and restores legacy.
# Synthetic data only. Usage: PSQL="sudo -u postgres psql" supabase/tests/food_stripe_auto_refund_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="food_stripe_auto_refund_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB with (force)" >/dev/null 2>&1 || true' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
q() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
eq() { [[ "$1" == "$2" ]] || fail "$3 (got '$1', want '$2')"; pass "$3"; }
# as <role> <uid> <sql>: run as a client role with auth.uid()/auth.role() set.
as() { run -At -c "select set_config('test.uid','$2',false), set_config('test.role','$1',false);" -c "set role $1;" -c "$3" 2>&1 | tail -n1; }
expect_fail() {
  local label="$1" role="$2" uid="$3" sql="$4" needle="$5" out
  if out=$(run -At -c "select set_config('test.uid','$uid',false), set_config('test.role','$role',false);" -c "set role $role;" -c "$sql" 2>&1); then
    fail "$label (expected error '$needle', got success: $out)"
  fi
  grep -Fq "$needle" <<<"$out" || fail "$label (expected '$needle', got '$out')"
  pass "$label"
}
svc() { as service_role "" "$1"; }

OWNER=00000000-0000-0000-0000-000000000011
OTHER_MERCHANT=00000000-0000-0000-0000-000000000012
BUYER=00000000-0000-0000-0000-000000000022
ACCOUNT=00000000-0000-0000-0000-000000000044
OTHER_ACCOUNT=00000000-0000-0000-0000-000000000045
STORE=00000000-0000-0000-0000-000000000033
UNREADY=00000000-0000-0000-0000-000000000034
HIDDEN=00000000-0000-0000-0000-000000000035

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create extension if not exists pgcrypto;
create schema auth; create schema internal; create schema vault; create schema net;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create function auth.role() returns text language sql stable as \$\$ select nullif(current_setting('test.role',true),'') \$\$;

-- Vault / pg_net stand-ins (Supabase provides the real ones).
create table vault.secrets(id uuid primary key default gen_random_uuid(), name text unique, secret text, description text);
create view vault.decrypted_secrets as select id, name, secret as decrypted_secret from vault.secrets;
create function vault.create_secret(p_secret text, p_name text, p_description text) returns uuid language sql as \$\$
  insert into vault.secrets(name, secret, description) values (p_name, p_secret, p_description) returning id \$\$;
create table net.calls(id bigserial primary key, url text, headers jsonb);
create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds integer) returns bigint language sql as \$\$
  insert into net.calls(url, headers) values (url, headers) returning id \$\$;

create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_stores(id uuid primary key, merchant_account_id uuid, name text,
  is_published boolean not null default true, stripe_payments_enabled boolean not null default false);
create table public.food_stripe_accounts(store_id uuid primary key references public.food_stores(id), stripe_account_id text not null unique,
  details_submitted boolean not null default false, charges_enabled boolean not null default false,
  promptpay_enabled boolean not null default false, status text not null default 'onboarding', livemode boolean not null default false);
create table public.food_orders(
  id uuid primary key default gen_random_uuid(),
  order_number text not null default substr(md5(random()::text),1,6),
  store_id uuid not null references public.food_stores(id),
  buyer_id uuid,
  source text not null default 'app' check (source in ('app','manual','social')),
  status text not null default 'pending_acceptance',
  payment_status text not null default 'pending' check (payment_status in ('pending','submitted','paid','issue','refunded')),
  payment_provider text,
  payment_slip_path text,
  total numeric(10,2) not null default 120,
  paid_at timestamptz,
  cancelled_at timestamptz,
  stripe_checkout_session_id text,
  stripe_payment_intent_id text,
  stripe_refund_id text,
  refund_status text not null default 'none' check (refund_status in ('none','pending','refunded','failed')),
  refund_note text,
  refund_requested_at timestamptz,
  refunded_at timestamptz,
  refund_updated_by uuid,
  created_at timestamptz not null default now()
);
create table public.food_stripe_payments(order_id uuid primary key references public.food_orders(id), store_id uuid,
  stripe_account_id text not null, checkout_session_id text unique, payment_intent_id text unique,
  amount_satang bigint not null, status text not null default 'pending', livemode boolean not null default false,
  application_fee_satang bigint not null default 0, application_fee_refunded_satang bigint not null default 0,
  application_fee_refunded_at timestamptz, refunded_at timestamptz, last_error text, updated_at timestamptz default now());
create table public.food_order_events(order_id uuid, event_type text, from_status text, to_status text, note text, actor_id uuid);
create table public.notifications(recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_notifications(merchant_account_id uuid, recipient_user_id uuid, type text check (type in ('system','order','payment','staff')), reason text);
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path='' as \$\$
  select exists(select 1 from public.food_stores s join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
    where s.id = p_store_id and mm.user_id = auth.uid() and mm.active and (p_roles is null or mm.role = any(p_roles))) \$\$;
grant usage on schema public, auth, internal to anon, authenticated, service_role;
grant select on public.food_orders to authenticated;

insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true), ('$OTHER_ACCOUNT','$OTHER_MERCHANT','owner',true);
insert into public.food_stores(id, merchant_account_id, name, is_published, stripe_payments_enabled) values
  ('$STORE','$ACCOUNT','Ready store',true,true), ('$UNREADY','$OTHER_ACCOUNT','Unready store',true,false),
  ('$HIDDEN','$ACCOUNT','Hidden store',false,true);
insert into public.food_stripe_accounts(store_id, stripe_account_id, details_submitted, charges_enabled, promptpay_enabled, status) values
  ('$STORE','acct_test_ready',true,true,true,'ready'), ('$UNREADY','acct_test_unready',true,false,false,'restricted');
SQL

MIGRATION="$ROOT/supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"   # idempotent rerun
pass "jobs migration applies twice"

# 1. Privileges.
eq "$(q "select count(*) from pg_class where relname in ('food_stripe_jobs','food_payment_policy') and relrowsecurity")" "2" "RLS on for new tables"
eq "$(q "select has_table_privilege('authenticated','public.food_stripe_jobs','select') or has_table_privilege('anon','public.food_payment_policy','select') or has_table_privilege('authenticated','public.food_payment_policy','update')")" "f" "no client grants on new tables"
for fn in "public.food_claim_stripe_jobs(integer)" "public.food_complete_stripe_job(uuid,text,text,text,boolean)" "public.food_refund_worker_cron_authorized(text)"; do
  eq "$(q "select has_function_privilege('authenticated','$fn','execute') or has_function_privilege('anon','$fn','execute')")" "f" "$fn not callable by clients"
  eq "$(q "select has_function_privilege('service_role','$fn','execute')")" "t" "$fn callable by service_role"
done
eq "$(q "select has_function_privilege('anon','public.merchant_retry_stripe_refund(uuid)','execute')")" "f" "merchant retry not callable by anon"
eq "$(q "select has_function_privilege('anon','public.food_payment_policy_public()','execute') and has_function_privilege('anon','public.food_store_payment_options(uuid[])','execute')")" "t" "public RPCs callable by guests"
eq "$(q "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where p.proname in ('food_claim_stripe_jobs','food_complete_stripe_job','food_refund_worker_cron_authorized','merchant_retry_stripe_refund','food_payment_policy_public','food_store_payment_options','food_orders_payment_guard','food_orders_payment_jobs','food_orders_require_stripe_ready','food_refund_worker_tick')
    and (not p.prosecdef or not coalesce(array_to_string(p.proconfig,','),'') like '%search_path=\"\"%')")" "0" "security definer + empty search_path"
expect_fail "claim refused for authenticated" authenticated "$OWNER" "select * from public.food_claim_stripe_jobs(5)" "permission denied"
eq "$(q "select stripe_only_from is null from public.food_payment_policy")" "t" "policy installed off (NULL)"

new_order() { # store source status payment_status provider session pi
  q "insert into public.food_orders(store_id, buyer_id, source, status, payment_status, payment_provider, stripe_checkout_session_id, stripe_payment_intent_id)
     values ('$1','$BUYER','$2','$3','$4',nullif('$5',''),nullif('$6',''),nullif('$7','')) returning id"
}
ledger() { q "insert into public.food_stripe_payments(order_id, store_id, stripe_account_id, checkout_session_id, payment_intent_id, amount_satang, status, application_fee_satang)
              values ('$1','$STORE','acct_test_ready',nullif('$2',''),nullif('$3',''),12000,'$4',${5:-0})" >/dev/null; }
jobs() { q "select coalesce(string_agg(kind || ':' || reason || ':' || status, ',' order by created_at, kind), '') from public.food_stripe_jobs where order_id='$1'"; }

# 2a. Customer cancel of an unpaid order with a session -> one expire job.
O1=$(new_order "$STORE" app pending_acceptance pending "" cs_test_o1 "")
ledger "$O1" cs_test_o1 "" pending
q "update public.food_orders set status='cancelled', cancelled_at=now() where id='$O1'" >/dev/null
q "update public.food_orders set status='cancelled' where id='$O1'" >/dev/null
eq "$(jobs "$O1")" "expire_checkout:order_cancelled:queued" "cancel with open session queues one expire job"
O1B=$(new_order "$STORE" app pending_acceptance pending "" "" "")
q "update public.food_orders set status='cancelled' where id='$O1B'" >/dev/null
eq "$(jobs "$O1B")" "" "cancel without a session queues nothing"

# 2b. Store cancels a Stripe-paid order (food_transition_order's update).
O2=$(new_order "$STORE" app preparing paid stripe cs_test_o2 pi_test_o2)
ledger "$O2" cs_test_o2 pi_test_o2 paid 1410
q "update public.food_orders set status='cancelled', cancelled_at=now(), refund_status='pending', refund_requested_at=now() where id='$O2'" >/dev/null
eq "$(jobs "$O2")" "refund:store_cancelled:queued" "store cancel of paid order queues a refund"
eq "$(q "select refund_status || ':' || (refund_requested_at is not null) from public.food_orders where id='$O2'")" "pending:true" "refund pending"
eq "$(q "select count(*) from public.food_order_events where order_id='$O2' and event_type='refund_auto_queued'")" "1" "audit event written"
q "update public.food_orders set status='cancelled' where id='$O2'" >/dev/null
eq "$(q "select count(*) from public.food_stripe_jobs where order_id='$O2'")" "1" "re-cancel does not duplicate the refund job"

# Any cancel path without refund fields still gets refund_status pending.
O2B=$(new_order "$STORE" app out_for_delivery paid stripe cs_test_o2b pi_test_o2b)
q "update public.food_orders set status='cancelled' where id='$O2B'" >/dev/null
eq "$(q "select refund_status from public.food_orders where id='$O2B'")" "pending" "guard marks refund pending on any cancel path"

# 2c. Paid after cancel (food_apply_stripe_event's paid update).
O3=$(new_order "$STORE" app pending_acceptance pending "" cs_test_o3 "")
ledger "$O3" cs_test_o3 "" pending
q "update public.food_orders set status='cancelled' where id='$O3'" >/dev/null
q "update public.food_orders set payment_status='paid', payment_provider='stripe', stripe_payment_intent_id=coalesce('pi_test_o3', stripe_payment_intent_id), paid_at=coalesce(paid_at, now())
   where id='$O3' and payment_status in ('pending','issue','submitted','paid')" >/dev/null
eq "$(q "select status || ':' || payment_status || ':' || refund_status from public.food_orders where id='$O3'")" "cancelled:paid:pending" "paid after cancel stays cancelled, refund pending"
eq "$(jobs "$O3")" "expire_checkout:order_cancelled:queued,refund:paid_after_cancel:queued" "paid after cancel queues a refund"
eq "$(q "select count(*) from public.notifications where recipient_id='$BUYER' and reason like '%กำลังคืนเงินให้อัตโนมัติ%'")" "1" "customer told about automatic refund"
eq "$(q "select count(*) from public.merchant_notifications where recipient_user_id='$OWNER' and type='payment'")" "1" "merchant told about automatic refund"

# 2d. Duplicate payment is parked, not refunded.
O4=$(new_order "$STORE" app preparing paid stripe cs_test_o4 pi_test_o4a)
q "update public.food_orders set payment_status='paid', payment_provider='stripe', stripe_payment_intent_id='pi_test_o4b' where id='$O4'" >/dev/null
eq "$(jobs "$O4")" "refund:duplicate_payment:needs_attention" "duplicate payment parked for review"

# 2e. Manual orders / non-Stripe payments never queue Stripe jobs.
O5=$(new_order "$STORE" manual preparing paid merchant_manual "" "")
q "update public.food_orders set status='cancelled' where id='$O5'" >/dev/null
eq "$(jobs "$O5")" "" "manual paid order cancel queues nothing"
eq "$(q "select refund_status from public.food_orders where id='$O5'")" "none" "manual order refund left to the merchant"

# 3. Claim / complete.
eq "$(svc "select count(*) from public.food_claim_stripe_jobs(25)")" "5" "service role claims the 5 due jobs"
eq "$(svc "select count(*) from public.food_claim_stripe_jobs(25)")" "0" "leased jobs are not claimed twice"
eq "$(q "select string_agg(distinct attempts::text, ',') from public.food_stripe_jobs where status='queued'")" "1" "claim counts one attempt"

# SKIP LOCKED: a concurrent claimer skips rows another worker holds.
q "update public.food_stripe_jobs set locked_until=null" >/dev/null
( run -At -c "select set_config('test.role','service_role',false);" -c "begin; select count(*) from public.food_claim_stripe_jobs(1); select pg_sleep(3); commit;" >/dev/null ) &
HOLDER=$!
got=$(run -At -c "do \$\$ begin
    while not exists (select 1 from pg_stat_activity where wait_event='PgSleep' and pid<>pg_backend_pid()) loop
      perform pg_sleep(0.05); end loop; end \$\$;" \
  -c "select set_config('test.role','service_role',false);" -c "select count(*) from public.food_claim_stripe_jobs(25);" | tail -n1)
wait $HOLDER
eq "$got" "4" "concurrent claim skips the locked job"
q "update public.food_stripe_jobs set locked_until=null, attempts=1" >/dev/null

J2=$(q "select id from public.food_stripe_jobs where order_id='$O2'")
eq "$(svc "select public.food_complete_stripe_job('$J2','retry',null,'network_error',false)")" "queued" "transient error keeps the job queued"
eq "$(q "select (next_attempt_at between now() + interval '55 seconds' and now() + interval '65 seconds') || ':' || last_error_code from public.food_stripe_jobs where id='$J2'")" "true:network_error" "first backoff is 1 minute"
q "update public.food_stripe_jobs set attempts=5 where id='$J2'" >/dev/null
svc "select public.food_complete_stripe_job('$J2','retry',null,'api_error',false)" >/dev/null
eq "$(q "select (next_attempt_at between now() + interval '5 hours 59 minutes' and now() + interval '6 hours 1 minute')::text from public.food_stripe_jobs where id='$J2'")" "true" "fifth failure backs off 6 hours"
q "update public.food_stripe_jobs set attempts=8 where id='$J2'" >/dev/null
eq "$(svc "select public.food_complete_stripe_job('$J2','retry',null,'api_error',false)")" "failed" "8th failure fails the job"
eq "$(q "select refund_status from public.food_orders where id='$O2'")" "failed" "order shows refund failed"
eq "$(q "select count(*) from public.notifications where recipient_id='$BUYER' and reason like '%มีปัญหา กรุณาติดต่อร้าน%'")" "1" "customer told the refund has a problem"
eq "$(q "select count(*) from public.merchant_notifications where reason like '%ไม่สำเร็จ%'")" "1" "merchant told the refund failed"
eq "$(svc "select public.food_complete_stripe_job('$J2','refunded','re_test_late',null,false)")" "failed" "outcome replay on a final job is a no-op"

# Stale lease after the last attempt -> failed on the next claim.
J2B=$(q "select id from public.food_stripe_jobs where order_id='$O2B'")
q "update public.food_stripe_jobs set attempts=8, locked_until=now() - interval '1 minute' where id='$J2B'" >/dev/null
svc "select count(*) from public.food_claim_stripe_jobs(25)" >/dev/null
eq "$(q "select status || ':' || last_error_code from public.food_stripe_jobs where id='$J2B'")" "failed:max_attempts_exceeded" "crashed final attempt fails on next claim"
q "update public.food_stripe_jobs set locked_until=null where status in ('queued','awaiting_refund')" >/dev/null

# Refund requested -> polled -> refunded (with GP fee).
J3=$(q "select id from public.food_stripe_jobs where order_id='$O3' and kind='refund'")
q "update public.food_stripe_payments set status='paid', payment_intent_id='pi_test_o3', application_fee_satang=500 where order_id='$O3'" >/dev/null
eq "$(svc "select public.food_complete_stripe_job('$J3','refund_requested','re_test_o3',null,true)")" "awaiting_refund" "refund requested -> awaiting_refund"
eq "$(q "select stripe_refund_id || ':' || refund_status from public.food_orders where id='$O3'")" "re_test_o3:pending" "order carries the refund id"
eq "$(q "select application_fee_refunded_satang from public.food_stripe_payments where order_id='$O3'")" "500" "GP fee refund recorded"
expect_fail "bad refund id rejected" service_role "" "select public.food_complete_stripe_job('$J3','refund_requested','re x; drop',null,false)" "invalid refund id"
eq "$(svc "select public.food_complete_stripe_job('$J3','refunded','re_test_o3',null,false)")" "done" "refund succeeded"
eq "$(q "select payment_status || ':' || refund_status || ':' || (refunded_at is not null) from public.food_orders where id='$O3'")" "refunded:refunded:true" "order refunded"
eq "$(q "select status from public.food_stripe_payments where order_id='$O3'")" "refunded" "ledger refunded"
eq "$(q "select count(*) from public.notifications where recipient_id='$BUYER' and reason like 'คืนเงินออเดอร์ #% แล้ว'")" "1" "customer told the refund is done"

# Expire job: session_expired marks the ledger, session_complete never downgrades.
J1=$(q "select id from public.food_stripe_jobs where order_id='$O1'")
eq "$(svc "select public.food_complete_stripe_job('$J1','done',null,'session_expired',false)")" "done" "expire done"
eq "$(q "select status from public.food_stripe_payments where order_id='$O1'")" "failed" "expired session ledger -> failed"
J3E=$(q "select id from public.food_stripe_jobs where order_id='$O3' and kind='expire_checkout'")
q "update public.food_stripe_payments set status='pending' where order_id='$O3'" >/dev/null
svc "select public.food_complete_stripe_job('$J3E','done',null,'session_complete',false)" >/dev/null
eq "$(q "select status from public.food_stripe_payments where order_id='$O3'")" "pending" "complete session ledger left for the webhook"
expect_fail "refund outcome on expire job rejected" service_role "" "select public.food_complete_stripe_job('$J1','refunded',null,null,false)" "invalid job outcome"

# 4. Merchant retry.
expect_fail "other merchant cannot retry" authenticated "$OTHER_MERCHANT" "select public.merchant_retry_stripe_refund('$O2')" "order management role required"
expect_fail "anon cannot retry" anon "" "select public.merchant_retry_stripe_refund('$O2')" "permission denied"
eq "$(as authenticated "$OWNER" "select public.merchant_retry_stripe_refund('$O2')")" "queued" "owner requeues failed refund"
eq "$(q "select status || ':' || attempts || ':' || requeue_count || ':' || (requeued_by = '$OWNER') from public.food_stripe_jobs where id='$J2'")" "queued:0:1:true" "job requeued (new idempotency generation)"
eq "$(q "select refund_status from public.food_orders where id='$O2'")" "pending" "order back to pending"
expect_fail "nothing to retry" authenticated "$OWNER" "select public.merchant_retry_stripe_refund('$O2')" "no_failed_refund"
expect_fail "unpaid order not eligible" authenticated "$OWNER" "select public.merchant_retry_stripe_refund('$O1')" "stripe_refund_not_eligible"

# 5. Policy off: legacy behaviour.
eq "$(as anon "" "select public.food_payment_policy_public()")" "f" "policy reads off"
LEG=$(new_order "$UNREADY" app pending_acceptance pending "" "" "")
q "update public.food_orders set payment_status='submitted', payment_slip_path='x' where id='$LEG'" >/dev/null
eq "$(q "select payment_status from public.food_orders where id='$LEG'")" "submitted" "policy off: unready store order + slip allowed"
q "update public.food_orders set created_at = now() - interval '1 hour' where id='$LEG'" >/dev/null
eq "$(as anon "" "select string_agg(store_id || ':' || accepting_orders || ':' || promptpay || ':' || card, ',' order by store_id) from public.food_store_payment_options(array['$STORE','$UNREADY','$HIDDEN']::uuid[])")" \
  "$STORE:true:true:true,$UNREADY:true:false:false" "options with policy off (unpublished store omitted)"

# Policy on.
ACTIVATE="$ROOT/supabase/migrations/20261023100200_food_stripe_only_activate.sql"
run >/dev/null < "$ACTIVATE"
T1=$(q "select stripe_only_from from public.food_payment_policy")
run >/dev/null < "$ACTIVATE"
eq "$(q "select stripe_only_from from public.food_payment_policy")" "$T1" "activation rerun keeps the cut-over time"
eq "$(as anon "" "select public.food_payment_policy_public()")" "t" "policy reads on"
eq "$(as anon "" "select string_agg(store_id || ':' || accepting_orders || ':' || promptpay || ':' || card, ',' order by store_id) from public.food_store_payment_options(array['$STORE','$UNREADY']::uuid[])")" \
  "$STORE:true:true:true,$UNREADY:false:false:false" "options with policy on"
expect_fail "too many stores refused" anon "" "select * from public.food_store_payment_options(array_fill(gen_random_uuid(), array[101]))" "too many stores"
expect_fail "app order at unready store refused" postgres "" \
  "insert into public.food_orders(store_id, buyer_id) values ('$UNREADY','$BUYER')" "store_not_accepting_orders"
NEW=$(new_order "$STORE" app pending_acceptance pending "" "" "")
pass "app order at ready store accepted"
MAN=$(new_order "$UNREADY" manual pending_acceptance pending "" "" "")
q "update public.food_orders set payment_status='paid', payment_provider='merchant_manual' where id='$MAN'" >/dev/null
pass "manual orders excluded from the gate and the manual-paid block"
expect_fail "slip refused on new app order" postgres "" "update public.food_orders set payment_status='submitted' where id='$NEW'" "stripe_only_payments"
expect_fail "manual paid refused on new app order" postgres "" "update public.food_orders set payment_status='paid', payment_provider='merchant_manual' where id='$NEW'" "stripe_only_payments"
expect_fail "manual issue refused on new app order" postgres "" "update public.food_orders set payment_status='issue', payment_provider='merchant_manual' where id='$NEW'" "stripe_only_payments"
q "update public.food_orders set payment_status='paid', payment_provider='stripe', stripe_payment_intent_id='pi_test_new' where id='$NEW'" >/dev/null
pass "Stripe webhook paid allowed with policy on"
q "update public.food_orders set payment_status='paid', payment_provider='merchant_manual' where id='$LEG'" >/dev/null
eq "$(q "select payment_status from public.food_orders where id='$LEG'")" "paid" "legacy in-flight slip can still be confirmed"
LEG2=$(new_order "$STORE" app pending_acceptance issue "" "" "")
q "update public.food_orders set created_at = now() - interval '1 hour' where id='$LEG2'" >/dev/null
expect_fail "legacy order cannot start a new slip after cut-over" postgres "" "update public.food_orders set payment_status='submitted' where id='$LEG2'" "stripe_only_payments"

# 6. Cron key + tick.
eq "$(svc "select public.food_refund_worker_cron_authorized('wrong')")" "f" "wrong cron key refused"
eq "$(svc "select public.food_refund_worker_cron_authorized(null)")" "f" "missing cron key refused"
KEY=$(q "select decrypted_secret from vault.decrypted_secrets where name='wynos_food_refund_worker_cron_key'")
[[ ${#KEY} -eq 64 ]] || fail "cron key is 32 random bytes"
eq "$(svc "select public.food_refund_worker_cron_authorized('$KEY')")" "t" "vault cron key accepted"
expect_fail "tick refuses without project url" postgres "" "select internal.food_refund_worker_tick()" "vault configuration missing"
q "select vault.create_secret('https://abcdefgh.supabase.co','wynos_project_url','test')" >/dev/null
q "select internal.food_refund_worker_tick()" >/dev/null
eq "$(q "select url || ':' || (headers->>'x-wynos-cron-key' = '$KEY') from net.calls")" "https://abcdefgh.supabase.co/functions/v1/food-stripe-refund-worker:true" "tick posts to the worker with the key"
expect_fail "tick not callable by clients" authenticated "$OWNER" "select internal.food_refund_worker_tick()" "permission denied"
expect_fail "enable-cron migration needs pg_cron" postgres "" "$(cat "$ROOT/supabase/migrations/20261023100100_food_stripe_jobs_enable_cron.sql")" "pg_cron and pg_net required"

# Rollback: legacy behaviour back, tables and history kept.
run >/dev/null < "$ROOT/supabase/rollbacks/20261023100200_food_stripe_only_activate_rollback.sql"
eq "$(as anon "" "select public.food_payment_policy_public()")" "f" "activation rollback restores legacy"
run >/dev/null < "$ROOT/supabase/rollbacks/20261023100100_food_stripe_jobs_enable_cron_rollback.sql"
run >/dev/null < "$ROOT/supabase/rollbacks/20261023100000_food_stripe_jobs_auto_refund_rollback.sql"
eq "$(q "select count(*) from pg_trigger where tgname in ('food_orders_payment_guard','food_orders_payment_jobs','food_orders_require_stripe_ready')")" "0" "rollback drops the 3 triggers"
eq "$(q "select (to_regclass('public.food_stripe_jobs') is not null) || ':' || (select count(*) > 0 from public.food_stripe_jobs)")" "true:true" "rollback keeps tables and history"
O9=$(new_order "$STORE" app preparing paid stripe cs_test_o9 pi_test_o9)
q "update public.food_orders set status='cancelled' where id='$O9'" >/dev/null
eq "$(jobs "$O9")" "" "after rollback no jobs are queued"
run >/dev/null < "$MIGRATION"
eq "$(q "select count(*) from pg_trigger where tgname in ('food_orders_payment_guard','food_orders_payment_jobs','food_orders_require_stripe_ready')")" "3" "re-apply after rollback works"

echo "PASS food_stripe_auto_refund_test"
