#!/usr/bin/env bash
# Food order-status notifications and share-link results.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_order_push_share_stats_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_order_push_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { $PSQL -q -X -t -A -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

STORE=00000000-0000-4000-8000-0000000000a1
HIDDEN=00000000-0000-4000-8000-0000000000a2
ACCOUNT=00000000-0000-4000-8000-0000000000b1
BUYER=00000000-0000-4000-8000-0000000000c1
OTHER=00000000-0000-4000-8000-0000000000c2
OWNER=00000000-0000-4000-8000-0000000000d1
O1=00000000-0000-4000-8000-0000000000e1
O2=00000000-0000-4000-8000-0000000000e2
O3=00000000-0000-4000-8000-0000000000e3
O4=00000000-0000-4000-8000-0000000000e4

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid', true), '')::uuid \$\$;
grant usage on schema public, auth, internal to anon, authenticated;
create table public.food_stores(id uuid primary key, name text, description text, logo_path text, cover_path text,
  merchant_account_id uuid, is_published boolean not null default true, admin_suspended_at timestamptz);
create table public.food_orders(id uuid primary key, store_id uuid, buyer_id uuid, order_number text,
  status text not null default 'pending_acceptance', payment_status text not null default 'pending',
  eta_minutes integer, total numeric not null default 100, created_at timestamptz not null default now());
create table public.notifications(id bigserial, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_notifications(id bigserial, merchant_account_id uuid, recipient_user_id uuid, type text, reason text);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, active boolean);
create table public.food_staff(store_id uuid, user_id uuid, active boolean, role text);
create function public.food_has_merchant_access(p_store_id uuid default null) returns boolean language sql stable as
  \$\$ select exists (select 1 from public.food_staff where store_id = p_store_id and user_id = auth.uid() and active) \$\$;
grant select, update on public.food_orders to authenticated;
insert into public.food_stores(id, name, merchant_account_id, is_published) values ('$STORE', 'มะละป๊อกป๊อก', '$ACCOUNT', true), ('$HIDDEN', 'ร่าง', null, false);
insert into public.merchant_memberships values ('$ACCOUNT', '$OWNER', true);
insert into public.food_staff values ('$STORE', '$OWNER', true, 'owner');
insert into public.food_orders(id, store_id, buyer_id, order_number, payment_status) values
  ('$O1', '$STORE', '$BUYER', 'WF0015', 'paid'), ('$O2', '$STORE', '$BUYER', 'WF0016', 'pending'),
  ('$O3', '$STORE', '$BUYER', 'WF0017', 'paid'), ('$O4', '$STORE', '$OTHER', 'WF0018', 'paid');
SQL
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_preview_v1.sql"
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_share_code_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_order_push_share_stats_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_order_push_share_stats_v1.sql"

as_user() { val "set test.uid = '$1'; $2"; }
buyer_says() { val "select reason from public.notifications where recipient_id = '$BUYER' order by id desc limit 1"; }

# Store accepts with an ETA, then sends.
as_user "$OWNER" "update public.food_orders set status = 'preparing', eta_minutes = 20 where id = '$O1'" >/dev/null
[ "$(buyer_says)" = "ออเดอร์ #WF0015 ร้านรับออเดอร์แล้ว · กำลังเตรียมอาหาร (ประมาณ 20 นาที)" ] || fail "accepted: $(buyer_says)"
as_user "$OWNER" "update public.food_orders set status = 'ready_for_delivery' where id = '$O1'" >/dev/null
[ "$(val "select count(*) from public.notifications where recipient_id = '$BUYER'")" = "1" ] || fail "ready_for_delivery stays quiet"
as_user "$OWNER" "update public.food_orders set status = 'out_for_delivery' where id = '$O1'" >/dev/null
[ "$(buyer_says)" = "ออเดอร์ #WF0015 กำลังจัดส่ง · เตรียมรับอาหารได้เลย" ] || fail "out for delivery"
# Updating other columns never notifies.
as_user "$OWNER" "update public.food_orders set total = 120 where id = '$O1'" >/dev/null
[ "$(val "select count(*) from public.notifications where recipient_id = '$BUYER'")" = "2" ] || fail "non-status update is quiet"

