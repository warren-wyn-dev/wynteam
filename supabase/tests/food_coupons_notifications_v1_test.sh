#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PSQL=psql
DB="wyn_food_coupon_regression_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
ADMIN=00000000-0000-0000-0000-0000000000a0
BUYER=00000000-0000-0000-0000-0000000000c0
OTHER=00000000-0000-0000-0000-0000000000d0
PUSH_ONLY=00000000-0000-0000-0000-0000000000b1
STORE=00000000-0000-0000-0000-0000000000f1
PC=00000000-0000-0000-0000-0000000000e1
CAM=00000000-0000-0000-0000-0000000000e2
O1=00000000-0000-0000-0000-000000000101
run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$select nullif(current_setting('test.uid',true),'')::uuid\$\$;
create table public.profiles(id uuid primary key,platform_role text);
create function internal.current_platform_role() returns text language sql stable as \$\$select platform_role from public.profiles where id=auth.uid()\$\$;
create table public.food_stores(id uuid primary key);
create table public.food_menu_items(id uuid primary key);
create table public.food_platform_campaigns(id uuid primary key,name text,starts_at timestamptz default now(),ends_at timestamptz,is_active boolean default true,updated_at timestamptz default now());
create table public.food_campaigns(id uuid primary key,store_id uuid,platform_campaign_id uuid,name text,campaign_type text,discount_value numeric,max_discount numeric,scope text,min_subtotal numeric,starts_at timestamptz,ends_at timestamptz,usage_limit integer,usage_count integer,is_active boolean,deleted_at timestamptz);
create table public.food_campaign_items(campaign_id uuid,menu_item_id uuid);
create table public.food_orders(id uuid primary key,buyer_id uuid,status text default 'pending_acceptance',payment_status text default 'pending',payment_due_at timestamptz,campaign_id uuid);
create table public.food_order_campaigns(order_id uuid,platform_campaign_id uuid);
create table public.food_customer_addresses(user_id uuid);
create table public.push_tokens(user_id uuid,platform text,app text,token text);
create function internal.food_set_scheduled_order(uuid,timestamptz) returns void language plpgsql as \$\$begin null; end\$\$;
create function public.food_quote_order(uuid,jsonb,double precision,double precision) returns jsonb language sql as \$\$select jsonb_build_object('campaign_id',null)\$\$;
create function public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision) returns uuid language sql as \$\$select '00000000-0000-0000-0000-000000000101'::uuid\$\$;
insert into auth.users values ('$ADMIN'),('$BUYER'),('$OTHER'),('$PUSH_ONLY');
insert into public.profiles values ('$ADMIN','admin'),('$BUYER','user'),('$OTHER','user'),('$PUSH_ONLY','user');
insert into public.food_stores values ('$STORE');
insert into public.food_platform_campaigns(id,name,starts_at) values ('$PC','Campaign',now()-interval '1 day');
insert into public.food_campaigns values ('$CAM','$STORE','$PC','WYNOS 50','fixed',50,null,'store',0,now()-interval '1 day',null,null,0,true,null);
SQL
run >/dev/null -f "$ROOT/supabase/migrations/20261008161000_food_admin_coupons.sql"
run >/dev/null -f "$ROOT/supabase/migrations/20261008161100_food_promo_notifications.sql"
auto="$(run -At -c "select count(*) from internal.food_campaign_candidates('$STORE',250,20,'{}'::jsonb)")"
[[ "$auto" == 1 ]] || { echo "FAIL: existing automatic campaign"; exit 1; }
cid="$(run -At -c "select set_config('test.uid','$ADMIN',false);" -c "select public.admin_food_issue_coupon('$PC','FOOD50',1,1,null,null)" | tail -1)"
[[ "$cid" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: issue coupon"; exit 1; }
off="$(run -At -c "select count(*) from internal.food_campaign_candidates('$STORE',250,20,'{}'::jsonb)")"
[[ "$off" == 0 ]] || { echo "FAIL: code needed but applied automatically"; exit 1; }
on="$(run -At -c "select set_config('test.uid','$BUYER',false);" -c "select set_config('wyn.food_coupon_code','FOOD50',false);" -c "select count(*) from internal.food_campaign_candidates('$STORE',250,20,'{}'::jsonb)" | tail -1)"
[[ "$on" == 1 ]] || { echo "FAIL: valid code rejected"; exit 1; }
run >/dev/null -c "insert into public.food_orders(id,buyer_id) values ('$O1','$BUYER'); insert into public.food_coupon_redemptions(order_id,coupon_id,user_id) values ('$O1','$cid','$BUYER')"
used="$(run -At -c "select set_config('test.uid','$BUYER',false);" -c "select set_config('wyn.food_coupon_code','FOOD50',false);" -c "select count(*) from internal.food_campaign_candidates('$STORE',250,20,'{}'::jsonb)" | tail -1)"
[[ "$used" == 0 ]] || { echo "FAIL: coupon quota"; exit 1; }
run >/dev/null -c "update public.food_orders set payment_status='submitted',payment_due_at=now()-interval '1 minute' where id='$O1'"
submitted="$(run -At -c "select internal.food_coupon_usage_active('$O1')")"
[[ "$submitted" == t ]] || { echo "FAIL: slip awaiting review released coupon"; exit 1; }
run >/dev/null -c "update public.food_orders set payment_status='refunded' where id='$O1'"
refunded="$(run -At -c "select internal.food_coupon_usage_active('$O1')")"
[[ "$refunded" == t ]] || { echo "FAIL: refunded used coupon should remain consumed by default"; exit 1; }
run >/dev/null -c "update public.food_orders set status='cancelled' where id='$O1'"
paid_cancelled="$(run -At -c "select internal.food_coupon_usage_active('$O1')")"
[[ "$paid_cancelled" == t ]] || { echo "FAIL: refunded cancelled order should not restore coupon"; exit 1; }
# Simulate a distinct unpaid cancellation: only unpaid orders return a slot.
run >/dev/null -c "update public.food_orders set payment_status='pending' where id='$O1'"
released="$(run -At -c "select set_config('test.uid','$BUYER',false);" -c "select set_config('wyn.food_coupon_code','FOOD50',false);" -c "select count(*) from internal.food_campaign_candidates('$STORE',250,20,'{}'::jsonb)" | tail -1)"
[[ "$released" == 1 ]] || { echo "FAIL: cancelled order quota"; exit 1; }
run >/dev/null -c "insert into public.push_tokens values ('$BUYER','web','food','fcm-food'),('$OTHER','web','social','fcm-social'),('$PUSH_ONLY','web','food','fcm-food-2'); insert into public.food_marketing_preferences(user_id,push_marketing) values ('$BUYER',true); insert into public.food_marketing_preferences(user_id,push_marketing,in_app_marketing) values ('$PUSH_ONLY',true,false)"
bid="$(run -At -c "select set_config('test.uid','$ADMIN',false);" -c "select public.admin_food_promo_schedule('Food Promotion','Discount available','$cid','all',now()-interval '1 minute')" | tail -1)"
[[ "$bid" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: schedule promo"; exit 1; }
sent="$(run -At -c "select count(*) from public.food_promo_claim_batch(10)")"
[[ "$sent" == 2 ]] || { echo "FAIL: expected both Food marketing recipients ($sent)"; exit 1; }
notified="$(run -At -c "select count(*) from public.food_notifications")"
[[ "$notified" == 1 ]] || { echo "FAIL: only In-App consented Food customer gets inbox"; exit 1; }
push_only="$(run -At -c "select count(*) from public.food_promo_deliveries where recipient_id='$PUSH_ONLY'")"
[[ "$push_only" == 1 ]] || { echo "FAIL: Push enabled but In-App disabled recipient was skipped"; exit 1; }
leak="$(run -At -c "select count(*) from public.food_promo_deliveries where recipient_id='$OTHER'")"
[[ "$leak" == 0 ]] || { echo "FAIL: Social leaked Food marketing"; exit 1; }
echo "PASS: Food coupon gating, quota, release, and Food-only marketing"
