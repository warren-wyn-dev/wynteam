#!/usr/bin/env bash
# WYNOS Merchant GP v1 (supabase/migrations/20261011140000_merchant_gp_v1.sql).
#
#   1. No rate row -> every store and every new order is 0% (Founder: no GP yet).
#   2. Rate resolution: store rate beats default; latest start wins; a
#      temporary rate ends and the earlier one applies again; cancelled and
#      future rates do not apply.
#   3. Orders snapshot the rate on insert, ignore caller-supplied values and
#      never change after; a later GP change does not touch placed orders.
#   4. GP maths in satang: base = subtotal - max(campaign_discount -
#      platform_funded, 0), delivery excluded, round half up, capped at total.
#   5. Only the super admin sets/cancels; merchant:view reads; others refused.
#      Validation (range, reason, past start, end before start, store exists),
#      idempotency, audit rows, append-only history (no update/delete).
#   6. food_order_gp_quote is service-role only.
#
# Usage: PSQL="sudo -u postgres psql" supabase/tests/merchant_gp_v1_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="merchant_gp_v1_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

SUPER=00000000-0000-0000-0000-0000000000a1
MERCHANT_VIEW=00000000-0000-0000-0000-0000000000a2
MERCHANT_EDIT=00000000-0000-0000-0000-0000000000a3
USER=00000000-0000-0000-0000-0000000000a5
STORE=00000000-0000-0000-0000-0000000000f1
OTHER=00000000-0000-0000-0000-0000000000f2

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, username text);
create table internal.platform_super_admins(user_id uuid primary key);
create table public.admin_permissions(user_id uuid, system text, level text, primary key (user_id, system));
create function internal.is_super_admin() returns boolean language sql stable security definer set search_path = '' as \$\$
  select exists (select 1 from internal.platform_super_admins s where s.user_id = auth.uid()) \$\$;
create function internal.has_admin_permission(p_system text, p_level text) returns boolean language sql stable security definer set search_path = '' as \$\$
  select internal.is_super_admin()
      or exists (select 1 from public.admin_permissions ap where ap.user_id = auth.uid() and ap.system = p_system
                 and (ap.level = 'edit' or p_level = 'view')) \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, actor_username_snapshot text, event_type text, target_id uuid, detail jsonb,
  created_at timestamptz default now(),
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned', 'admin_permission_granted')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void
  language sql security definer set search_path = public as \$\$
  insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.food_stores(id uuid primary key, name text, is_published boolean default true, admin_suspended_at timestamptz);
create table public.food_orders(id uuid primary key default gen_random_uuid(), store_id uuid, status text default 'pending_acceptance',
  subtotal numeric(10,2), delivery_fee numeric(10,2), total numeric(10,2), created_at timestamptz default now());
create table public.food_order_campaigns(order_id uuid primary key, campaign_discount numeric(10,2) default 0, delivery_discount numeric(10,2) default 0,
  platform_funded numeric(10,2) default 0, released_at timestamptz);
create table public.food_stripe_payments(order_id uuid primary key, amount_satang bigint not null);
grant usage on schema public, auth, internal to authenticated, anon, service_role;

insert into public.profiles values ('$SUPER','founder'), ('$MERCHANT_VIEW','mv'), ('$MERCHANT_EDIT','me'), ('$USER','u');
insert into internal.platform_super_admins values ('$SUPER');
insert into public.admin_permissions values ('$MERCHANT_VIEW','merchant','view'), ('$MERCHANT_EDIT','merchant','edit');
insert into public.food_stores(id, name) values ('$STORE','ร้าน A'), ('$OTHER','ร้าน B');
insert into public.food_orders(id, store_id, subtotal, delivery_fee, total)
  values ('00000000-0000-0000-0000-0000000000c0','$STORE',100,20,120);
SQL

MIGRATION="$ROOT/supabase/migrations/20261011140000_merchant_gp_v1.sql"
run >/dev/null < "$MIGRATION"
run >/dev/null < "$MIGRATION"   # idempotent

q()  { run -At -c "$1" 2>&1 | tail -n1; }
as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
eq() { [[ "$1" == "$2" ]] || { echo "FAIL: $3 (got '$1', want '$2')"; exit 1; }; }
fails() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
          [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }
rate_at() { q "select coalesce((select rate_bp::text || ':' || source from internal.merchant_gp_rate_at('$1', $2)), 'none')"; }
new_order() { q "insert into public.food_orders(store_id, subtotal, delivery_fee, total, gp_rate_bp, gp_rate_id) values ('$1',$2,$3,$4, 9999, gen_random_uuid()) returning id"; }

