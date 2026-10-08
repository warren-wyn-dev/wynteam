#!/usr/bin/env bash
# Disposable PostgreSQL regression: Food -> Merchant order journey.
# Uses actual RPC definitions from migration files (not mocked SQL logic).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="wyn_order_journey_$$"
psql -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap 'psql -q -X -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { psql -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
value() { run -At -c "$1" | tail -1; }
fail() { echo "FAIL: $*" >&2; exit 1; }
# Preserve complete stderr/error context under both raw psql and CI's psql wrapper.
# Using tail here loses the RAISE EXCEPTION message when CI merges stderr/stdout.
as_user() { run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2"; }
allow() { as_user "$1" "$2" >/dev/null || fail "$3"; echo "ok - $3"; }
deny() { local out; if out="$(as_user "$1" "$2" 2>&1)"; then fail "$3 unexpectedly allowed"; fi
  [[ "$out" == *"$4"* ]] || fail "$3 (wanted $4; got $out)"; echo "ok - $3"; }
eq() { local got; got="$(value "$1")"; [[ "$got" == "$2" ]] || fail "$3 (got $got, expected $2)"; echo "ok - $3"; }
load_rpc() {
  local name="$1" file="$2" src
  src="$(awk -v fn="$name" '
    $0 ~ "^create or replace function public\\." fn "\\(" { reading=1 }
    reading { print }
    reading && /^\$\$;[[:space:]]*$/ { done=1; exit }
    END { if (!done) exit 42 }
  ' "$ROOT/$file")" || fail "missing RPC definition $name"
  printf "%s\n" "$src" | run >/dev/null
}
OWNER=00000000-0000-0000-0000-0000000000a1
RIDER=00000000-0000-0000-0000-0000000000a2
OTHER=00000000-0000-0000-0000-0000000000b1
BUYER=00000000-0000-0000-0000-0000000000c1
STORE=aaaaaaaa-0000-0000-0000-000000000000
STOREB=bbbbbbbb-0000-0000-0000-000000000000
ACC=a0000000-0000-0000-0000-00000000000a
ACCB=b0000000-0000-0000-0000-00000000000b
PAID=11111111-0000-0000-0000-000000000000
UNPAID=22222222-0000-0000-0000-000000000000
REFUND=33333333-0000-0000-0000-000000000000
STRIPE=44444444-0000-0000-0000-000000000000

run >/dev/null <<SQL
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal; create schema storage;
create function auth.uid() returns uuid language sql stable as
  \$\$select nullif(current_setting('test.uid',true),'')::uuid\$\$;
grant usage on schema auth, internal, storage to authenticated;
create table public.merchant_memberships(merchant_account_id uuid,user_id uuid,role text,active boolean);
create table public.food_stores(id uuid primary key,merchant_account_id uuid);
create table public.food_staff(store_id uuid,user_id uuid,role text,active boolean);
create table public.food_orders(
  id uuid primary key,order_number text not null,store_id uuid not null,buyer_id uuid,
  status text not null default 'pending_acceptance',payment_status text not null default 'pending',
  payment_note text,payment_slip_path text,payment_provider text,payment_provider_code text,
  payment_transaction_ref text,payment_verified_at timestamptz,payment_verification_status text,
  payment_verification_note text,stripe_checkout_session_id text,eta_minutes integer,
  accepted_at timestamptz,ready_at timestamptz,out_for_delivery_at timestamptz,
  cancelled_at timestamptz,delivered_at timestamptz,paid_at timestamptz,
  refunded_at timestamptz,refund_status text not null default 'none',
  refund_requested_at timestamptz,refund_updated_by uuid
);
create table public.food_order_events(
  id bigserial primary key,order_id uuid,event_type text,from_status text,
  to_status text,note text,actor_id uuid);
create table public.food_delivery_proofs(
  order_id uuid unique,method text,location_note text,image_path text,
  delivered_by uuid,created_at timestamptz default now());
create table storage.objects(bucket_id text,name text);
create table public.notifications(recipient_id uuid,actor_id uuid,type text,reason text);
create table public.notification_settings(user_id uuid primary key,system boolean);
create function internal.notification_enabled(p_user_id uuid,p_category text)
returns boolean language sql stable set search_path='' as
  \$\$select coalesce((select system from public.notification_settings where user_id=p_user_id),true)\$\$;
create function public.food_customer_access_enabled() returns boolean
language sql stable as \$\$select auth.uid() is not null\$\$;
create function public.food_is_permanent_account() returns boolean
language sql stable as \$\$select auth.uid() is not null\$\$;
create function public.merchant_has_store_role(p_store_id uuid,p_roles text[] default null)
returns boolean language sql stable security definer set search_path='' as
  \$\$select exists(select 1 from public.food_stores s join public.merchant_memberships mm
    on mm.merchant_account_id=s.merchant_account_id where s.id=p_store_id
    and mm.user_id=auth.uid() and mm.active and (p_roles is null or mm.role=any(p_roles)))
    or exists(select 1 from public.food_staff fs where fs.store_id=p_store_id
    and fs.user_id=auth.uid() and fs.active and (p_roles is null or fs.role=any(p_roles)))\$\$;
insert into public.food_stores values('$STORE','$ACC'),('$STOREB','$ACCB');
insert into public.merchant_memberships values
('$ACC','$OWNER','owner',true),('$ACC','$RIDER','delivery',true),
('$ACCB','$OTHER','owner',true);
insert into public.food_orders(id,order_number,store_id,buyer_id,payment_status) values
('$PAID','WF1001','$STORE','$BUYER','pending'),
('$UNPAID','WF1002','$STORE','$BUYER','pending'),
('$REFUND','WF1003','$STORE','$BUYER','paid'),
('$STRIPE','WF1004','$STORE','$BUYER','pending');
update public.food_orders set stripe_checkout_session_id='cs_test_open' where id='$STRIPE';
insert into public.notification_settings values('$BUYER',true);
SQL
load_rpc food_submit_payment "supabase/migrations_wynos_stripe_payment_core_v1.sql"
load_rpc food_set_payment_status "supabase/migrations_wynos_stripe_payment_core_v1.sql"
load_rpc food_transition_order "supabase/migrations_wynos_merchant_core_completion_v1.sql"
load_rpc food_complete_delivery "supabase/migrations_wynos_food_delivery_photo_required_v1.sql"
load_rpc food_cancel_order "supabase/migrations_wynos_food_customer_access_gate_v2.sql"

deny "$BUYER" "select public.food_transition_order('$PAID','preparing')" \
 "buyer cannot manage store" "order management role required"
deny "$OTHER" "select public.food_transition_order('$PAID','preparing')" \
 "another restaurant cannot manage store" "order management role required"
deny "$OWNER" "select public.food_transition_order('$PAID','preparing')" \
 "cannot prepare unpaid order" "payment must be verified first"
deny "$BUYER" "select public.food_submit_payment('$PAID','$OTHER/slips/$PAID/fake.jpg')" \
 "foreign slip path refused" "invalid slip path"
deny "$BUYER" "select public.food_submit_payment('$STRIPE','$BUYER/slips/$STRIPE/s.jpg')" \
 "open Stripe checkout blocks slip" "cancel stripe checkout before submitting slip"
allow "$BUYER" "select public.food_submit_payment('$PAID','$BUYER/slips/$PAID/s.jpg')" \
 "Food buyer submits payment slip"
eq "select payment_status||'|'||payment_verification_status from food_orders where id='$PAID'" \
 "submitted|manual_review" "Merchant sees manual review required"
deny "$BUYER" "select public.food_submit_payment('$PAID','$BUYER/slips/$PAID/again.jpg')" \
 "buyer cannot resubmit the slip" "payment already submitted"
deny "$RIDER" "select public.food_set_payment_status('$PAID','paid')" \
 "courier cannot approve payment" "order management role required"
allow "$OWNER" "select public.food_set_payment_status('$PAID','paid','confirmed')" \
 "Merchant verifies payment"
eq "select payment_status||'|'||payment_verification_status||'|'||(paid_at is not null)::text from food_orders where id='$PAID'" \
 "paid|manual_verified|true" "verified payment metadata is persisted"
deny "$BUYER" "select public.food_cancel_order('$PAID','changed mind')" \
 "customer cannot cancel paid order" "order cannot be cancelled by customer"

allow "$OWNER" "select public.food_transition_order('$PAID','preparing',20,'accepted')" \
 "Merchant accepts paid order"
deny "$RIDER" "select public.food_transition_order('$PAID','ready_for_delivery')" \
 "delivery staff cannot skip prep" "order management role required"
deny "$OWNER" "select public.food_transition_order('$PAID','out_for_delivery')" \
 "invalid state skip refused" "invalid order transition"
allow "$OWNER" "select public.food_transition_order('$PAID','ready_for_delivery')" \
 "Merchant marks order ready"
allow "$RIDER" "select public.food_transition_order('$PAID','out_for_delivery')" \
 "Courier starts delivery"
deny "$OWNER" "select public.food_complete_delivery('$PAID','direct',null,null)" \
 "photo required" "delivery photo is required"
deny "$OTHER" "select public.food_complete_delivery('$PAID','direct',null,'delivery/$PAID/a.jpg')" \
 "another store cannot confirm delivery" "delivery role required"
run -c "insert into storage.objects values('food-private','delivery/$PAID/a.jpg')" >/dev/null
allow "$RIDER" "select public.food_complete_delivery('$PAID','direct',null,'delivery/$PAID/a.jpg')" \
 "Courier confirms delivery with photo"
eq "select status||'|'||(delivered_at is not null)::text from food_orders where id='$PAID'" \
 "delivered|true" "Delivered status reaches Food order"
eq "select count(*) from food_order_events where order_id='$PAID' and event_type='status_changed'" \
 "3" "Three Merchant status transitions logged"
eq "select count(*) from notifications where recipient_id='$BUYER' and reason like 'ออเดอร์ #WF1001 ส่งถึงแล้ว%'" \
 "1" "One delivery notification to buyer"
deny "$RIDER" "select public.food_complete_delivery('$PAID','direct',null,'delivery/$PAID/a.jpg')" \
 "cannot deliver twice" "order is not out for delivery"

deny "$OTHER" "select public.food_cancel_order('$UNPAID','competitor')" \
 "other customer cannot cancel" "order not found"
allow "$BUYER" "select public.food_cancel_order('$UNPAID','not needed')" \
 "Buyer cancels unpaid pending order"
eq "select status||'|'||(cancelled_at is not null)::text from food_orders where id='$UNPAID'" \
 "cancelled|true" "Cancelled order state persisted"
deny "$OWNER" "select public.food_transition_order('$UNPAID','preparing')" \
 "cancelled order cannot restart" "invalid order transition"
allow "$OWNER" "select public.food_transition_order('$REFUND','cancelled')" \
 "Merchant cancels paid order"
eq "select status||'|'||payment_status||'|'||refund_status from food_orders where id='$REFUND'" \
 "cancelled|paid|pending" "Cancelled paid order requests refund but does not fabricate it"
eq "select (refund_requested_at is not null)::text from food_orders where id='$REFUND'" \
 "true" "Refund timestamp recorded"
deny "$BUYER" "select public.food_submit_payment('$REFUND','$BUYER/slips/$REFUND/new.jpg')" \
 "cancelled order cannot accept slip" "order is closed"
deny "$OWNER" "select public.food_set_payment_status('$STRIPE','paid')" \
 "Merchant cannot bypass Stripe verification" "stripe payment status is managed by webhook"
echo "PASS: Food Merchant order journey; isolated PostgreSQL; no live payment or order mutations"
