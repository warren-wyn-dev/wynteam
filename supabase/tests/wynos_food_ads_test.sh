#!/usr/bin/env bash
# WYN-207 behaviour test: WYNOS Food pay-per-click ads controlled by WYNOS Admin.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_ads_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_ads_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

ADMIN=00000000-0000-0000-0000-0000000000a0
MOD=00000000-0000-0000-0000-0000000000b0
OWNER=00000000-0000-0000-0000-0000000000d1
RIDER=00000000-0000-0000-0000-0000000000d3
BUYER=00000000-0000-0000-0000-0000000000c0
BUYER2=00000000-0000-0000-0000-0000000000c2
GUEST=00000000-0000-0000-0000-0000000000c9
ACCOUNT=00000000-0000-0000-0000-0000000000e1
STORE=00000000-0000-0000-0000-0000000000f1
OTHER=00000000-0000-0000-0000-0000000000f2

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema auth; create schema internal; create schema storage;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as \$\$ select nullif(current_setting('test.uid',true),'')::uuid \$\$;
create table public.profiles(id uuid primary key, platform_role text not null default 'user', food_access boolean not null default true);
create function internal.current_platform_role() returns text language sql stable security definer set search_path = public as
  \$\$ select platform_role from public.profiles where id = auth.uid() \$\$;
create function public.food_customer_access_enabled() returns boolean language sql stable security definer set search_path = public as
  \$\$ select coalesce((select food_access from public.profiles where id = auth.uid()), false) \$\$;
create table public.audit_log(id bigserial primary key, actor_id uuid, event_type text not null, target_id uuid, detail jsonb,
  constraint audit_log_event_type_check check (event_type in ('admin_user_unbanned')));
create function internal.log_audit_event(p_actor_id uuid, p_event_type text, p_target_id uuid, p_detail jsonb) returns void language sql security definer as
  \$\$ insert into public.audit_log(actor_id, event_type, target_id, detail) values (p_actor_id, p_event_type, p_target_id, p_detail) \$\$;
create table public.notifications(id bigserial primary key, recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, role text, active boolean default true, primary key (merchant_account_id, user_id));
create table public.food_stores(id uuid primary key, slug text, name text, merchant_account_id uuid, logo_path text, cover_path text,
  address text, business_hours text, delivery_fee numeric default 20, latitude double precision, longitude double precision,
  prep_time_min_minutes integer default 15, prep_time_max_minutes integer default 30,
  is_open boolean default true, is_published boolean default true, admin_suspended_at timestamptz);
create function internal.food_store_effectively_open(p_store_id uuid, p_at timestamptz default now()) returns boolean
  language sql stable security definer set search_path = '' as
  \$\$ select coalesce((select s.is_open from public.food_stores s where s.id=p_store_id), false) \$\$;
create table public.food_menu_items(id uuid primary key, store_id uuid, category text, name text, is_available boolean default true);
create table public.food_store_reviews(id uuid primary key, store_id uuid, rating integer);
create table public.food_orders(id uuid primary key, store_id uuid, status text);
create table public.food_campaigns(
  id uuid primary key, store_id uuid, name text, campaign_type text, discount_value numeric default 0,
  min_subtotal numeric default 0, starts_at timestamptz default now(), ends_at timestamptz,
  usage_limit integer, usage_count integer default 0, is_active boolean default true, deleted_at timestamptz,
  created_at timestamptz default now()
);
create function public.merchant_has_store_role(p_store_id uuid, p_roles text[] default null) returns boolean language sql stable security definer set search_path = '' as \$\$
  select exists (select 1 from public.food_stores s join public.merchant_memberships m on m.merchant_account_id = s.merchant_account_id
    where s.id = p_store_id and m.user_id = auth.uid() and m.active and (p_roles is null or m.role = any(p_roles))) \$\$;
create function public.food_has_merchant_access(p_store_id uuid) returns boolean language sql stable security definer set search_path = '' as
  \$\$ select public.merchant_has_store_role(p_store_id, null) \$\$;
create function public.food_path_uuid(p_segment text) returns uuid language sql immutable as
  \$\$ select case when p_segment ~ '^[0-9a-f-]{36}\$' then p_segment::uuid end \$\$;
create table storage.objects(bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql immutable as
  \$\$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] \$\$;
alter table storage.objects enable row level security;
grant usage on schema public, auth, internal, storage to authenticated, anon;
grant select, insert on storage.objects to authenticated;

insert into auth.users values ('$ADMIN'), ('$MOD'), ('$OWNER'), ('$RIDER'), ('$BUYER'), ('$BUYER2'), ('$GUEST');
insert into public.profiles(id, platform_role, food_access) values ('$ADMIN','admin',true), ('$MOD','moderator',true),
  ('$OWNER','user',true), ('$RIDER','user',true), ('$BUYER','user',true), ('$BUYER2','user',true), ('$GUEST','user',false);
