#!/usr/bin/env bash
# Disposable LOCAL PostgreSQL only; synthetic fixtures, no payment or deployment.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_performance_test_$$"
$PSQL -q -X -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -X -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { run -At -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
expect_db() { [ "$(val "$1")" = "$2" ] || fail "$3"; pass "$3"; }
as_user() { run -At -c "set role authenticated; set test.uid='$1'; $2" | tail -1; }
expect_user() { [ "$(as_user "$1" "$2")" = "$3" ] || fail "$4"; pass "$4"; }
expect_error() {
  local output
  # CI's psql wrapper combines stdout/stderr. Preserve the whole diagnostic:
  # as_user's last-row filter would retain CONTEXT and discard the ERROR line.
  if output=$(run -At -c "set role authenticated; set test.uid='$2'; $3" 2>&1); then fail "$1 (unexpected success)"; fi
  [[ "$output" == *"$4"* ]] || fail "$1 (got $output)"
  pass "$1"
}
OWNER=00000000-0000-0000-0000-000000000001
BUYER=00000000-0000-0000-0000-000000000002
OTHER=00000000-0000-0000-0000-000000000003
STAFF=00000000-0000-0000-0000-000000000004
LEGACY=00000000-0000-0000-0000-000000000005
STORE=00000000-0000-0000-0000-000000000011
STORE2=00000000-0000-0000-0000-000000000012
QUERY="public.merchant_order_performance('$STORE','2026-10-13','2026-10-13')"

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as
  \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, developer boolean not null default false);
create table public.food_stores(id uuid primary key, merchant_account_id uuid);
create table public.merchant_memberships(merchant_account_id uuid,user_id uuid,role text,active boolean);
create table public.food_staff(store_id uuid,user_id uuid,role text,active boolean);
create function public.is_developer_account() returns boolean language sql stable security definer set search_path='' as
  \$\$ select coalesce((select developer from public.profiles where id=auth.uid()),false) \$\$;
-- Reproduce legacy developer bypass and any-role food_staff access: the new RPC
-- must still deny foreign developers and legacy non-manager staff.
create function public.merchant_has_store_role(p_store_id uuid,p_roles text[]) returns boolean
language sql stable security definer set search_path='' as \$\$
  select public.is_developer_account()
  or exists(select 1 from public.food_stores s join public.merchant_memberships m
    on m.merchant_account_id=s.merchant_account_id where s.id=p_store_id
    and m.user_id=auth.uid() and m.active and m.role=any(p_roles))
  or exists(select 1 from public.food_staff where store_id=p_store_id and user_id=auth.uid() and active) \$\$;
create table public.food_development_features(name text primary key,enabled boolean not null default false,
  developer_only boolean not null default true);
alter table public.food_development_features enable row level security;
revoke all on public.food_development_features from public,anon,authenticated;
create function internal.food_development_feature_enabled(p_name text) returns boolean
language sql stable security definer set search_path='' as \$\$
  select coalesce((select enabled and (not developer_only or public.is_developer_account())
    from public.food_development_features where name=p_name),false) \$\$;
revoke all on function internal.food_development_feature_enabled(text) from public,anon,authenticated;
create table public.food_orders(id uuid primary key,store_id uuid,buyer_id uuid,
  status text,payment_status text,accepted_at timestamptz,ready_at timestamptz,paid_at timestamptz,created_at timestamptz);
create table public.food_order_events(id bigint generated always as identity,order_id uuid,
  event_type text,to_status text,actor_id uuid);
