#!/usr/bin/env bash
# Isolated PostgreSQL behaviour tests; no external services or real customer data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_food_observation_test_$$"
$PSQL -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -X -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
VIEW=00000000-0000-0000-0000-000000000001
EDIT=00000000-0000-0000-0000-000000000002
OTHER=00000000-0000-0000-0000-000000000003
BUYER=00000000-0000-0000-0000-000000000004
STORE=00000000-0000-0000-0000-000000000005
run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$
  select nullif(current_setting('test.uid', true),'')::uuid \$\$;
-- WYN-219 contract: edit includes view, no session or other system denies.
create table public.admin_permissions(user_id uuid, system text, level text);
create function internal.has_admin_permission(p_system text,p_level text) returns boolean
language sql stable security definer set search_path = '' as \$\$
  select exists(select 1 from public.admin_permissions p where p.user_id = auth.uid()
    and p.system = p_system and (p.level = 'edit' or p_level = 'view')) \$\$;
insert into public.admin_permissions values ('$VIEW','food','view'),('$EDIT','food','edit'),('$OTHER','merchant','edit');
create table public.food_stores(id uuid primary key,name text);
create table public.food_orders(id uuid primary key,order_number text,store_id uuid,buyer_id uuid,
  status text default 'delivered',payment_status text default 'paid',refund_status text default 'none',
  total numeric default 100,payment_provider text,stripe_checkout_session_id text,
  created_at timestamptz default '2026-10-12 00:00+07',updated_at timestamptz default '2026-10-12 00:00+07',
  refund_requested_at timestamptz,refunded_at timestamptz,
  recipient_name text default 'PRIVATE_NAME',recipient_phone text default 'PRIVATE_PHONE',shipping_address text default 'PRIVATE_ADDRESS');
create table public.food_stripe_payments(order_id uuid primary key,store_id uuid,amount_satang bigint,
  status text,currency text default 'thb',stripe_account_id text default 'acct_PRIVATE',last_error text default 'PRIVATE_ERROR');
create table public.food_stripe_webhook_events(event_id text,event_type text,order_id uuid,object_id text,
  received_at timestamptz default '2026-10-12 01:00+07');