insert into public.merchant_memberships values ('$ACCOUNT','$OWNER','owner',true), ('$ACCOUNT','$RIDER','delivery',true);
insert into public.food_stores(id, slug, name, merchant_account_id, address, latitude, longitude)
  values ('$STORE','main','ร้านโฆษณา','$ACCOUNT','ถนนหลัก มหาสารคาม',16.185,103.301),
         ('$OTHER','other','ร้านอื่น',null,'ถนนรอง มหาสารคาม',16.190,103.310);
insert into public.food_menu_items(id,store_id,category,name) values
  ('00000000-0000-0000-0000-000000000101','$STORE','อาหารไทย','ข้าวผัด'),
  ('00000000-0000-0000-0000-000000000102','$OTHER','อาหารตามสั่ง','กะเพราไก่');
insert into public.food_store_reviews values ('00000000-0000-0000-0000-000000000201','$STORE',5);
insert into public.food_orders values ('00000000-0000-0000-0000-000000000301','$STORE','delivered');
insert into public.food_campaigns(id,store_id,name,campaign_type,discount_value,min_subtotal)
  values ('00000000-0000-0000-0000-000000000401','$STORE','ลด 30 บาท','fixed',30,150);
SQL
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_ads_v1.sql"
# The apply workflow can be dispatched again; a re-run must keep every audit type.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_ads_v1.sql"
# Home v2 replaces the directory return shape after the existing ad RPC exists.
run >/dev/null 2>&1 < "$ROOT/supabase/migrations_wynos_food_home_directory_v2.sql"

