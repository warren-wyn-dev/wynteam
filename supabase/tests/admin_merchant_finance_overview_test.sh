#!/usr/bin/env bash
# WYNOS Admin Merchant Finance overview
# (supabase/migrations/20261011120000_admin_merchant_finance_overview.sql).
#
#   1. Only merchant:view (or edit, or the super admin) may call it; food-only,
#      signed-out and plain users are refused; anon has no execute grant.
#   2. Per-store money lines match public.merchant_finance_summary (WYN-210)
#      for the same store and range, so Admin and the merchant app agree.
#   3. Bangkok day boundaries, refunds, ad spend, WYNOS share and owed.
#   4. Stripe payouts / settlements are range bound; no bank account number,
#      PromptPay ID or Stripe account ID is ever returned.
#   5. Bad ranges are refused; the function is stable (read only) and the
#      migration can be applied twice.
#
# Runs on a throwaway local PostgreSQL database with minimal stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/admin_merchant_finance_overview_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_merchant_finance_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

SUPER=00000000-0000-0000-0000-0000000000a1
MERCHANT_VIEW=00000000-0000-0000-0000-0000000000a2
MERCHANT_EDIT=00000000-0000-0000-0000-0000000000a3
FOOD_ONLY=00000000-0000-0000-0000-0000000000a4
USER=00000000-0000-0000-0000-0000000000a5
OWNER=00000000-0000-0000-0000-0000000000d1
ACCOUNT=00000000-0000-0000-0000-0000000000e1
STORE=00000000-0000-0000-0000-0000000000f1
OTHER=00000000-0000-0000-0000-0000000000f2
QUIET=00000000-0000-0000-0000-0000000000f3

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, username text);
-- Same contract as WYN-219 internal.has_admin_permission (edit includes view).
create table internal.platform_super_admins(user_id uuid primary key);
create table public.admin_permissions(user_id uuid, system text, level text, primary key (user_id, system));
create function internal.has_admin_permission(p_system text, p_level text) returns boolean language sql stable security definer set search_path = '' as \$\$
  select exists (select 1 from internal.platform_super_admins s where s.user_id = auth.uid())
      or exists (select 1 from public.admin_permissions ap where ap.user_id = auth.uid() and ap.system = p_system
                 and (ap.level = 'edit' or p_level = 'view')) \$\$;
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, primary key (merchant_account_id, user_id));
create table public.food_staff(store_id uuid, user_id uuid, role text, active boolean default true);
create table public.food_stores(id uuid primary key, merchant_account_id uuid, name text, is_published boolean default true, admin_suspended_at timestamptz);
create table public.food_orders(id uuid primary key default gen_random_uuid(), store_id uuid, status text, payment_status text,
  refund_status text default 'none', payment_provider text, subtotal numeric, delivery_fee numeric, total numeric,
  paid_at timestamptz, refunded_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.food_order_campaigns(order_id uuid, platform_funded numeric default 0, released_at timestamptz, settlement_id uuid, campaign_discount numeric default 0);
create table public.food_ad_clicks(store_id uuid, click_day date, cost numeric);
create table public.food_platform_settlements(id uuid primary key default gen_random_uuid(), store_id uuid, amount numeric, order_count int,
  reference text, note text, settled_by uuid, created_at timestamptz default now());
create table public.food_stripe_accounts(store_id uuid primary key, stripe_account_id text, status text, payouts_enabled boolean,
  bank_name text, bank_last4 text, payout_interval text, livemode boolean default false);
create table public.food_stripe_payouts(payout_id text primary key, store_id uuid, stripe_account_id text, amount_satang bigint,
  currency text default 'thb', status text, arrival_date date, failure_code text, stripe_created_at timestamptz);
-- PromptPay / bank account details live on the store in production; the overview must never read them out.
alter table public.food_stores add column promptpay_id text, add column bank_account_number text;
-- Same rule as WYN-206: delivered, not refunded, not released, not settled.
create function internal.food_platform_owed_rows(p_store_id uuid) returns table (order_id uuid, amount numeric) language sql stable set search_path = '' as \$\$
  select foc.order_id, foc.platform_funded from public.food_order_campaigns foc join public.food_orders o on o.id = foc.order_id
  where o.store_id = p_store_id and foc.platform_funded > 0 and foc.released_at is null and foc.settlement_id is null
    and o.status = 'delivered' and o.payment_status <> 'refunded' \$\$;
-- For GP v1 (applied at the end of this test).
create table public.food_stripe_payments(order_id uuid primary key, amount_satang bigint not null, status text not null default 'paid', refunded_at timestamptz);
create function internal.is_super_admin() returns boolean language sql stable security definer set search_path = '' as \$\$
  select exists (select 1 from internal.platform_super_admins s where s.user_id = auth.uid()) \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, actor_username_snapshot text, event_type text, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned', 'admin_permission_granted')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void
  language sql security definer set search_path = public as \$\$
  insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
grant usage on schema public, auth, internal to authenticated, anon;

insert into auth.users values ('$SUPER'), ('$MERCHANT_VIEW'), ('$MERCHANT_EDIT'), ('$FOOD_ONLY'), ('$USER'), ('$OWNER');
insert into public.profiles values ('$SUPER','founder'), ('$OWNER','owner_a');
insert into internal.platform_super_admins values ('$SUPER');
insert into public.admin_permissions values ('$MERCHANT_VIEW','merchant','view'), ('$MERCHANT_EDIT','merchant','edit'), ('$FOOD_ONLY','food','edit');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true);
insert into public.food_stores(id, merchant_account_id, name, promptpay_id, bank_account_number) values
  ('$STORE','$ACCOUNT','ร้าน A','0812345678','1234567890'),
  ('$OTHER',null,'ร้าน B',null,null),
  ('$QUIET',null,'ร้าน C',null,null);