create table public.food_order_items(order_id uuid,menu_item_id uuid,item_name text,quantity integer);
alter table public.food_orders enable row level security;
alter table public.food_order_events enable row level security;
alter table public.food_order_items enable row level security;
revoke all on public.food_orders,public.food_order_events,public.food_order_items from public,anon,authenticated;
grant usage on schema public,auth to authenticated,anon;
insert into public.profiles values ('$OWNER',true),('$BUYER',false),('$OTHER',true),('$STAFF',false),('$LEGACY',false);
insert into public.food_stores values ('$STORE','$STORE'),('$STORE2','$STORE2');
insert into public.merchant_memberships values ('$STORE','$OWNER','owner',true),('$STORE2','$OTHER','owner',true);
insert into public.food_staff values ('$STORE','$STAFF','staff',true),('$STORE','$LEGACY','owner',true);
insert into public.food_orders values
 ('00000000-0000-0000-0000-000000000021','$STORE','$BUYER','delivered','paid','2026-10-13 08:00Z','2026-10-13 08:20Z','2026-10-12 17:00Z','2026-10-12 17:00Z'),
 ('00000000-0000-0000-0000-000000000022','$STORE','$BUYER','preparing','paid','2026-10-13 08:00Z',null,'2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000023','$STORE','$BUYER','cancelled','paid',null,null,'2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000024','$STORE','$BUYER','cancelled','refunded','2026-10-13 08:00Z','2026-10-13 08:10Z','2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000025','$STORE','$BUYER','pending_acceptance','pending',null,null,null,'2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000026','$STORE','$BUYER','pending_acceptance','submitted',null,null,null,'2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000027','$STORE','$BUYER','cancelled','issue',null,null,'2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000028','$STORE','$BUYER','delivered','paid','2026-10-13 08:00Z','2026-10-13 07:00Z','2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000029','$STORE','$BUYER','delivered','paid','2026-10-13 08:00Z','2026-10-13 08:00Z','2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000030','$STORE','$BUYER','cancelled','paid','2026-10-13 08:00Z',null,'2026-10-13 00:00Z','2026-10-13 00:00Z'),
 ('00000000-0000-0000-0000-000000000031','$STORE','$BUYER','delivered','paid','2026-10-12 08:00Z','2026-10-12 09:00Z','2026-10-12 00:00Z','2026-10-12 16:59:59Z'),
 ('00000000-0000-0000-0000-000000000032','$STORE','$BUYER','delivered','paid','2026-10-13 18:00Z','2026-10-13 19:00Z','2026-10-13 17:00Z','2026-10-13 17:00Z'),
 ('00000000-0000-0000-0000-000000000033','$STORE2','$BUYER','delivered','paid','2026-10-13 08:00Z','2026-10-13 09:00Z','2026-10-13 00:00Z','2026-10-13 00:00Z');
insert into public.food_order_events(order_id,event_type,to_status,actor_id) values
 ('00000000-0000-0000-0000-000000000023','status_changed','cancelled','$OWNER'),
 ('00000000-0000-0000-0000-000000000023','status_changed','cancelled','$OWNER'),
 ('00000000-0000-0000-0000-000000000024','status_changed','cancelled','$BUYER'),
 ('00000000-0000-0000-0000-000000000027','status_changed','cancelled','$OTHER'),
 ('00000000-0000-0000-0000-000000000030','status_changed','cancelled',null);