# 1. Nothing set: 0% everywhere; orders placed before GP v1 count as 0%.
eq "$(rate_at "$STORE" "now()")" "none" "no rate row -> none"
O0="$(new_order "$STORE" 100 20 120)"
eq "$(q "select gp_rate_bp || ':' || (gp_rate_id is null) || ':' || gp_rule_version from public.food_orders where id = '$O0'")" "0:true:gp_v1_food_after_store_discount" "new order snapshots 0% and ignores caller values"
eq "$(q "select gp_satang from internal.food_order_gp('00000000-0000-0000-0000-0000000000c0')")" "0" "pre-GP order is 0"

# 2. Resolution (rows inserted directly to place them in the past).
run -q >/dev/null <<SQL
insert into public.merchant_gp_rates(store_id, rate_bp, effective_from, effective_to, reason, idempotency_key)
  values (null, 2000, '2026-01-01', null, 'default seed', gen_random_uuid()),
         ('$STORE', 1500, '2026-02-01', null, 'store A deal', gen_random_uuid()),
         ('$STORE', 1000, '2026-03-01', '2026-03-08', 'promo week', gen_random_uuid());
SQL
eq "$(rate_at "$OTHER" "'2026-01-15'")" "2000:default" "store without own rate uses default"
eq "$(rate_at "$STORE" "'2026-01-15'")" "2000:default" "before store rate starts: default"
eq "$(rate_at "$STORE" "'2026-02-15'")" "1500:store" "store rate beats default"
eq "$(rate_at "$STORE" "'2026-03-05'")" "1000:store" "temporary rate inside its window"
eq "$(rate_at "$STORE" "'2026-03-08'")" "1500:store" "temporary rate ended: earlier store rate again"
eq "$(rate_at "$STORE" "'2025-12-31'")" "none" "before any rate"

# 3. Snapshot and freezing.
O1="$(new_order "$STORE" 100 20 120)"
eq "$(q "select gp_rate_bp from public.food_orders where id = '$O1'")" "1500" "order snapshots store rate"
run -q -c "update public.food_orders set gp_rate_bp = 0, gp_rate_id = null, total = 119 where id = '$O1'" >/dev/null
eq "$(q "select gp_rate_bp || ':' || (gp_rate_id is not null) || ':' || total from public.food_orders where id = '$O1'")" "1500:true:119.00" "snapshot frozen on update; other columns still update"

# 4. GP maths. 100 food, 20 delivery, store discount 10 of which WYNOS funds 4.
O2="$(new_order "$STORE" 100 20 110)"
run -q -c "insert into public.food_order_campaigns(order_id, campaign_discount, platform_funded) values ('$O2', 10, 4)" >/dev/null
eq "$(q "select base_satang || ':' || gp_satang from internal.food_order_gp('$O2')")" "9400:1410" "base 94.00 (store discount 6), 15% = 14.10"
# Round half up: base 33.33 * 15% = 4.9995 -> 5.00
O3="$(new_order "$STORE" 33.33 0 33.33)"
eq "$(q "select gp_satang from internal.food_order_gp('$O3')")" "500" "round half up to the satang"
# WYNOS-funded free delivery does not change the base.
O4="$(new_order "$STORE" 50 30 50)"
run -q -c "insert into public.food_order_campaigns(order_id, campaign_discount, delivery_discount, platform_funded) values ('$O4', 0, 30, 30)" >/dev/null
eq "$(q "select base_satang from internal.food_order_gp('$O4')")" "5000" "delivery discount not in base"
# Cap at total: 100% GP on 100 food where customer pays 90 (store discount 0, WYNOS funds 10).
run -q -c "insert into public.merchant_gp_rates(store_id, rate_bp, effective_from, reason, idempotency_key) values ('$OTHER', 10000, '2026-04-01', 'cap test', gen_random_uuid())" >/dev/null
O5="$(new_order "$OTHER" 100 0 90)"
run -q -c "insert into public.food_order_campaigns(order_id, campaign_discount, platform_funded) values ('$O5', 10, 10)" >/dev/null
eq "$(q "select base_satang || ':' || gp_satang from internal.food_order_gp('$O5')")" "10000:9000" "GP capped at what the customer pays"