-- Same fixtures as wynos_merchant_finance_test.sh for STORE.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$STORE','delivered','paid',100,20,110,'2026-10-03 05:00+07');
insert into public.food_orders(id, store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('00000000-0000-0000-0000-0000000000b2','$STORE','delivered','paid',200,30,200,'2026-10-04 12:00+07');
insert into public.food_order_campaigns values ('00000000-0000-0000-0000-0000000000b2', 15, null, null);
insert into public.food_orders(store_id, status, payment_status, refund_status, subtotal, delivery_fee, total, paid_at, refunded_at)
  values ('$STORE','cancelled','refunded','refunded',80,20,100,'2026-10-04 13:00+07','2026-10-04 18:00+07');
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$STORE','delivered','paid',50,0,50,'2026-10-04 23:30+07');
-- 00:30 on 5 Oct Bangkok is 4 Oct in UTC: not part of 4 Oct.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$STORE','delivered','paid',40,0,40,'2026-10-05 00:30+07');
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total)
  values ('$STORE','pending_acceptance','pending',999,0,999), ('$STORE','pending_acceptance','submitted',70,20,90);
insert into public.food_ad_clicks values ('$STORE','2026-10-04',2.5), ('$STORE','2026-10-04',2.5);
-- Store B: one big order on 4 Oct, ad spend 500.
insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at)
  values ('$OTHER','delivered','paid',5000,0,5000,'2026-10-04 12:00+07');
insert into public.food_ad_clicks values ('$OTHER','2026-10-04',500);

insert into public.food_stripe_accounts values
  ('$STORE','acct_SECRET_A','ready',true,'KBank','4321','daily',false);
insert into public.food_stripe_payouts values
  ('po_in','$STORE','acct_SECRET_A',12345,'thb','paid','2026-10-05',null,'2026-10-04 10:00+07'),
  ('po_failed','$STORE','acct_SECRET_A',500,'thb','failed',null,'account_closed','2026-10-04 11:00+07'),
  ('po_out','$STORE','acct_SECRET_A',999,'thb','paid','2026-09-02',null,'2026-09-01 10:00+07');
insert into public.food_platform_settlements(store_id, amount, order_count, reference, settled_by, created_at) values
  ('$OTHER', 30, 2, 'TRF-001', '$SUPER', '2026-10-04 15:00+07');
SQL

MIGRATION="$ROOT/supabase/migrations/20261011120000_admin_merchant_finance_overview.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"   # idempotent
# The store app's own summary, to compare against.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_finance_v1.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

F="public.admin_merchant_finance_overview('2026-10-04','2026-10-04')"
A="(select s from jsonb_array_elements(($F)->'stores') s where s->>'store_id' = '$STORE')"
B="(select s from jsonb_array_elements(($F)->'stores') s where s->>'store_id' = '$OTHER')"

