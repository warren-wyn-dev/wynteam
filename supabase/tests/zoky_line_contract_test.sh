#!/usr/bin/env bash
# Isolated PostgreSQL contract QA for the proposed Zoky LINE schema.
# Uses a throwaway database and synthetic users/orders; NEVER production.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="zoky_line_contract_$$"
PSQL="${PSQL:-psql}"
$PSQL -v ON_ERROR_STOP=1 -q -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB with (force)" >/dev/null 2>&1 || true' EXIT
sql() { $PSQL -v ON_ERROR_STOP=1 -X -q -d "$DB" "$@"; }
result() { sql -At -c "$1"; }
OWNER="123e4567-e89b-42d3-a456-426614174000"
OTHER="123e4567-e89b-42d3-a456-426614174001"
STORE="123e4567-e89b-42d3-a456-426614174002"
OTHERSTORE="123e4567-e89b-42d3-a456-426614174003"
ACCOUNT="123e4567-e89b-42d3-a456-426614174004"
ORDER1="123e4567-e89b-42d3-a456-426614174005"
ORDER2="123e4567-e89b-42d3-a456-426614174006"
LINEUSER="Uaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
NONCE="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
sql >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role bypassrls; exception when duplicate_object then null; end \$\$;
create extension if not exists pgcrypto;
create schema auth;
create table auth.users(id uuid primary key);
insert into auth.users(id) values ('$OWNER'),('$OTHER');
create table public.food_stores(id uuid primary key,merchant_account_id uuid,name text);
create table public.merchant_memberships(merchant_account_id uuid,user_id uuid,role text,active boolean);
create table public.food_staff(store_id uuid,user_id uuid,role text,active boolean);
create table public.food_orders(id uuid primary key,store_id uuid,order_number text,
    status text,payment_status text,payment_method text,refund_status text,
    refund_requested_at timestamptz,accepted_at timestamptz,cancelled_at timestamptz,total numeric);
create table public.food_order_events(order_id uuid,event_type text,from_status text,
    to_status text,note text,actor_id uuid);
-- Minimal canonical transition stand-in: repeats the role check and refund semantics
-- so LINE must delegate instead of updating order status itself.
create function public.food_transition_order(p_order_id uuid,p_status text,p_eta_minutes integer default null,p_note text default null)
returns void language plpgsql security definer set search_path='public' as \$proc\$
declare current_order public.food_orders%rowtype;
  actor uuid := nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
begin
  select * into current_order from public.food_orders where id=p_order_id for update;
  if not found or current_order.status<>'pending_acceptance' or p_status not in ('preparing','cancelled') then
    raise exception 'invalid order transition';
  end if;
  if not exists (select 1 from public.food_stores s join public.merchant_memberships m
    on m.merchant_account_id=s.merchant_account_id
    where s.id=current_order.store_id and m.user_id=actor and m.active
      and m.role in ('owner','admin','manager','orders')) then
    raise exception 'canonical role check failed';
  end if;
  if p_status='preparing' and current_order.payment_status<>'paid' and current_order.payment_method<>'cod' then
    raise exception 'payment must be verified first';
  end if;
  update public.food_orders set status=p_status,
    accepted_at=case when p_status='preparing' then now() else accepted_at end,
    cancelled_at=case when p_status='cancelled' then now() else cancelled_at end,
    refund_status=case when p_status='cancelled' and current_order.payment_status='paid' then 'pending' else refund_status end,
    refund_requested_at=case when p_status='cancelled' and current_order.payment_status='paid' then now() else refund_requested_at end
  where id=p_order_id;
  insert into public.food_order_events(order_id,event_type,from_status,to_status,note,actor_id)
  values(p_order_id,'status_changed',current_order.status,p_status,p_note,actor);
