#!/usr/bin/env bash
# WYNOS Finance Control Center integration regression.
# Applies the real finance migrations to a throwaway PostgreSQL database.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_finance_control_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "ok - $1"; }
expect_db() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || fail "$3 (got '$got', want '$2')"; pass "$3"; }
as_user() { run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" 2>&1 | tail -n1; }
expect_as() { local got; got="$(as_user "$1" "$2")"; [[ "$got" == "$3" ]] || fail "$4 (got '$got', want '$3')"; pass "$4"; }
expect_fail_as() {
  local out
  out="$(run -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" 2>&1 || true)"
  grep -Fq "$4" <<<"$out" || fail "$3 (expected '$4', got '$out')"
  pass "$3"
}

ADMIN=00000000-0000-0000-0000-0000000000a1
USER=00000000-0000-0000-0000-0000000000b1
STORE=00000000-0000-0000-0000-0000000000c1
STORE2=00000000-0000-0000-0000-0000000000c2
CAMPAIGN=00000000-0000-0000-0000-0000000000d1
ORDER1=00000000-0000-0000-0000-000000000101
ORDER2=00000000-0000-0000-0000-000000000102
ORDER3=00000000-0000-0000-0000-000000000103

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role service_role; exception when duplicate_object then null; end \$\$;
create schema auth;
create schema internal;
create function auth.uid() returns uuid language sql stable as \$\$
  select nullif(current_setting('test.uid',true),'')::uuid
\$\$;
create table auth.users(id uuid primary key);
create table public.profiles(
  id uuid primary key,
  username text,
  display_name text,
  platform_role text not null default 'user'
);
create function internal.current_platform_role() returns text
language sql stable security definer set search_path='' as \$\$
  select p.platform_role from public.profiles p where p.id=auth.uid()
\$\$;
create table public.audit_log(
  id uuid primary key default gen_random_uuid(),
  actor_id uuid,
  actor_username_snapshot text,
  event_type text not null,
  target_id uuid,
  detail jsonb,
  created_at timestamptz not null default now(),
  constraint audit_log_event_type_check check(event_type in ('admin_user_unbanned'))
);
create function internal.log_audit_event(p_actor_id uuid,p_event_type text,p_target_id uuid,p_detail jsonb)
returns void language plpgsql security definer set search_path='' as \$\$
declare u text;
begin
  select username into u from public.profiles where id=p_actor_id;
  insert into public.audit_log(actor_id,actor_username_snapshot,event_type,target_id,detail)
  values(p_actor_id,u,p_event_type,p_target_id,p_detail);
end \$\$;

create table public.merchant_accounts(id uuid primary key);
create table public.merchant_memberships(
  merchant_account_id uuid,user_id uuid,role text,active boolean default true,
  primary key(merchant_account_id,user_id)
);
create table public.food_service_areas(
  code text primary key,name text not null,active boolean not null default true,
  min_lat double precision not null,max_lat double precision not null,
  min_lng double precision not null,max_lng double precision not null,
  lats double precision[] not null,lngs double precision[] not null,
  updated_at timestamptz default now()
);
create function internal.food_point_in_polygon(double precision,double precision,double precision[],double precision[])
returns boolean language sql immutable as \$\$ select true \$\$;
create function internal.food_in_service_area(p_lat double precision,p_lng double precision)
returns boolean language sql stable as \$\$ select p_lat is not null and p_lng is not null \$\$;
create function internal.food_distance_km(
  p_lat1 double precision,p_lng1 double precision,p_lat2 double precision,p_lng2 double precision
) returns numeric language sql immutable as \$\$ select round(abs(coalesce(p_lat2,0))::numeric,2) \$\$;

create table public.food_stores(
  id uuid primary key,
  slug text not null,
  name text not null,
  merchant_account_id uuid,
  delivery_fee numeric(10,2) not null default 0,
  delivery_base_km numeric(6,2) not null default 2,
  delivery_fee_per_km numeric(10,2) not null default 0,
  latitude double precision,
  longitude double precision,
  delivery_radius_km numeric(6,2) not null default 10,
  stripe_payments_enabled boolean not null default false
);
create table public.developer_accounts(user_id uuid primary key);
create function public.food_has_merchant_access(p_store_id uuid)
returns boolean language sql stable security definer set search_path='' as \$\$
  select exists(
    select 1 from public.food_stores s join public.merchant_memberships m
      on m.merchant_account_id=s.merchant_account_id
    where s.id=p_store_id and m.user_id=auth.uid() and m.active
  )
\$\$;