# 1. Access.
expect_fail "$FOOD_ONLY" "select $F" "food-only admin is refused" "Not authorized"
expect_fail "$USER" "select $F" "a plain user is refused" "Not authorized"
expect_fail "$OWNER" "select $F" "a store owner cannot see every store" "Not authorized"
expect_fail "" "select $F" "signed out is refused" "Not authorized"
expect_eq "$MERCHANT_VIEW" "select jsonb_array_length(($F)->'stores')" "3" "merchant:view sees every store"
expect_eq "$MERCHANT_EDIT" "select jsonb_array_length(($F)->'stores')" "3" "merchant:edit includes view"
expect_eq "$SUPER" "select jsonb_array_length(($F)->'stores')" "3" "super admin passes"
expect_eq "$SUPER" "select has_function_privilege('anon', 'public.admin_merchant_finance_overview(date,date)', 'execute')" "f" "anon cannot execute"
expect_eq "$SUPER" "select provolatile from pg_proc where proname = 'admin_merchant_finance_overview'" "s" "stable (read only)"

# 2. Ranges.
expect_fail "$SUPER" "select public.admin_merchant_finance_overview('2026-10-05','2026-10-04')" "from after to" "invalid date range"
expect_fail "$SUPER" "select public.admin_merchant_finance_overview(null,'2026-10-04')" "null from" "invalid date range"
expect_fail "$SUPER" "select public.admin_merchant_finance_overview('2025-01-01','2026-10-04')" "over a year" "date range is too long"

# 3. Store A lines on 4 Oct (Bangkok).
expect_eq "$SUPER" "select ($A)->>'orders'" "3" "three paid orders on 4 Oct (not the 00:30 5 Oct one)"
expect_eq "$SUPER" "select (($A)->>'food')::numeric" "330" "food"
expect_eq "$SUPER" "select (($A)->>'discounts')::numeric" "30" "discounts"
expect_eq "$SUPER" "select (($A)->>'refunds')::numeric" "100" "refunds"
expect_eq "$SUPER" "select (($A)->>'sales_net')::numeric" "250" "net sales"
expect_eq "$SUPER" "select (($A)->>'ad_spend')::numeric" "5.0" "ad spend"
expect_eq "$SUPER" "select (($A)->>'platform_funded')::numeric" "15" "WYNOS share"
expect_eq "$SUPER" "select (($A)->>'income')::numeric" "260.0" "income"
expect_eq "$SUPER" "select (($A)->>'platform_owed')::numeric" "15" "WYNOS still owes 15"

# Matches the merchant app's own summary for the same store and range, line
# by line. merchant_finance_summary only answers the store's own managers,
# so it is read as the owner.
for key in orders food delivery discounts refund_count refunds sales_net ad_spend platform_funded income platform_owed; do
  admin="$(as "$SUPER" "select ($A)->>'$key'")"
  merchant="$(as "$OWNER" "select public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'$key'")"
  [[ "$(as "$SUPER" "select '$admin'::numeric = '$merchant'::numeric")" == "t" ]] || { echo "FAIL: $key admin=$admin merchant=$merchant"; exit 1; }
done

# Store B and the totals.
expect_eq "$SUPER" "select (($B)->>'income')::numeric" "4500" "store B income = 5000 - 500"
expect_eq "$SUPER" "select (($F)->'totals'->>'sales_net')::numeric" "5250" "total net sales"
expect_eq "$SUPER" "select (($F)->'totals'->>'orders')::numeric" "4" "total orders"
expect_eq "$SUPER" "select ($F)->'totals'->>'stores_with_sales'" "2" "two stores sold"
expect_eq "$SUPER" "select ($F)->'stores'->0->>'store_id'" "$OTHER" "ordered by net sales"
expect_eq "$SUPER" "select ($F)->'totals'->>'stores_without_stripe'" "2" "B and C have no Stripe account"
expect_eq "$SUPER" "select ($F)->'totals'->>'stores_payout_ready'" "1" "A can receive payouts"

# 4. Payouts and settlements.
expect_eq "$SUPER" "select jsonb_array_length(($F)->'payouts')" "2" "only payouts created on 4 Oct"
expect_eq "$SUPER" "select ($F)->'payout_status_counts'->>'failed'" "1" "one failed payout"
expect_eq "$SUPER" "select ($F)->'payouts'->0->>'payout_id'" "po_failed" "newest payout first"
expect_eq "$SUPER" "select jsonb_array_length(($F)->'settlements')" "1" "one settlement"
expect_eq "$SUPER" "select ($F)->'settlements'->0->>'settled_by_username'" "founder" "settled by"
expect_eq "$SUPER" "select ($A)->>'stripe_bank_last4'" "4321" "bank last 4 only"
expect_eq "$SUPER" "select ($F)::text like '%acct_SECRET%'" "f" "no Stripe account id"
expect_eq "$SUPER" "select ($F)::text like '%1234567890%' or ($F)::text like '%0812345678%'" "f" "no bank account / PromptPay number"