# 5. Admin RPCs.
K1=11111111-1111-1111-1111-111111111111
fails "$MERCHANT_EDIT" "select public.admin_set_gp_rate('$STORE', 1200, null, null, 'merchant edit tries', '$K1')" "merchant:edit cannot set GP" "Only the super admin"
fails "$USER" "select public.admin_gp_settings()" "plain user cannot read" "Not authorized"
eq "$(as "$MERCHANT_VIEW" "select (public.admin_gp_settings()->>'can_edit')")" "false" "merchant:view reads, cannot edit"
eq "$(as "$SUPER" "select (public.admin_gp_settings()->>'can_edit')")" "true" "super admin can edit"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', 10001, null, null, 'too high', '$K1')" "over 100%" "between 0 and 100"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', -1, null, null, 'negative', '$K1')" "negative" "between 0 and 100"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, null, null, ' x ', '$K1')" "reason required" "reason"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, now() - interval '1 day', null, 'backdate', '$K1')" "no backdating" "past"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, now() + interval '2 day', now() + interval '1 day', 'bad window', '$K1')" "end after start" "end must be after start"
fails "$SUPER" "select public.admin_set_gp_rate(gen_random_uuid(), 1200, null, null, 'ghost store', '$K1')" "unknown store" "store not found"
fails "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, null, null, 'no key', null)" "idempotency key required" "idempotency key"

ID1="$(as "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, null, null, 'ตกลงกับร้าน A', '$K1')")"
ID1b="$(as "$SUPER" "select public.admin_set_gp_rate('$STORE', 1200, null, null, 'ตกลงกับร้าน A', '$K1')")"
eq "$ID1b" "$ID1" "same idempotency key returns the same row"
fails "$SUPER" "select public.admin_set_gp_rate('$OTHER', 500, null, null, 'reuse key', '$K1')" "key reused for other change" "different change"
eq "$(q "select count(*) from public.merchant_gp_rates where idempotency_key = '$K1'")" "1" "only one row for the key"
eq "$(rate_at "$STORE" "now()")" "1200:store" "new rate applies now"
eq "$(q "select gp_rate_bp from public.food_orders where id = '$O1'")" "1500" "placed order keeps its old rate"
eq "$(q "select detail->>'previous_rate_bp' || '>' || (detail->>'rate_bp') from public.audit_log where event_type = 'admin_gp_rate_set'")" "1500>1200" "audit has previous and new rate"

# Future rate, then cancel it.
K2=22222222-2222-2222-2222-222222222222
ID2="$(as "$SUPER" "select public.admin_set_gp_rate(null, 2500, now() + interval '7 day', null, 'ปรับ default เดือนหน้า', '$K2')")"
eq "$(as "$SUPER" "select (public.admin_gp_settings()->'default'->'next'->>'rate_bp')")" "2500" "default shows the scheduled change"
fails "$MERCHANT_EDIT" "select public.admin_cancel_gp_rate('$ID2', 'not allowed')" "merchant:edit cannot cancel" "Only the super admin"
fails "$SUPER" "select public.admin_cancel_gp_rate('$ID1', 'already live')" "live rate cannot be cancelled" "already in effect"
as "$SUPER" "select public.admin_cancel_gp_rate('$ID2', 'เลื่อนออกไป')" >/dev/null
eq "$(q "select (cancelled_at is not null)::text from public.merchant_gp_rates where id = '$ID2'")" "true" "future rate cancelled"
fails "$SUPER" "select public.admin_cancel_gp_rate('$ID2', 'again')" "cannot cancel twice" "already cancelled"
eq "$(q "select count(*) from public.audit_log where event_type = 'admin_gp_rate_cancelled'")" "1" "cancel audited"

# Append-only history, even for the table owner.
if run -q -c "update public.merchant_gp_rates set rate_bp = 1 where id = '$ID1'" >/dev/null 2>&1; then echo "FAIL: live rate edited"; exit 1; fi
if run -q -c "delete from public.merchant_gp_rates where id = '$ID1'" >/dev/null 2>&1; then echo "FAIL: history deleted"; exit 1; fi
fails "$SUPER" "select * from public.merchant_gp_rates" "no direct table access" "permission denied"

# 6. Quote function.
fails "$SUPER" "select public.food_order_gp_quote('$O2')" "authenticated cannot quote" "permission denied"
eq "$(run -At -c "set role service_role;" -c "select public.food_order_gp_quote('$O2')->>'gp_satang'" | tail -n1)" "1410" "service role quote"
eq "$(q "select has_function_privilege('anon','internal.merchant_gp_rate_at(uuid,timestamptz)','execute')")" "f" "helper not callable by anon"

echo "PASS: merchant GP v1"