create table public.food_campaigns(
  id uuid primary key,store_id uuid not null,name text not null,campaign_type text not null,
  discount_value numeric not null default 0,max_discount numeric,scope text not null default 'store',
  min_subtotal numeric not null default 0,deleted_at timestamptz,is_active boolean not null default true,
  starts_at timestamptz not null default now(),ends_at timestamptz,
  usage_limit integer,usage_count integer not null default 0,
  platform_share_percent numeric not null default 0
);
create table public.food_campaign_items(campaign_id uuid,menu_item_id uuid);
create table public.food_orders(
  id uuid primary key,
  order_number text not null,
  store_id uuid not null,
  buyer_id uuid,
  subtotal numeric(12,2) not null,
  delivery_fee numeric(12,2) not null default 0,
  campaign_discount numeric(12,2) not null default 0,
  delivery_discount numeric(12,2) not null default 0,
  total numeric(12,2) not null,
  delivery_distance_km numeric(8,2),
  status text not null default 'pending_acceptance',
  payment_status text not null default 'pending',
  payment_provider text,
  stripe_checkout_session_id text,
  stripe_payment_intent_id text,
  stripe_refund_id text,
  refund_status text not null default 'none',
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.food_order_campaigns(
  order_id uuid primary key,
  campaign_id uuid,
  campaign_name text not null,
  campaign_type text not null,
  campaign_discount numeric not null default 0,
  delivery_discount numeric not null default 0,
  platform_funded numeric not null default 0
);
create table public.food_stripe_payments(
  order_id uuid primary key,
  store_id uuid not null,
  buyer_id uuid,
  stripe_account_id text not null,
  checkout_session_id text,
  payment_intent_id text,
  amount_satang bigint not null,
  currency text not null default 'thb',
  status text not null default 'pending',
  attempt integer not null default 1,
  payment_method text,
  last_error text,
  paid_at timestamptz,
  refunded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  livemode boolean not null default false
);

grant usage on schema public,auth,internal to authenticated,anon,service_role;
insert into auth.users values('$ADMIN'),('$USER');
insert into public.profiles values('$ADMIN','admin1','Admin','admin'),('$USER','user1','User','user');
insert into public.merchant_accounts values('00000000-0000-0000-0000-00000000e001');
insert into public.merchant_memberships values('00000000-0000-0000-0000-00000000e001','$USER','owner',true);
insert into public.food_service_areas(code,name,min_lat,max_lat,min_lng,max_lng,lats,lngs)
values('maha_sarakham','มหาสารคาม',-90,90,-180,180,array[0,1,1],array[0,0,1]);
insert into public.food_stores(
  id,slug,name,merchant_account_id,delivery_fee,delivery_base_km,delivery_fee_per_km,latitude,longitude
) values
('$STORE','one','Store One','00000000-0000-0000-0000-00000000e001',25,2,7,1,1),
('$STORE2','two','Store Two',null,25,2,7,1,1);
insert into public.food_campaigns(id,store_id,name,campaign_type,discount_value,starts_at,platform_share_percent)
values('$CAMPAIGN','$STORE','Shared promo','fixed',50,now()-interval '1 hour',60);
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_finance_control_center_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_finance_engine_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_finance_admin_api_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_finance_hardening_v1.sql"
pass "finance migrations apply on the additive fixture"

expect_db "select default_gp_bps from public.food_finance_configs order by effective_from desc limit 1" "1000" "default GP is 10%"
expect_db "select internal.food_feature_enabled('promptpay_enabled','2026-10-08')" "t" "PromptPay default is ON"
expect_db "select internal.food_feature_enabled('card_enabled','2026-10-08')" "f" "Card default is OFF"
expect_db "select internal.food_feature_enabled('rider_enabled','2026-10-08')" "f" "Rider default is OFF"
expect_db "select tax_enabled::text||'|'||vat_registered::text from public.food_finance_configs order by effective_from desc limit 1" "false|false" "VAT remains OFF"

expect_db "select gp_bps||'|'||gp_source from internal.food_effective_gp('$STORE2',now())" "1000|default" "store without GP override uses default"
run -q -c "insert into public.food_store_finance_overrides(store_id,effective_from,custom_gp_bps,reason) values('$STORE',now(),1500,'custom GP test')" >/dev/null
expect_db "select gp_bps||'|'||gp_source from internal.food_effective_gp('$STORE',now()+interval '1 second')" "1500|custom" "custom merchant GP overrides default"
run -q -c "insert into public.food_store_gp_promotions(store_id,gp_bps,starts_at,ends_at,reason) values('$STORE',0,now()-interval '1 minute',now()+interval '1 hour','new store promo')" >/dev/null
expect_db "select gp_bps||'|'||gp_source from internal.food_effective_gp('$STORE',now())" "0|promotion" "temporary GP overrides custom GP and supports 0%"

expect_db "select delivery_fee from internal.food_delivery_fee('$STORE',4,1)" "39.0000000000000000" "4 km delivery is 25 + 2 x 7 = 39"
expect_db "select delivery_fee from internal.food_delivery_fee('$STORE',4.1,1)" "46.0000000000000000" "distance rounding is configurable and rounds extra distance"
expect_db "select total_satang from internal.food_rider_earning(3,now())" "4000" "rider earning is 25 + 3 x 5 = 40 baht"

run -q -c "update public.food_store_gp_promotions set active=false where store_id='$STORE';
insert into public.food_orders(id,order_number,store_id,buyer_id,subtotal,delivery_fee,total,delivery_distance_km)
values('$ORDER2','F102','$STORE','$USER',300,39,339,4);" >/dev/null
expect_db "select gp_bps from public.food_order_financials where order_id='$ORDER2'" "1500" "order snapshots custom GP at creation"

run -q -c "insert into public.food_store_finance_overrides(store_id,effective_from,custom_gp_bps,reason)
values('$STORE',now()+interval '1 second',2000,'future GP test')" >/dev/null
expect_db "select gp_bps from public.food_order_financials where order_id='$ORDER2'" "1500" "later GP changes do not alter historical order snapshot"

run -q -c "insert into public.food_orders(id,order_number,store_id,buyer_id,subtotal,delivery_fee,campaign_discount,total,delivery_distance_km,status,payment_status,payment_provider)
values('$ORDER3','F103','$STORE','$USER',300,39,50,289,4,'delivered','paid','stripe');
insert into public.food_order_campaigns(order_id,campaign_id,campaign_name,campaign_type,campaign_discount,delivery_discount,platform_funded)
values('$ORDER3','$CAMPAIGN','Shared promo','fixed',50,0,30);" >/dev/null
expect_db "select merchant_funded_satang||'|'||platform_funded_satang from public.food_order_campaigns where order_id='$ORDER3'" "2000|3000" "promotion cost sharing snapshots merchant/platform portions"
expect_db "select merchant_discount_satang||'|'||platform_discount_satang from public.food_order_financials where order_id='$ORDER3'" "2000|3000" "financial snapshot receives promotion cost sharing"

expect_fail_as "$USER" "select public.admin_finance_control_snapshot()" "ordinary user cannot call Admin finance RPC" "Only admins can manage finance"
expect_db "select has_table_privilege('authenticated','public.food_finance_configs','select')" "f" "finance config table is deny-by-default"
expect_db "select has_table_privilege('authenticated','public.food_order_financials','select')" "f" "financial ledger table is deny-by-default"

expect_as "$ADMIN" "select (public.admin_finance_control_snapshot()->'flags'->>'promptpay_enabled')" "true" "admin can read central finance control snapshot"
expect_as "$ADMIN" "select public.admin_set_feature_flag('peak_pricing_enabled',true,now()+interval '2 seconds','test enable','{}')::text" "" "admin can change feature flag with reason"
expect_db "select count(*) from public.audit_log where event_type='admin_feature_flag_changed'" "1" "feature flag change is audited"

PREVIEW="$(as_user "$ADMIN" "select public.admin_merchant_settlement_preview('$STORE',now()-interval '1 day',now()+interval '1 day')")"
COUNT="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["order_count"])' "$PREVIEW")"
NET="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["net_satang"])' "$PREVIEW")"
SETTLEMENT="$(as_user "$ADMIN" "select public.admin_create_merchant_settlement('$STORE',now()-interval '1 day',now()+interval '1 day',$COUNT,$NET,null,'settlement test','{}')")"
[[ "$SETTLEMENT" =~ ^[0-9a-f-]{36}$ ]] || fail "merchant settlement id"
pass "merchant settlement is created from server preview"
expect_as "$ADMIN" "select public.admin_merchant_settlement_preview('$STORE',now()-interval '1 day',now()+interval '1 day')->>'order_count'" "0" "settled orders cannot enter a duplicate settlement"
expect_db "select count(*) from public.audit_log where event_type='admin_merchant_settlement_created'" "1" "settlement is audited"

run -q -c "grant select,insert,update,delete on public.audit_log to authenticated" >/dev/null
expect_fail_as "$ADMIN" "delete from public.audit_log where event_type='admin_feature_flag_changed'" "finance audit cannot be deleted through authenticated API role" "financial audit log is immutable"

echo "PASS: WYNOS Finance Control Center integration"