# Empty range.
expect_eq "$SUPER" "select (public.admin_merchant_finance_overview('2026-11-01','2026-11-07')->'totals'->>'income')::numeric" "0" "empty week is zero"

# ---------------------------------------------------------------------------
# GP v1 finance lines (20261011140000 + 20261011140100): no GP -> nothing moves;
# a collected Stripe fee comes off income in both the Admin and store views.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations/20261011140000_merchant_gp_v1.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations/20261011140100_merchant_gp_finance_lines.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations/20261011140100_merchant_gp_finance_lines.sql"   # idempotent
expect_eq "$SUPER" "select (($A)->>'income')::numeric" "260.00" "no GP: store A income unchanged"
expect_eq "$SUPER" "select (($F)->'totals'->>'gp')::numeric" "0.00" "no GP collected"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'income')::numeric" "260.0" "no GP: merchant income unchanged"
# Same Bangkok day edges with the timestamptz-bound filters.
expect_eq "$SUPER" "select ($A)->>'orders'" "3" "4 Oct still excludes the 00:30 5 Oct order"
expect_eq "$SUPER" "select (public.admin_merchant_finance_overview('2026-10-05','2026-10-05')->'totals'->>'orders')" "1" "00:30 5 Oct order counts on 5 Oct"
expect_eq "$SUPER" "select (($A)->>'refunds')::numeric" "100" "refund still on 4 Oct"
expect_eq "$SUPER" "select jsonb_array_length(($F)->'payouts')" "2" "payouts still range bound"

# Order B (paid by Stripe) carried a 30.00 GP fee.
run -q -c "insert into public.food_stripe_payments values ('00000000-0000-0000-0000-0000000000b2', 20000)" >/dev/null
run -q -c "update public.food_stripe_payments set application_fee_satang = 3000" >/dev/null
run -q -c "update public.food_orders set payment_provider = 'stripe' where id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
expect_eq "$SUPER" "select (($A)->>'gp')::numeric" "30.00" "admin: GP collected on store A"
expect_eq "$SUPER" "select (($A)->>'income')::numeric" "230.00" "admin: income = 260 - 30"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'gp')::numeric" "30.00" "merchant: GP line"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'income')::numeric" "230.00" "merchant: income = 260 - 30"
for key in orders sales_net platform_funded gp income platform_owed; do
  admin="$(as "$SUPER" "select ($A)->>'$key'")"
  merchant="$(as "$OWNER" "select public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'$key'")"
  [[ "$(as "$SUPER" "select '$admin'::numeric = '$merchant'::numeric")" == "t" ]] || { echo "FAIL (GP): $key admin=$admin merchant=$merchant"; exit 1; }
done
# Review finding: a late `payment_failed` webhook from an older checkout
# attempt rewrites the ledger row to `failed`; the order was still paid by
# Stripe, so the fee still counts.
run -q -c "update public.food_stripe_payments set status = 'failed' where order_id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
expect_eq "$SUPER" "select (($A)->>'gp')::numeric" "30.00" "stale failed ledger row does not drop collected GP"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'gp')::numeric" "30.00" "merchant: same"

# Review finding: refunded from the Stripe Dashboard (no fee refund) -> WYNOS
# keeps the fee, nothing is reversed.
run -q -c "update public.food_orders set payment_status = 'refunded', refund_status = 'refunded', refunded_at = '2026-10-06 10:00+07' where id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
run -q -c "update public.food_stripe_payments set status = 'refunded', refunded_at = '2026-10-06 10:00+07' where order_id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
R6="(select s from jsonb_array_elements(public.admin_merchant_finance_overview('2026-10-06','2026-10-06')->'stores') s where s->>'store_id' = '$STORE')"
expect_eq "$SUPER" "select (($R6)->>'gp')::numeric = 0" "t" "refund without fee refund: nothing reversed"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-06','2026-10-06')->>'gp')::numeric" "0" "merchant: nothing reversed"

