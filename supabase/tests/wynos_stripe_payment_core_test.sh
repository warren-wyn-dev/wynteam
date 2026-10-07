#!/usr/bin/env bash
# Stripe payment core regression: privacy, readiness, webhook idempotency,
# amount/account verification, paid/refunded transitions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_stripe_payment_core_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
expect_fail() {
  local label="$1" sql="$2" needle="$3" out
  out=$(run -At -c "$sql" 2>&1 || true)
  grep -Fq "$needle" <<<"$out" || fail "$label (expected '$needle', got '$out')"
  pass "$label"
}

OWNER=00000000-0000-0000-0000-000000000011
BUYER=00000000-0000-0000-0000-000000000022
STORE=00000000-0000-0000-0000-000000000033
ACCOUNT=00000000-0000-0000-0000-000000000044
ORDER=00000000-0000-0000-0000-000000000055
MENU=00000000-0000-0000-0000-000000000066

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table auth.users(id uuid primary key);
create table public.merchant_accounts(id uuid primary key);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_stores(
  id uuid primary key,
  merchant_account_id uuid,
  name text, description text, phone text, address text,
  logo_path text, cover_path text,
  latitude double precision, longitude double precision,
  business_schedule jsonb not null default '{}'::jsonb,
  prep_time_min_minutes integer default 15,
  prep_time_max_minutes integer default 30,
  promptpay_id text, bank_account_number text, payment_qr_path text,
  is_published boolean default false
);
create table public.food_menu_items(id uuid primary key, store_id uuid);
create table public.food_orders(
  id uuid primary key,
  order_number text,
  store_id uuid,
  buyer_id uuid,
  total numeric(10,2),
  status text default 'pending',
  payment_status text default 'pending',
  payment_provider text,
  payment_provider_code text,
  payment_transaction_ref text,
  payment_verified_at timestamptz,
  payment_verification_status text default 'not_started',
  payment_verification_note text,
  payment_note text,
  payment_slip_path text,
  paid_at timestamptz,
  refund_status text default 'none',
  refund_note text,
  refund_requested_at timestamptz,
  refund_updated_by uuid,
  refunded_at timestamptz
);
create table public.food_order_events(order_id uuid,event_type text,note text,actor_id uuid);
create table public.notifications(recipient_id uuid,actor_id uuid,type text,reason text);
create function public.food_is_permanent_account() returns boolean language sql stable as \$fn\$ select auth.uid() is not null \$fn\$;
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path='' as \$fn\$
  select exists(
    select 1 from public.food_stores s
    join public.merchant_memberships m on m.merchant_account_id=s.merchant_account_id
    where s.id=p_store_id and m.user_id=auth.uid() and m.active
      and (p_roles is null or m.role=any(p_roles))
  )
\$fn\$;
grant usage on schema public, auth, internal to authenticated, anon, service_role;
insert into auth.users values ('$OWNER'),('$BUYER');
insert into public.merchant_accounts values ('$ACCOUNT');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true);
insert into public.food_stores(id,merchant_account_id,name,description,phone,address,logo_path,cover_path,latitude,longitude,business_schedule,promptpay_id)
values ('$STORE','$ACCOUNT','ร้านทดสอบ','desc','0800000000','มหาสารคาม','logo','cover',16.18,103.30,'{"weekly":{"mon":[]}}',null);
insert into public.food_menu_items values ('$MENU','$STORE');
insert into public.food_orders(id,order_number,store_id,buyer_id,total) values ('$ORDER','WF9001','$STORE','$BUYER',125.50);
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_stripe_payment_core_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_stripe_payment_core_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_stripe_connect_v2_embedded.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_stripe_connect_v2_embedded.sql"
pass "Stripe core and v2 hardening migrations apply twice"

[ "$(val "set role authenticated; set test.uid='$OWNER'; select public.merchant_stripe_status('$STORE')->>'status'")" = "not_connected" ] || fail "unconnected status"
pass "merchant status hides account ID and reports not connected"

[ "$(val "set role service_role; select public.food_claim_stripe_account_creation('$STORE','00000000-0000-0000-0000-000000000077',45)")" = "t" ] || fail "first connect lock"
[ "$(val "set role service_role; select public.food_claim_stripe_account_creation('$STORE','00000000-0000-0000-0000-000000000088',45)")" = "f" ] || fail "second connect lock"
val "set role service_role; select public.food_release_stripe_account_creation('$STORE','00000000-0000-0000-0000-000000000077')" >/dev/null
[ "$(val "set role service_role; select public.food_claim_stripe_account_creation('$STORE','00000000-0000-0000-0000-000000000088',45)")" = "t" ] || fail "released connect lock"
val "set role service_role; select public.food_release_stripe_account_creation('$STORE','00000000-0000-0000-0000-000000000088')" >/dev/null
pass "server-side provisioning lock prevents concurrent account creation"

expect_fail "authenticated cannot read Stripe payouts table" \
  "set role authenticated; set test.uid='$OWNER'; select * from public.food_stripe_payouts" \
  "permission denied"
