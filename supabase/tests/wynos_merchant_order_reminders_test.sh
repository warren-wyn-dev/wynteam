#!/usr/bin/env bash
# WYNOS Merchant order reminders: one push a minute, at most 5, only for paid
# or slip-submitted orders still waiting for the store, never old orders.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs
# (no pg_cron locally: the job function is called directly).
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_merchant_order_reminders_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_merchant_reminders_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { $PSQL -q -X -t -A -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

STORE=00000000-0000-4000-8000-0000000000a1
OWNER=00000000-0000-4000-8000-0000000000d1
STAFF=00000000-0000-4000-8000-0000000000d2
GONE=00000000-0000-4000-8000-0000000000d3
PAID=00000000-0000-4000-8000-0000000000e1
SLIP=00000000-0000-4000-8000-0000000000e2
UNPAID=00000000-0000-4000-8000-0000000000e3
ACCEPTED=00000000-0000-4000-8000-0000000000e4
OLD=00000000-0000-4000-8000-0000000000e5
FRESH=00000000-0000-4000-8000-0000000000e6

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema internal;
create table public.food_stores(id uuid primary key);
create table public.food_orders(id uuid primary key, store_id uuid, order_number text, status text, payment_status text,
  paid_at timestamptz, created_at timestamptz not null, updated_at timestamptz not null);
create table public.notifications(id bigserial, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.food_staff(store_id uuid, user_id uuid, active boolean, role text);
insert into public.food_stores values ('$STORE');
insert into public.food_staff values ('$STORE', '$OWNER', true, 'owner'), ('$STORE', '$STAFF', true, 'staff'), ('$STORE', '$GONE', false, 'staff');
insert into public.food_orders values
  ('$PAID', '$STORE', 'WF0015', 'pending_acceptance', 'paid', now() - interval '3 minutes', now() - interval '5 minutes', now() - interval '3 minutes'),
  ('$SLIP', '$STORE', 'WF0016', 'pending_acceptance', 'submitted', null, now() - interval '2 minutes', now() - interval '2 minutes'),
  ('$UNPAID', '$STORE', 'WF0017', 'pending_acceptance', 'pending', null, now() - interval '10 minutes', now() - interval '10 minutes'),
  ('$ACCEPTED', '$STORE', 'WF0018', 'preparing', 'paid', now() - interval '9 minutes', now() - interval '10 minutes', now() - interval '8 minutes'),
  ('$OLD', '$STORE', 'WF0019', 'pending_acceptance', 'paid', now() - interval '5 hours', now() - interval '5 hours', now() - interval '5 hours'),
  ('$FRESH', '$STORE', 'WF0020', 'pending_acceptance', 'paid', now() - interval '10 seconds', now() - interval '20 seconds', now() - interval '10 seconds');
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_order_reminders_v1.sql"
# Re-applying is safe.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_merchant_order_reminders_v1.sql"

[ "$(val "select internal.food_remind_waiting_orders()")" = "2" ] || fail "first run reminds paid and slip-submitted orders only"
[ "$(val "select count(*) from public.notifications")" = "4" ] || fail "one push per active owner/staff per order"
[ "$(val "select count(*) from public.notifications where recipient_id = '$GONE'")" = "0" ] || fail "inactive staff skipped"
[ "$(val "select reason from public.notifications where recipient_id = '$OWNER' and reason like '%WF0015%'")" = "WYNOS Merchant · ออเดอร์ #WF0015 รอรับ 3 นาทีแล้ว" ] || fail "text: $(val "select reason from public.notifications where reason like '%WF0015%' limit 1")"
[ "$(val "select internal.food_remind_waiting_orders()")" = "0" ] || fail "nothing again within the same minute"

# Each later minute adds one reminder, up to 5 in total.
for i in 2 3 4 5 6 7; do
  val "update public.food_order_merchant_reminders set last_sent_at = now() - interval '61 seconds'" >/dev/null
  val "select internal.food_remind_waiting_orders()" >/dev/null
done
[ "$(val "select sent from public.food_order_merchant_reminders where order_id = '$PAID'")" = "5" ] || fail "capped at 5"
[ "$(val "select count(*) from public.notifications where reason like '%WF0015%'")" = "10" ] || fail "5 reminders x 2 staff"

# Accepting stops the reminders.
val "update public.food_orders set status = 'preparing' where id = '$FRESH'" >/dev/null
[ "$(val "select count(*) from public.notifications where reason like '%WF0020%'")" = "0" ] || fail "accepted order never reminded"
[ "$(val "select count(*) from public.notifications where reason like '%WF0017%' or reason like '%WF0018%' or reason like '%WF0019%'")" = "0" ] || fail "unpaid, accepted and old orders stay quiet"
if val "set role anon; select * from public.food_order_merchant_reminders" >/dev/null 2>&1; then fail "anon reads reminders"; fi
echo "PASS: merchant order reminders"