# Customer cancels: the store hears about it (Push and the Merchant inbox), the customer does not.
as_user "$BUYER" "update public.food_orders set status = 'cancelled' where id = '$O2'" >/dev/null
[ "$(val "select reason from public.notifications where recipient_id = '$OWNER'")" = "WYNOS Merchant · ลูกค้ายกเลิกออเดอร์ #WF0016" ] || fail "store told of customer cancel"
[ "$(val "select count(*) from public.merchant_notifications where recipient_user_id = '$OWNER' and type = 'order'")" = "1" ] || fail "merchant inbox"
[ "$(val "select count(*) from public.notifications where recipient_id = '$BUYER'")" = "2" ] || fail "customer not told of own cancel"

# Store cancels a paid order: the customer hears about the refund.
as_user "$OWNER" "update public.food_orders set status = 'cancelled' where id = '$O3'" >/dev/null
[ "$(buyer_says)" = "ออเดอร์ #WF0017 ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ" ] || fail "store cancel: $(buyer_says)"

# Share-link opens: published stores only, anon allowed.
CODE=$(val "select share_code from public.food_stores where id = '$STORE'")
HCODE=$(val "select share_code from public.food_stores where id = '$HIDDEN'")
val "set role anon; select public.food_record_share_open('$CODE'); select public.food_record_share_open('$CODE'); select public.food_record_share_open('$HCODE'); select public.food_record_share_open('zzzzzz');" >/dev/null
[ "$(val "select sum(opens) from public.food_share_link_opens where store_id = '$STORE'")" = "2" ] || fail "opens counted"
[ "$(val "select count(*) from public.food_share_link_opens where store_id = '$HIDDEN'")" = "0" ] || fail "hidden store not counted"
if val "set role anon; select * from public.food_share_link_opens" >/dev/null 2>&1; then fail "anon reads opens table"; fi

# Only the buyer marks their own recent order.
val "set role authenticated; set test.uid = '$OTHER'; select public.food_mark_order_from_share('$O1');" >/dev/null
[ "$(val "select from_share_link from public.food_orders where id = '$O1'")" = "f" ] || fail "someone else cannot mark"
val "set role authenticated; set test.uid = '$BUYER'; select public.food_mark_order_from_share('$O1');" >/dev/null
[ "$(val "select from_share_link from public.food_orders where id = '$O1'")" = "t" ] || fail "buyer marks own order"
val "update public.food_orders set created_at = now() - interval '1 hour' where id = '$O4'" >/dev/null
val "set role authenticated; set test.uid = '$OTHER'; select public.food_mark_order_from_share('$O4');" >/dev/null
[ "$(val "select from_share_link from public.food_orders where id = '$O4'")" = "f" ] || fail "old order cannot be marked"
if val "set role anon; select public.food_mark_order_from_share('$O1')" >/dev/null 2>&1; then fail "anon marks orders"; fi

# Stats: store staff only; cancelled orders excluded.
val "update public.food_orders set from_share_link = true where id = '$O3'" >/dev/null
[ "$(val "set role authenticated; set test.uid = '$OWNER'; select opens || '/' || orders || '/' || sales from public.food_share_stats('$STORE', 7)")" = "2/1/120" ] || fail "stats: $(val "set role authenticated; set test.uid = '$OWNER'; select opens || '/' || orders || '/' || sales from public.food_share_stats('$STORE', 7)")"
if val "set role authenticated; set test.uid = '$BUYER'; select * from public.food_share_stats('$STORE', 7)" >/dev/null 2>&1; then fail "non-staff reads stats"; fi
echo "PASS: food order push and share stats"