insert into public.food_stores values ('$STORE','Fixture restaurant');
insert into public.food_orders(id,order_number,store_id,buyer_id,payment_provider)
  select ('10000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid,'PAY-' || n,'$STORE','$BUYER','stripe'
  from generate_series(1,8) n;
insert into public.food_stripe_payments(order_id,store_id,amount_satang,status)
  select id,store_id,10000,'paid' from public.food_orders where order_number <> 'PAY-8';
update public.food_stripe_payments set amount_satang=9999 where order_id='10000000-0000-0000-0000-000000000002';
update public.food_stripe_payments set status='refunded' where order_id='10000000-0000-0000-0000-000000000003';
update public.food_orders set status='cancelled',refund_status='failed' where order_number='PAY-4';
update public.food_orders set status='cancelled',refund_status='pending',refund_requested_at='2026-10-01 00:00+07' where order_number='PAY-5';
update public.food_orders set payment_status='pending',status='pending_acceptance',payment_provider=null where order_number='PAY-7';
update public.food_stripe_payments set status='pending' where order_id='10000000-0000-0000-0000-000000000007';
update public.food_orders set stripe_checkout_session_id='cs_PRIVATE',payment_status='pending',status='pending_acceptance' where order_number='PAY-8';
insert into public.food_stripe_webhook_events(event_id,event_type,order_id,object_id) values
  ('evt_dispute','charge.dispute.closed','10000000-0000-0000-0000-000000000006','dp_PRIVATE'),
  ('evt_refund','refund.failed','10000000-0000-0000-0000-000000000004','re_PRIVATE');
insert into public.food_orders(id,order_number,store_id,buyer_id)
  select ('20000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid,'MAN-' || n,'$STORE',
    case when n=30 then null else '$BUYER'::uuid end from generate_series(1,30) n;
-- Both ends of a Bangkok day are included, next midnight is not.
insert into public.food_orders(id,order_number,store_id,created_at) values
 ('30000000-0000-0000-0000-000000000001','BOUND-FIRST','$STORE','2026-10-11 17:00Z'),
 ('30000000-0000-0000-0000-000000000002','BOUND-LAST','$STORE','2026-10-12 16:59:59Z'),
 ('30000000-0000-0000-0000-000000000003','BOUND-NEXT','$STORE','2026-10-12 17:00Z');
grant usage on schema public,auth,internal to authenticated,anon;
SQL
MIGRATION="$ROOT/supabase/migrations/20261014023253_admin_food_payment_customer_observability.sql"
ROLLBACK="$ROOT/supabase/rollbacks/20261014023253_admin_food_payment_customer_observability_rollback.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"
CHECKS=0
as() { run -At -c "select set_config('test.uid','$1',false)" -c 'set role authenticated' -c "$2" 2>&1 | tail -n1; }
expect() { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL $4: got $got expected $3"; exit 1; }; CHECKS=$((CHECKS+1)); }
denies() { local out; if out="$(run -c "select set_config('test.uid','$1',false)" -c 'set role authenticated' -c "$2" 2>&1)"; then echo "FAIL expected denial: $3"; exit 1; fi
  [[ "$out" == *"$4"* ]] || { echo "FAIL wrong error $3: $out"; exit 1; }; CHECKS=$((CHECKS+1)); }
F="public.admin_food_payment_monitor(null,'all',null,'2026-10-12','2026-10-12',25,0)"
C="public.admin_food_customer_history(null,null,25,0)"
for who in "$OTHER" "$BUYER" ""; do
  denies "$who" "select $F" "monitor unauthorized" 'Not authorized'
  denies "$who" "select $C" "history unauthorized" 'Not authorized'
done
denies "$VIEW" "select $C" 'viewer cannot read customer history' 'Not authorized'
expect "$VIEW" "select ($F)->>'total_count'" 40 'DB count covers all matching rows before pagination'
expect "$VIEW" "select jsonb_array_length(($F)->'rows')" 25 'page bound'
expect "$EDIT" "select ($F)->>'total_count'" 40 'edit includes view'
expect "$VIEW" "select public.admin_food_payment_monitor('bound','all',null,'2026-10-12','2026-10-12',25,0)->>'total_count'" 2 'Bangkok date bounds'
expect "$VIEW" "select public.admin_food_payment_monitor(null,'all','stripe','2026-10-12','2026-10-12',25,0)->>'total_count'" 8 'Stripe provider includes ledger and pending checkout'
expect "$VIEW" "select public.admin_food_payment_monitor(null,'all','manual','2026-10-12','2026-10-12',25,0)->>'total_count'" 32 'manual filter excludes Stripe'
expect "$VIEW" "select public.admin_food_payment_monitor('pay-2','all',null,'2026-10-12','2026-10-12',25,0)->'rows'->0->'flags' ? 'amount_mismatch'" t 'amount mismatch flagged'
expect "$VIEW" "select public.admin_food_payment_monitor('pay-3','all',null,'2026-10-12','2026-10-12',25,0)->'rows'->0->'flags' ? 'state_mismatch'" t 'status mismatch flagged'
expect "$VIEW" "select public.admin_food_payment_monitor('pay-5','all',null,'2026-10-12','2026-10-12',25,0)->'rows'->0->'flags' ? 'refund_waiting_24h'" t 'stale refund flagged'
expect "$VIEW" "select public.admin_food_payment_monitor('pay-8','all',null,'2026-10-12','2026-10-12',25,0)->'rows'->0->'flags' ? 'ledger_missing'" t 'missing Stripe ledger flagged'
expect "$VIEW" "select public.admin_food_payment_monitor('pay-7','all',null,'2026-10-12','2026-10-12',25,0)->'rows'->0->'flags' ? 'payment_waiting_24h'" t 'stale pending payment flagged'
expect "$VIEW" "select public.admin_food_payment_monitor(null,'dispute',null,'2026-10-12','2026-10-12',25,0)->>'total_count'" 1 'dispute event receipt visible'
expect "$VIEW" "select public.admin_food_payment_monitor(null,'refund',null,'2026-10-12','2026-10-12',25,0)->>'total_count'" 2 'refund filter'
expect "$VIEW" "select public.admin_food_payment_monitor('absent','all',null,'2026-10-12','2026-10-12',25,0)->>'total_count'" 0 'empty only after successful query'
expect "$VIEW" "select public.admin_food_payment_monitor(null,'all',null,'2026-10-12','2026-10-12',25,25)->'rows'->0->>'order_id' <> ($F)->'rows'->0->>'order_id'" t 'distinct next page'
expect "$VIEW" "select ($F)::text !~ 'PRIVATE|recipient|shipping|buyer_id|stripe_account_id|last_error|object_id'" t 'no PII or raw gateway fields'
expect "$EDIT" "select ($C)->>'total_count'" 1 'deleted/manual buyer not merged into customer identity'
expect "$EDIT" "select ($C)->'customers'->0->>'order_count'" 37 'customer aggregate uses all actual buyer orders'
expect "$EDIT" "select public.admin_food_customer_history('$BUYER',null,25,0)->>'total_count'" 37 'selected buyer history count'
expect "$EDIT" "select public.admin_food_customer_history('$BUYER','PAY-1',25,0)->>'total_count'" 1 'selected history query'
expect "$EDIT" "select ($C)::text !~ 'PRIVATE|recipient|shipping|phone|email|username|address'" t 'customer summaries redacted'
expect "$EDIT" "select public.admin_food_customer_history('$BUYER',null,25,0)::text !~ 'PRIVATE|recipient|shipping|phone|email|username|address'" t 'customer history redacted'
expect "$VIEW" "select has_function_privilege('anon','public.admin_food_payment_monitor(text,text,text,date,date,integer,integer)','execute')" f 'anon monitor grant denied'
expect "$VIEW" "select has_function_privilege('anon','public.admin_food_customer_history(uuid,text,integer,integer)','execute')" f 'anon history grant denied'
expect "$VIEW" "select has_function_privilege('authenticated','internal.admin_food_payment_rows(timestamptz,timestamptz,text,text)','execute')" f 'private projection not callable'
denies "$VIEW" "select * from public.food_orders" 'no underlying table bypass' 'permission denied'
for args in "null,'oops',null,'2026-10-12','2026-10-12',25,0" "null,'all','other','2026-10-12','2026-10-12',25,0" "null,'all',null,'2026-10-12','2026-10-11',25,0" "null,'all',null,'2020-01-01','2026-10-12',25,0" "null,'all',null,null,null,0,0" "null,'all',null,null,null,25,-1"; do
  denies "$VIEW" "select public.admin_food_payment_monitor($args)" 'invalid filter/range/page rejected' 'Invalid'
done
denies "$EDIT" "select public.admin_food_customer_history(null,repeat('x',101),25,0)" 'long search rejected' 'Invalid'
denies "$EDIT" "select public.admin_food_customer_history(null,null,101,0)" 'oversized history rejected' 'Invalid'
# Reversible schema-only rollout; rollback removes APIs, keeps real data intact.
run >/dev/null < "$ROLLBACK"
expect "$EDIT" "select to_regprocedure('public.admin_food_payment_monitor(text,text,text,date,date,integer,integer)') is null" t 'rollback removes monitor'
expect "$EDIT" "select to_regprocedure('public.admin_food_customer_history(uuid,text,integer,integer)') is null" t 'rollback removes history'
[[ "$(run -At -c 'select count(*) from public.food_orders')" == 41 ]] || { echo 'FAIL rollback changed orders'; exit 1; }
CHECKS=$((CHECKS+1))
run >/dev/null < "$MIGRATION"
expect "$VIEW" "select ($F)->>'total_count'" 40 'reapply restores read model'
echo "PASS: $CHECKS payment/customer PostgreSQL assertions"