insert into public.food_order_items values
 ('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000041','กะเพรา',2),
 ('00000000-0000-0000-0000-000000000029','00000000-0000-0000-0000-000000000041','กะเพรา',1),
 ('00000000-0000-0000-0000-000000000028',null,'เมนูที่ลบแล้ว',5),
 ('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000041','กะเพรา',99),
 ('00000000-0000-0000-0000-000000000024','00000000-0000-0000-0000-000000000041','กะเพรา',99),
 ('00000000-0000-0000-0000-000000000033',null,'ร้านอื่น',99);
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013050200_food_merchant_performance.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013050200_food_merchant_performance.sql"
pass "migration applies twice"
expect_db "select enabled::text||'|'||developer_only::text from public.food_development_features where name='merchant_performance'" "false|true" "feature defaults OFF and developer-only"
expect_error "feature flag blocks metrics" "$OWNER" "select $QUERY" "merchant performance is not enabled"
expect_error "foreign developer cannot bypass ownership" "$OTHER" "select $QUERY" "merchant manager access required"
expect_error "legacy non-manager cannot bypass roles" "$STAFF" "select $QUERY" "merchant manager access required"
expect_error "unauthenticated access denied" "" "select $QUERY" "merchant manager access required"
run -c "update public.food_development_features set enabled=true where name='merchant_performance'" >/dev/null
expect_error "non-developer owner remains gated" "$LEGACY" "select $QUERY" "merchant performance is not enabled"
expect_error "null date rejected" "$OWNER" "select public.merchant_order_performance('$STORE',null,'2026-10-13')" "invalid date range"
expect_error "reversed range rejected" "$OWNER" "select public.merchant_order_performance('$STORE','2026-10-14','2026-10-13')" "invalid date range"
expect_error "more than 366 inclusive days rejected" "$OWNER" "select public.merchant_order_performance('$STORE','2025-10-13','2026-10-14')" "date range is too long"
expect_user "$OWNER" "select (($QUERY)->>'total_orders')" "10" "Bangkok half-open boundary and cross-store isolation"
expect_user "$OWNER" "select (($QUERY)->>'completed_orders')||'|'||(($QUERY)->>'cancelled_orders')" "3|4" "terminal counts from actual order statuses"
expect_user "$OWNER" "select (($QUERY)->>'accepted_orders')||'|'||(($QUERY)->>'acceptance_eligible_orders')||'|'||(($QUERY)->>'acceptance_rate')" "6|9|66.67" "acceptance denominator excludes unsubmitted unpaid orders and retains payment history"
expect_user "$OWNER" "select (($QUERY)->>'merchant_cancelled_orders')||'|'||(($QUERY)->>'merchant_cancel_rate')||'|'||(($QUERY)->>'unattributed_cancelled_orders')" "1|11.11|3" "merchant cancellations use role evidence, deduplicate events, and exclude customer/system/foreign actor"
expect_user "$OWNER" "select (($QUERY)->>'preparation_samples')||'|'||(($QUERY)->>'average_preparation_minutes')" "3|10.00" "preparation excludes invalid/missing timestamps and includes zero-minute valid sample"
expect_user "$OWNER" "select (($QUERY)->'top_items'->0->>'quantity')||'|'||(($QUERY)->'top_items'->1->>'quantity')" "5|3" "top menu counts delivered paid orders only, preserving deleted menu snapshots"
expect_user "$OWNER" "select (($QUERY) ? 'income')::text||'|'||(($QUERY) ? 'gp')::text" "false|false" "performance does not duplicate financial calculations"
expect_user "$OWNER" "select (s->'acceptance_rate'='null'::jsonb)::text||'|'||(s->'average_preparation_minutes'='null'::jsonb)::text||'|'||(s->>'total_orders')||'|'||(s->'top_items'='[]'::jsonb)::text from (select public.merchant_order_performance('$STORE','2026-11-01','2026-11-01') s) t" "true|true|0|true" "empty data returns unknown rates and no fabricated samples"
expect_user "$OWNER" "select (($QUERY)->>'total_orders') from (select public.merchant_order_performance('$STORE','2025-10-13','2026-10-13')) valid_range" "10" "366 inclusive days accepted"
expect_db "select has_function_privilege('anon','public.merchant_order_performance(uuid,date,date)','EXECUTE')::text" "false" "anonymous RPC execution denied"
expect_db "select has_table_privilege('authenticated','public.food_orders','SELECT')::text" "false" "report requires no broad table privileges"
run -c "update public.food_development_features set developer_only=false where name='merchant_performance'" >/dev/null
expect_user "$LEGACY" "select (($QUERY)->>'total_orders')" "10" "legacy owner supported without widening staff access"
run -c "update public.merchant_memberships set active=false where user_id='$OWNER'" >/dev/null
expect_error "revoked owner cannot rely on developer bypass" "$OWNER" "select $QUERY" "merchant manager access required"
expect_db "select count(*) from public.food_orders" "13" "read-only report retains every order"