expect_fail "authenticated cannot read Stripe provisioning lock" \
  "set role authenticated; set test.uid='$OWNER'; select * from public.food_stripe_account_creation_locks" \
  "permission denied"
expect_fail "authenticated cannot read archived Stripe mappings" \
  "set role authenticated; set test.uid='$OWNER'; select * from public.food_stripe_account_mapping_archive" \
  "permission denied"

expect_fail "authenticated cannot read Stripe account table"   "set role authenticated; set test.uid='$OWNER'; select * from public.food_stripe_accounts"   "permission denied"

run >/dev/null <<SQL
insert into public.food_stripe_accounts(store_id,stripe_account_id,details_submitted,charges_enabled,payouts_enabled,promptpay_enabled,status)
values ('$STORE','acct_test_wynos',true,true,true,true,'ready');
update public.food_stripe_accounts set account_api_version='v2', bank_ready=true, bank_name='TEST BANK', bank_last4='1234', payout_interval='daily' where store_id='$STORE';
update public.food_stores set stripe_payments_enabled=true where id='$STORE';
SQL

[ "$(val "set role authenticated; set test.uid='$OWNER'; select public.merchant_stripe_status('$STORE')->>'status'")" = "ready" ] || fail "ready status"
pass "merchant sees sanitized Stripe readiness"
[ "$(val "set role authenticated; set test.uid='$OWNER'; select public.merchant_stripe_status('$STORE')->>'bank_last4'")" = "1234" ] || fail "sanitized bank last4"
[ "$(val "set role authenticated; set test.uid='$OWNER'; select public.merchant_stripe_status('$STORE') ? 'stripe_account_id'")" = "f" ] || fail "status leaked account id"
pass "merchant status exposes only sanitized payout account data"
[ "$(val "select has_table_privilege('service_role','public.food_stripe_accounts','select')")" = "t" ] || fail "service role cannot read Stripe account backend table"
[ "$(val "select has_table_privilege('authenticated','public.food_stripe_accounts','select')")" = "f" ] || fail "authenticated can read Stripe account backend table"
[ "$(val "select has_table_privilege('service_role','public.food_stripe_account_mapping_archive','select')")" = "t" ] || fail "service role cannot read archived Stripe mappings"
[ "$(val "select has_table_privilege('authenticated','public.food_stripe_account_mapping_archive','select')")" = "f" ] || fail "authenticated can read archived Stripe mappings"
[ "$(val "select has_function_privilege('service_role','public.food_archive_stripe_account_mapping(uuid,boolean,text)','execute')")" = "t" ] || fail "service role cannot archive Stripe mappings"
[ "$(val "select has_function_privilege('authenticated','public.food_archive_stripe_account_mapping(uuid,boolean,text)','execute')")" = "f" ] || fail "authenticated can archive Stripe mappings"
pass "raw Stripe account access and archives are service-role only"
[ "$(val "select has_function_privilege('authenticated','public.food_get_stripe_webhook_secret(text)','execute')")" = "f" ] || fail "authenticated can read Stripe webhook Vault secret"
[ "$(val "select has_function_privilege('authenticated','public.food_set_stripe_webhook_secret(text,text)','execute')")" = "f" ] || fail "authenticated can write Stripe webhook Vault secret"
[ "$(val "select has_function_privilege('service_role','public.food_get_stripe_webhook_secret(text)','execute')")" = "t" ] || fail "service role cannot read Stripe webhook Vault secret"
[ "$(val "select has_function_privilege('service_role','public.food_set_stripe_webhook_secret(text,text)','execute')")" = "t" ] || fail "service role cannot write Stripe webhook Vault secret"
pass "Stripe webhook Vault access is service-role only"
[ "$(val "set role service_role; select account_api_version from public.food_stripe_accounts where store_id='$STORE'")" = "v2" ] || fail "account api version"
[ "$(val "set role service_role; select livemode::text from public.food_stripe_accounts where store_id='$STORE'")" = "false" ] || fail "test mapping default mode"
pass "new schema records Accounts v2 and Stripe mode without exposing it to Merchant UI"

[ "$(val "set role service_role; select public.food_claim_stripe_webhook_event('evt_account_sync','v2.core.account[requirements].updated','acct_test_wynos','acct_test_wynos')")" = "t" ] || fail "first account webhook claim"
[ "$(val "set role service_role; select public.food_claim_stripe_webhook_event('evt_account_sync','v2.core.account[requirements].updated','acct_test_wynos','acct_test_wynos')")" = "f" ] || fail "duplicate account webhook claim"
val "set role service_role; select public.food_release_stripe_webhook_event_claim('evt_account_sync','v2.core.account[requirements].updated')" >/dev/null
[ "$(val "set role service_role; select public.food_claim_stripe_webhook_event('evt_account_sync','v2.core.account[requirements].updated','acct_test_wynos','acct_test_wynos')")" = "t" ] || fail "released account webhook claim"
[ "$(val "select has_function_privilege('authenticated','public.food_claim_stripe_webhook_event(text,text,text,text)','execute')")" = "f" ] || fail "authenticated can claim Stripe webhook events"
pass "account webhook claims deduplicate concurrent delivery and can be released for retry"