as() { run -At -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1 | tail -n1; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
expect_eq()   { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_db()   { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_fail() { local err; if err="$(run -c "select set_config('test.uid','$1',false);" -c "set role authenticated;" -c "$2" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi
                [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }

SLIP="ads/$STORE/slip1.jpg"

# Ads start switched off; turning them on needs WYNOS's PromptPay; admin only.
expect_fail "$OWNER" "select public.merchant_request_ad_topup('$STORE', 500, '$SLIP')" "no top-ups while ads are off" "ads are not open yet"
expect_fail "$MOD" "select public.admin_update_ad_settings(2, 100, 'WYNOS', '0812345678', true)" "moderator cannot change ad settings" "Only admins can manage ads"
expect_fail "$ADMIN" "select public.admin_update_ad_settings(2, 100, null, null, true)" "PromptPay is required to turn ads on" "set the WYNOS PromptPay before turning ads on"
expect_eq "$ADMIN" "select public.admin_update_ad_settings(2, 100, 'WYNOS', '0812345678', true)::text" "" "admin turns ads on at 2 baht per click"
expect_db "select count(*) from public.audit_log where event_type = 'admin_ad_settings_updated'" "1" "settings change is audited"
expect_db "insert into public.audit_log(event_type) values ('admin_user_unbanned') returning 1" "1" "existing audit types still allowed"

# Slip storage: store managers upload under ads/<their store>/ only.
expect_eq "$OWNER" "insert into storage.objects(bucket_id, name) values ('food-private', '$SLIP') returning 1" "1" "owner uploads a slip for the store"
expect_fail "$RIDER" "insert into storage.objects(bucket_id, name) values ('food-private', 'ads/$STORE/slip2.jpg')" "delivery staff cannot upload ad slips" "row-level security"
expect_fail "$OWNER" "insert into storage.objects(bucket_id, name) values ('food-private', 'ads/$OTHER/slip.jpg')" "no uploads for another store" "row-level security"

# Top-up requests.
expect_fail "$RIDER" "select public.merchant_request_ad_topup('$STORE', 500, '$SLIP')" "delivery staff cannot top up" "merchant manager access required"
expect_fail "$OWNER" "select public.merchant_request_ad_topup('$STORE', 50, '$SLIP')" "below the minimum" "top-up is below the minimum"
expect_fail "$OWNER" "select public.merchant_request_ad_topup('$STORE', 500, 'ads/$OTHER/slip.jpg')" "slip must be this store's" "slip must be uploaded for this store"
TID="$(as "$OWNER" "select public.merchant_request_ad_topup('$STORE', 500, '$SLIP')")"
[[ "$TID" =~ ^[0-9a-f-]{36}$ ]] || { echo "FAIL: owner requests a top-up (got '$TID')"; exit 1; }
expect_eq "$OWNER" "select (public.merchant_ad_account('$STORE')->>'balance') || '|' || (public.merchant_ad_account('$STORE')->>'live')" "0.00|false" "no credit before approval"

# Admin review.
expect_fail "$MOD" "select public.admin_review_ad_topup('$TID', true)" "moderator cannot approve" "Only admins can review ad top-ups"
expect_fail "$ADMIN" "select public.admin_review_ad_topup('$TID', false)" "rejecting needs a reason" "a reason is required to reject"
expect_eq "$ADMIN" "select public.admin_review_ad_topup('$TID', true)::text" "" "admin approves"
expect_fail "$ADMIN" "select public.admin_review_ad_topup('$TID', true)" "a top-up is credited once" "top-up already reviewed"
expect_eq "$OWNER" "select (public.merchant_ad_account('$STORE')->>'balance') || '|' || (public.merchant_ad_account('$STORE')->>'live')" "500.00|true" "credit added and the ad is live"
expect_db "select count(*) from public.notifications where recipient_id = '$OWNER'" "1" "the owner is notified"

# Food directory puts the live ad first; access gate applies.
expect_eq "$BUYER" "select name || '|' || is_ad from public.food_store_directory() limit 1" "ร้านโฆษณา|true" "the advertised store is first"
expect_eq "$BUYER" "select count(*) from public.food_store_directory('อื่น')" "1" "search by name"
expect_eq "$BUYER" "select count(*) from public.food_store_directory('กะเพรา')" "1" "search by menu name"
expect_eq "$BUYER" "select categories[1] || '|' || rating_average || '|' || rating_count || '|' || delivered_order_count || '|' || promo_type from public.food_store_directory() where id='$STORE'" "อาหารไทย|5.0|1|1|fixed" "home metadata is returned"
expect_eq "$BUYER" "select address from public.food_store_directory() where id='$STORE'" "ถนนหลัก มหาสารคาม" "store address is returned"
expect_fail "$GUEST" "select * from public.food_store_directory()" "Food access gate applies" "food access required"

# Clicks: charged once per customer per day, never for the store's own team.
expect_eq "$BUYER" "select public.food_ad_click('$STORE', 'home')" "charged" "a customer click is charged"
expect_eq "$BUYER" "select public.food_ad_click('$STORE', 'search')" "repeat" "the same customer is not charged twice a day"
expect_eq "$RIDER" "select public.food_ad_click('$STORE', 'home')" "own_store" "the store's team is never charged"
expect_eq "$BUYER2" "select public.food_ad_click('$STORE', 'search')" "charged" "another customer is charged"
expect_db "select balance || '|' || total_spent from public.food_ad_accounts where store_id = '$STORE'" "496.00|4.00" "two clicks cost 4 baht"
expect_fail "$BUYER" "select public.food_ad_click('$STORE', 'banner')" "unknown placement" "invalid placement"

# Store pause and Admin stop.
expect_eq "$OWNER" "select public.merchant_set_ad_active('$STORE', false)::text" "" "store pauses its ads"
expect_eq "$BUYER" "select is_ad::text from public.food_store_directory() where name = 'ร้านโฆษณา'" "false" "a paused ad is not shown as an ad"
expect_eq "$OWNER" "select public.merchant_set_ad_active('$STORE', true)::text" "" "store resumes"
expect_fail "$ADMIN" "select public.admin_set_ad_account_status('$STORE', true)" "stopping needs a reason" "a reason is required to stop ads"
expect_eq "$ADMIN" "select public.admin_set_ad_account_status('$STORE', true, 'โฆษณาไม่ตรงกับร้าน')::text" "" "admin stops the ads"
expect_fail "$OWNER" "select public.merchant_set_ad_active('$STORE', true)" "store cannot restart stopped ads" "ads stopped by WYNOS"
expect_eq "$BUYER2" "select public.food_ad_click('$STORE', 'home')" "not_live" "stopped ads are not charged"

# Balance never goes below one click; direct table access is closed.
run -q -c "update public.food_ad_accounts set status = 'active', stop_reason = null, balance = 1 where store_id = '$STORE';" >/dev/null
expect_eq "$GUEST" "select 1" "1" "guest session works"
expect_eq "$BUYER" "select is_ad::text from public.food_store_directory() where name = 'ร้านโฆษณา'" "false" "not enough credit for a click means no ad"
expect_fail "$OWNER" "update public.food_ad_accounts set balance = 99999" "stores cannot edit their balance" "permission denied"
expect_fail "$BUYER" "select * from public.food_ad_clicks" "click log is private" "permission denied"
expect_db "select has_function_privilege('anon', 'public.food_ad_click(uuid,text)', 'execute')::text || has_function_privilege('anon', 'public.admin_review_ad_topup(uuid,boolean,text)', 'execute')::text" "falsefalse" "anon cannot call the RPCs"

echo "PASS: WYNOS Food ads are Admin-controlled, credited once, charged once per customer per day"