end;
\$proc\$;
grant usage on schema public to anon,authenticated,service_role;
grant select on public.food_stores,public.merchant_memberships,public.food_staff,public.food_orders to service_role;
grant update on public.food_orders to service_role;
grant insert on public.food_order_events to service_role;
insert into public.food_stores values ('$STORE','$ACCOUNT','ร้าน Zoky ทดสอบ'),('$OTHERSTORE',null,'ร้านอื่น');
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true);
insert into public.food_orders(id,store_id,order_number,status,payment_status,payment_method,refund_status,total)
values ('$ORDER1','$STORE','ZK1001','pending_acceptance','pending','transfer','none',200),
       ('$ORDER2','$STORE','ZK1002','pending_acceptance','paid','transfer','none',150);
SQL

# Apply the candidate only to the disposable database. The production DB is untouched.
sql -f "$ROOT/docs/engineering/zoky-line-end-to-end-schema-candidate.sql" >/dev/null

sql >/dev/null <<SQL
insert into public.zoky_line_enabled_stores(store_id) values('$STORE');
insert into public.zoky_line_link_requests(nonce_sha256,store_id,user_id,expires_at)
values('$NONCE','$STORE','$OWNER',now()+interval '10 minutes');
SQL
[[ "$(result "set role service_role; select public.zoky_line_complete_link('$NONCE','$LINEUSER');")" == "t" ]] ||
  { echo "FAIL: first linking"; exit 1; }
[[ "$(result "set role service_role; select public.zoky_line_complete_link('$NONCE','$LINEUSER');")" == "f" ]] ||
  { echo "FAIL: replay accepted"; exit 1; }
[[ "$(result "select count(*) from public.zoky_line_delivery_queue where order_id='$ORDER1'")" == "0" ]] ||
  { echo "FAIL: unpaid order queued"; exit 1; }

# Make a new pending -> paid transition; trigger should queue exactly one alert.
sql -c "update public.food_orders set payment_status='paid' where id='$ORDER1';" >/dev/null
[[ "$(result "select count(*) from public.zoky_line_delivery_queue where order_id='$ORDER1'")" == "1" ]] ||
  { echo "FAIL: paid order not queued"; exit 1; }
[[ "$(result "set role service_role; select count(*) from public.zoky_line_claim_deliveries(20);")" == "1" ]] ||
  { echo "FAIL: outbox claim"; exit 1; }
[[ "$(result "set role service_role; select (public.zoky_line_transition_order('$LINEUSER','accept','$ORDER1')->>'ok');")" == "true" ]] ||
  { echo "FAIL: eligible acceptance"; exit 1; }
[[ "$(result "set role service_role; select (public.zoky_line_transition_order('$LINEUSER','accept','$ORDER1')->>'ok');")" == "false" ]] ||
  { echo "FAIL: duplicate order transition"; exit 1; }
[[ "$(result "select status from public.food_orders where id='$ORDER1'")" == "preparing" ]] ||
  { echo "FAIL: accepted order status"; exit 1; }
[[ "$(result "set role service_role; select (public.zoky_line_transition_order('Ubbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','reject','$ORDER2')->>'ok');")" == "false" ]] ||
  { echo "FAIL: unauthorized LINE user"; exit 1; }
[[ "$(result "set role service_role; select (public.zoky_line_transition_order('$LINEUSER','reject','$ORDER2')->>'ok');")" == "true" ]] ||
  { echo "FAIL: cancellation"; exit 1; }
[[ "$(result "select refund_status from public.food_orders where id='$ORDER2'")" == "pending" ]] ||
  { echo "FAIL: paid cancel refund pending"; exit 1; }
sql -c "update public.merchant_memberships set active=false where user_id='$OWNER'" >/dev/null
[[ "$(result "set role service_role; select (public.zoky_line_transition_order('$LINEUSER','accept','$ORDER2')->>'ok');")" == "false" ]] ||
  { echo "FAIL: revoked role action"; exit 1; }
if sql -c "set role authenticated; select * from public.zoky_line_connections;" >/dev/null 2>&1; then
  echo "FAIL: authenticated user can read LINE links"; exit 1
fi
echo "Zoky LINE isolated schema contract checks passed"