[ "$(val "set role service_role; select public.food_record_stripe_payout_event('evt_payout_paid','payout.paid','acct_test_wynos','po_test_1',5000,'thb','paid',current_date,null,now())")" = "t" ] || fail "payout event applies"
[ "$(val "set role service_role; select public.food_record_stripe_payout_event('evt_payout_paid','payout.paid','acct_test_wynos','po_test_1',5000,'thb','paid',current_date,null,now())")" = "f" ] || fail "duplicate payout event ignored"
[ "$(val "select status||'|'||amount_satang from public.food_stripe_payouts where payout_id='po_test_1'")" = "paid|5000" ] || fail "payout audit row"
pass "payout webhook state is mapped and idempotent"

expect_fail "wrong payout connected account is rejected" \
  "set role service_role; select public.food_record_stripe_payout_event('evt_payout_bad','payout.failed','acct_other','po_bad',1,'thb','failed',null,'account_closed',now())" \
  "stripe account mismatch"
[ "$(val "select count(*) from public.food_stripe_webhook_events where event_id='evt_payout_bad'")" = "0" ] || fail "bad payout left event tombstone"
pass "payout mapping rejects unknown connected accounts atomically"


[ "$(val "select internal.food_store_publish_readiness_json('$STORE')->'checks'->>'payment'")" = "true" ] || fail "Stripe satisfies payment readiness"
pass "Stripe-ready store satisfies payment readiness without manual bank data"

run -c "update public.food_orders set stripe_checkout_session_id='cs_open' where id='$ORDER'" >/dev/null
expect_fail "manual slip is blocked while Stripe Checkout is open" \
  "set role authenticated; set test.uid='$BUYER'; select public.food_submit_payment('$ORDER','$BUYER/slips/$ORDER/a.jpg')" \
  "cancel stripe checkout before submitting slip"
run -c "update public.food_orders set stripe_checkout_session_id=null where id='$ORDER'" >/dev/null
pass "manual fallback requires the Stripe session to be expired first"

PAID_SQL="set role service_role; select public.food_apply_stripe_event(
  'evt_paid','checkout.session.completed','$ORDER','acct_test_wynos','cs_1','cs_1','pi_1',12550,'thb','paid','promptpay',null,null
)"
[ "$(val "$PAID_SQL")" = "t" ] || fail "paid event applies"
[ "$(val "select payment_status||'|'||payment_provider||'|'||stripe_payment_intent_id from public.food_orders where id='$ORDER'")" = "paid|stripe|pi_1" ] || fail "order becomes paid"
pass "verified webhook marks order paid"

expect_fail "legacy refund RPC cannot fake a Stripe refund" \
  "set role authenticated; set test.uid='$OWNER'; select public.merchant_set_refund_status('$ORDER','refunded','manual')" \
  "stripe refunds must be processed through the payment gateway"

expect_fail "legacy payment RPC cannot override a Stripe payment" \
  "set role authenticated; set test.uid='$OWNER'; select public.food_set_payment_status('$ORDER','refunded','manual')" \
  "stripe payment status is managed by webhook"

[ "$(val "$PAID_SQL")" = "f" ] || fail "duplicate event ignored"
[ "$(val "select count(*) from public.food_stripe_webhook_events where event_id='evt_paid'")" = "1" ] || fail "one webhook event row"
pass "webhook event is idempotent"

expect_fail "wrong amount is rejected"   "set role service_role; select public.food_apply_stripe_event('evt_bad_amount','checkout.session.completed','$ORDER','acct_test_wynos','cs_2','cs_2','pi_2',1,'thb','paid','card',null,null)"   "amount mismatch"
[ "$(val "select count(*) from public.food_stripe_webhook_events where event_id='evt_bad_amount'")" = "0" ] || fail "failed event transaction rolled back"
pass "rejected event leaves no idempotency tombstone"

expect_fail "wrong connected account is rejected"   "set role service_role; select public.food_apply_stripe_event('evt_bad_account','checkout.session.completed','$ORDER','acct_other','cs_3','cs_3','pi_3',12550,'thb','paid','card',null,null)"   "stripe account mismatch"

[ "$(val "set role service_role; select public.food_apply_stripe_event('evt_refund','refund.updated','$ORDER','acct_test_wynos','re_1',null,'pi_1',12550,'thb','refunded',null,null,'re_1')")" = "t" ] || fail "refund event applies"
[ "$(val "select payment_status||'|'||refund_status||'|'||stripe_refund_id from public.food_orders where id='$ORDER'")" = "refunded|refunded|re_1" ] || fail "refund finalizes"
pass "Stripe webhook finalizes full refund"

[ "$(val "select has_function_privilege('authenticated','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute')")" = "f" ] || fail "authenticated can execute webhook mutation"
[ "$(val "select has_function_privilege('service_role','public.food_apply_stripe_event(text,text,uuid,text,text,text,text,bigint,text,text,text,text,text)','execute')")" = "t" ] || fail "service role cannot execute webhook mutation"
pass "webhook mutation is service-role only"

echo "All WYNOS Stripe payment core tests passed."