# Refund through WYNOS on 6 Oct returns the fee: 4 Oct keeps the GP it really
# collected, 6 Oct shows it coming back, the two net 0.
run -q -c "update public.food_stripe_payments set application_fee_refunded_satang = 3000, application_fee_refunded_at = '2026-10-06 10:00+07' where order_id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
expect_eq "$SUPER" "select (($A)->>'gp')::numeric" "30.00" "4 Oct keeps the GP collected that day"
expect_eq "$SUPER" "select (($R6)->>'gp')::numeric" "-30.00" "admin: 6 Oct returns the fee"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-06','2026-10-06')->>'gp')::numeric" "-30.00" "merchant: 6 Oct returns the fee"
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-06')->>'gp')::numeric" "0.00" "over both days GP nets to zero"
R46="(select s from jsonb_array_elements(public.admin_merchant_finance_overview('2026-10-04','2026-10-06')->'stores') s where s->>'store_id' = '$STORE')"
expect_eq "$SUPER" "select (($R46)->>'gp')::numeric" "0.00" "admin: over both days GP nets to zero (same as the store's page)"
run -q -c "update public.food_orders set payment_status = 'paid', refund_status = 'none', refunded_at = null where id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null
run -q -c "update public.food_stripe_payments set status = 'paid', refunded_at = null, application_fee_refunded_satang = 0, application_fee_refunded_at = null where order_id = '00000000-0000-0000-0000-0000000000b2'" >/dev/null

# Slip order placed under a 10% store rate: GP worked out but not collectable.
run -q -c "insert into public.merchant_gp_rates(store_id, rate_bp, effective_from, reason, idempotency_key, request_fingerprint) values ('$OTHER', 1000, '2026-01-01', 'test rate', gen_random_uuid(), 'fixture')" >/dev/null
run -q -c "insert into public.food_orders(store_id, status, payment_status, subtotal, delivery_fee, total, paid_at) values ('$OTHER','delivered','paid',60,20,80,'2026-10-04 14:00+07')" >/dev/null
expect_eq "$SUPER" "select (($B)->>'gp_uncollected')::numeric" "6.00" "slip order GP 10% of 60 not collectable"
expect_eq "$SUPER" "select (($B)->>'gp')::numeric" "0.00" "nothing collected on slip"
expect_eq "$SUPER" "select ($B)->>'gp_rate_bp'" "1000" "store B current rate"
expect_eq "$SUPER" "select ($A)->>'gp_rate_bp'" "0" "store A has no rate: 0"

# Review finding: a checkout abandoned for a slip leaves a `failed` Stripe row
# that still carries the fee; that order paid by slip, so nothing was collected.
run -q -c "insert into public.food_orders(id, store_id, status, payment_status, subtotal, delivery_fee, total, paid_at) values ('00000000-0000-0000-0000-0000000000b9','$OTHER','delivered','paid',100,0,100,'2026-10-04 15:00+07')" >/dev/null
run -q -c "insert into public.food_stripe_payments(order_id, amount_satang, status, application_fee_satang) values ('00000000-0000-0000-0000-0000000000b9', 10000, 'failed', 1000)" >/dev/null
expect_eq "$SUPER" "select (($B)->>'gp')::numeric" "0.00" "failed Stripe row is not collected GP"
expect_eq "$SUPER" "select (($B)->>'gp_uncollected')::numeric" "16.00" "abandoned-checkout slip order counts as uncollected (6 + 10)"
run -q -c "insert into public.food_orders(id, store_id, status, payment_status, subtotal, delivery_fee, total, paid_at) values ('00000000-0000-0000-0000-0000000000ba','$STORE','delivered','paid',10,0,10,'2026-10-04 16:00+07')" >/dev/null
run -q -c "insert into public.food_stripe_payments(order_id, amount_satang, status, application_fee_satang) values ('00000000-0000-0000-0000-0000000000ba', 1000, 'failed', 500)" >/dev/null
expect_eq "$OWNER" "select (public.merchant_finance_summary('$STORE','2026-10-04','2026-10-04')->>'gp')::numeric" "30.00" "merchant: failed Stripe row not deducted (still only order B's 30)"

# Review finding: a slip order refunded later keeps its uncollected GP on the
# paid day and reverses it on the refund day.
run -q -c "update public.food_orders set payment_status = 'refunded', refund_status = 'refunded', refunded_at = '2026-10-06 09:00+07' where id = '00000000-0000-0000-0000-0000000000b9'" >/dev/null
expect_eq "$SUPER" "select (($B)->>'gp_uncollected')::numeric" "16.00" "4 Oct uncollected unchanged after a later refund"
B6="(select s from jsonb_array_elements(public.admin_merchant_finance_overview('2026-10-06','2026-10-06')->'stores') s where s->>'store_id' = '$OTHER')"
expect_eq "$SUPER" "select (($B6)->>'gp_uncollected')::numeric" "-10.00" "6 Oct reverses the refunded slip order's uncollected GP"

echo "PASS: admin merchant finance overview"
