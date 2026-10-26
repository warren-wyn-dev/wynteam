#!/usr/bin/env bash
# ZOKY-FULFILL-001: pickup at store, COD, store-decided cancellation/refunds.
# Loads stub tables shaped like production, the live production functions the
# migration builds on (fixtures/), then the migration, and exercises it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
DB="zoky_fulfill_001_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
db() { run -At -c "$1" 2>&1 | tail -n1; }
as() { db "set test.uid='$1'; $2"; }
expect() { local got; got="$(db "$1")"; [[ "$got" == "$2" ]] || { echo "FAIL: $3 (got '$got', want '$2')"; exit 1; }; }
expect_as() { local got; got="$(as "$1" "$2")"; [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }; }
expect_fail_db() { local err; if err="$(run -c "$1" 2>&1)"; then echo "FAIL (expected error): $3"; exit 1; fi; [[ "$err" == *"$2"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }; }
expect_fail_as() { local err; if err="$(run -c "set test.uid='$1'; $2" 2>&1)"; then echo "FAIL (expected error): $4"; exit 1; fi; [[ "$err" == *"$3"* ]] || { echo "FAIL: $4 (wrong error: $err)"; exit 1; }; }

STORE=00000000-0000-0000-0000-0000000000a1
STORE2=00000000-0000-0000-0000-0000000000a2
ITEM=00000000-0000-0000-0000-0000000000b1
ITEM2=00000000-0000-0000-0000-0000000000b2
OWNER=00000000-0000-0000-0000-0000000000c1
STAFF=00000000-0000-0000-0000-0000000000c2
BUYER=00000000-0000-0000-0000-0000000000d1
BUYER2=00000000-0000-0000-0000-0000000000d2
OTHER=00000000-0000-0000-0000-0000000000e1

run >/dev/null <<'SQL'
create extension if not exists pgcrypto;
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role; exception when duplicate_object then null; end $$;
create schema auth; create schema internal; create schema storage;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
create function auth.role() returns text language sql stable as $$ select 'authenticated'::text $$;
create table storage.objects(bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql immutable as
  $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
SQL
run -f "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_stub_schema.sql" >/dev/null

run >/dev/null <<'SQL'
create table public.food_menu_items(id uuid primary key, store_id uuid, name text, price numeric, options jsonb default '[]', is_available boolean default true);
create table public.food_order_items(order_id uuid, menu_item_id uuid, item_name text, unit_price numeric, quantity int, selected_options jsonb, item_note text);
create table public.food_campaigns(id uuid primary key, platform_campaign_id uuid, usage_count int default 0);
create table public.food_order_campaigns(order_id uuid, campaign_id uuid, campaign_name text, campaign_type text, campaign_discount numeric, delivery_discount numeric);
create table public.food_coupon_codes(id uuid, code text, is_active boolean, starts_at timestamptz, ends_at timestamptz, platform_campaign_id uuid, max_total_uses int, max_uses_per_user int);
create table public.food_coupon_redemptions(order_id uuid, coupon_id uuid, user_id uuid);
create table public.notifications(recipient_id uuid, actor_id uuid, type text, reason text);
create table public.merchant_notifications(merchant_account_id uuid, recipient_user_id uuid, type text, reason text);
create table public.merchant_memberships(merchant_account_id uuid, user_id uuid, active boolean);
create table public.food_staff(store_id uuid, user_id uuid, active boolean, role text);
create table public.food_delivery_proofs(order_id uuid primary key, method text, location_note text, image_path text, delivered_by uuid, created_at timestamptz default now());
create table public.developer_accounts(user_id uuid);
create table public.test_roles(store_id uuid, user_id uuid, role text);

create function public.food_customer_access_enabled() returns boolean language sql as $$ select true $$;
create function public.food_public_access_enabled() returns boolean language sql as $$ select true $$;
create function public.is_developer_account() returns boolean language sql as $$ select false $$;
create function public.food_is_permanent_account() returns boolean language sql as $$ select true $$;
create function public.merchant_has_store_role(p_store uuid, p_roles text[]) returns boolean language sql stable as
  $$ select exists(select 1 from public.test_roles r where r.store_id = p_store and r.user_id = auth.uid() and r.role = any(p_roles)) $$;
create function public.food_has_merchant_access(p_store uuid) returns boolean language sql stable as
  $$ select exists(select 1 from public.test_roles r where r.store_id = p_store and r.user_id = auth.uid()) $$;
create function public.food_path_uuid(p text) returns uuid language sql immutable as
  $$ select case when p ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then p::uuid end $$;
create function internal.food_in_service_area(double precision, double precision) returns boolean language sql as $$ select true $$;
create function internal.food_resolve_menu_options(p_options jsonb, p_selected jsonb) returns table(options jsonb, surcharge numeric) language sql as $$ select '[]'::jsonb, 0::numeric $$;
create function internal.food_campaign_candidates(uuid, numeric, numeric, jsonb)
  returns table(campaign_id uuid, campaign_name text, campaign_type text, campaign_discount numeric, delivery_discount numeric)
  language sql as $$ select null::uuid, null::text, null::text, 0::numeric, 0::numeric where false $$;
create function internal.food_coupon_usage_active(uuid) returns boolean language sql as $$ select true $$;
create function internal.merchant_gp_rate_at(uuid, timestamptz) returns table(rate_bp int, rate_id uuid) language sql as $$ select 1000, null::uuid $$;
create function internal.notification_enabled(uuid, text) returns boolean language sql as $$ select true $$;
-- Original (pre-migration) shapes of the functions the migration redefines.
create function internal.food_orders_gp_snapshot() returns trigger language plpgsql as $$ begin new.gp_rate_bp := 1000; return new; end $$;
create function internal.food_order_status_notify() returns trigger language plpgsql as $$ begin return new; end $$;
create function public.food_transition_order(uuid, text, integer default null, text default null) returns void language plpgsql as $$ begin end $$;
SQL
run -f "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_prod_baseline.sql" >/dev/null

run >/dev/null <<'SQL'
create trigger food_orders_gp_snapshot before insert or update of gp_rate_bp, gp_rate_id, gp_rule_version on public.food_orders for each row execute function internal.food_orders_gp_snapshot();
create trigger food_orders_guard_store_schedule before insert on public.food_orders for each row execute function internal.food_order_guard_store_schedule();
create trigger food_orders_notify_merchant_payment after insert or update of payment_status on public.food_orders for each row execute function internal.food_order_notify();
create trigger food_orders_status_notify after update of status on public.food_orders for each row execute function internal.food_order_status_notify();
SQL

# The migration under test, applied twice (must be idempotent).
run -f "$ROOT/supabase/migrations/20261026120000_zoky_fulfill_001.sql" >/dev/null
run -f "$ROOT/supabase/migrations/20261026120000_zoky_fulfill_001.sql" >/dev/null

# Fixtures: a store open every day 00:00-23:59 (Bangkok) and one without a schedule.
run >/dev/null <<SQL
insert into public.food_stores(id, slug, share_code, name, is_open, is_published, latitude, longitude, delivery_fee, business_schedule)
values ('$STORE', 's1', 'abcdef', 'ร้านทดสอบ', true, true, 16.18, 103.30, 20,
  jsonb_build_object('weekly', (select jsonb_object_agg(d, jsonb_build_object('enabled', true, 'open', '00:00', 'close', '23:59'))
                                from unnest(array['mon','tue','wed','thu','fri','sat','sun']) d))),
       ('$STORE2', 's2', 'abcdeg', 'ร้านไม่มีตาราง', true, true, 16.18, 103.30, 20, '{}');
insert into public.food_menu_items(id, store_id, name, price) values ('$ITEM', '$STORE', 'ข้าวผัด', 50), ('$ITEM2', '$STORE2', 'ก๋วยเตี๋ยว', 40);
insert into public.test_roles values ('$STORE', '$OWNER', 'owner'), ('$STORE', '$STAFF', 'orders'), ('$STORE2', '$OWNER', 'owner');
SQL
ITEMS="'[{\"menu_item_id\":\"$ITEM\",\"quantity\":2}]'::jsonb"

# --- defaults: existing behaviour unchanged ---------------------------------
expect "select pickup_enabled::text||delivery_enabled::text||cod_enabled::text||pickup_prep_minutes from public.food_stores where id='$STORE'" "falsetruefalse15" "store defaults"
O1=$(as "$BUYER" "select public.food_create_order_v2('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null)")
expect "select fulfillment_type||payment_method||(payment_due_at is not null)::text||delivery_fee::int from public.food_orders where id='$O1'" "deliverytransfertrue20" "v2 order stays delivery+transfer"

# --- store settings ----------------------------------------------------------
expect_fail_as "$STAFF" "select public.food_store_set_fulfillment('$STORE', true, true, true, 15)" "store settings role required" "orders role cannot change settings"
expect_fail_as "$OWNER" "select public.food_store_set_fulfillment('$STORE', false, false, false, 15)" "at_least_one_mode" "one mode required"
expect_fail_as "$OWNER" "select public.food_store_set_fulfillment('$STORE2', true, true, false, 15)" "pickup_requires_schedule" "pickup needs schedule"
expect_fail_as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, false, true, 15)" "cod_delivery_only" "COD needs delivery"
expect_fail_as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, true, false, 2)" "invalid_prep_minutes" "prep minutes range"
expect_fail_as "$OTHER" "select public.food_store_set_fulfillment('$STORE', true, true, true, 15)" "store settings role required" "stranger cannot change settings"
as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, true, true, 20)" >/dev/null
expect_fail_as "$OWNER" "update public.food_stores set cod_enabled=false where id='$STORE'" "use food_store_set_fulfillment" "settings change only through the RPC"
expect_fail_as "$STAFF" "update public.food_stores set pickup_prep_minutes=30 where id='$STORE'" "use food_store_set_fulfillment" "staff cannot bypass the RPC"
as "$OWNER" "update public.food_stores set name='ร้านทดสอบ' where id='$STORE'" >/dev/null
expect "select name||cod_enabled::text from public.food_stores where id='$STORE'" "ร้านทดสอบtrue" "other store fields still update directly"

# --- pickup slots ------------------------------------------------------------
SLOT=$(db "select s from internal.food_pickup_slots('$STORE', now()) s order by s limit 1")
[[ -n "$SLOT" ]] || { echo "FAIL: no pickup slot"; exit 1; }
expect "select (min(s) >= now() + interval '20 minutes')::text || (extract(minute from min(s))::int % 15)::text || bool_and((s at time zone 'Asia/Bangkok')::date = (now() at time zone 'Asia/Bangkok')::date)::text from internal.food_pickup_slots('$STORE', now()) s" "true0true" "slots after prep, on 15-min marks, today only"
expect "select count(*) from internal.food_pickup_slots('$STORE2', now())" "0" "no slots without pickup"
db "update public.food_stores set is_published=false where id='$STORE'" >/dev/null
expect "select count(*) from internal.food_pickup_slots('$STORE', now())" "0" "no slots for an unpublished store"
db "update public.food_stores set is_published=true, temporary_closed_until=now() + interval '2 hours' where id='$STORE'" >/dev/null
expect "select count(*) from internal.food_pickup_slots('$STORE', now())" "0" "no slots while the store is closed now"
db "update public.food_stores set temporary_closed_until=null where id='$STORE'" >/dev/null

# --- quote v3 ---------------------------------------------------------------
expect_as "$BUYER" "select (q->>'delivery_fee')::numeric::int || (q->>'fulfillment_type') || (jsonb_array_length(q->'pickup_slots') > 0)::text from (select public.food_quote_order_v3('$STORE',$ITEMS,null,null,null,'pickup') q) x" "0pickuptrue" "pickup quote has no fee and offers slots"
expect_as "$BUYER" "select (q->>'delivery_fee')::numeric::int || (q->>'cod_available') from (select public.food_quote_order_v3('$STORE',$ITEMS,16.181,103.301,null,'delivery') q) x" "20true" "delivery quote keeps fee, COD offered"
expect_fail_as "$BUYER" "select public.food_quote_order_v3('$STORE2',$ITEMS,null,null,null,'pickup')" "pickup_not_available" "pickup quote refused when off"

# --- pickup create -----------------------------------------------------------
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup', now() + interval '3 minutes','transfer')" "invalid_pickup_time" "pickup before prep time refused"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup', '$SLOT'::timestamptz + interval '1 day','transfer')" "invalid_pickup_time" "pickup tomorrow refused"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup', '$SLOT'::timestamptz + interval '7 minutes','transfer')" "invalid_pickup_time" "off-slot pickup time refused"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup', '$SLOT','cod')" "cod_delivery_only" "COD refused for pickup"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE2','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup', '$SLOT','transfer')" "pickup_not_available" "pickup refused when store has it off"
P1=$(as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
expect "select fulfillment_type||'|'||pickup_code||'|'||delivery_fee::int||'|'||shipping_address||'|'||(pickup_at='$SLOT'::timestamptz)::text||'|'||(delivery_latitude is null)::text||'|'||total::int from public.food_orders where id='$P1'" "pickup|P001|0|รับเองที่ร้าน|true|true|100" "pickup order fields"
P2=$(as "$BUYER2" "select public.food_create_order_v3('$STORE','ลูกค้า2','0800000001','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
expect "select pickup_code from public.food_orders where id='$P2'" "P002" "pickup codes are sequential per store/day"
expect_fail_db "update public.food_orders set pickup_code='P001' where id='$P2'" "food_orders_pickup_code_day_key" "pickup codes unique per store/day"

# --- pickup flow ------------------------------------------------------------
expect_fail_as "$STAFF" "select public.food_transition_order('$P1','preparing')" "payment must be verified first" "unpaid pickup cannot be accepted"
db "update public.food_orders set payment_status='paid' where id in ('$P1','$P2')" >/dev/null
as "$STAFF" "select public.food_transition_order('$P1','preparing')" >/dev/null
expect_fail_as "$STAFF" "select public.food_complete_pickup('$P1')" "invalid order transition" "cannot collect before ready"
as "$STAFF" "select public.food_transition_order('$P1','ready_for_delivery')" >/dev/null
expect "select count(*) from public.notifications where recipient_id='$BUYER' and reason like '%พร้อมให้รับที่ร้านแล้ว%P001%'" "1" "customer told the pickup is ready, with code"
expect_fail_as "$STAFF" "select public.food_transition_order('$P1','out_for_delivery')" "invalid order transition" "pickup never goes out for delivery"
expect_fail_as "$OTHER" "select public.food_complete_pickup('$P1')" "order management role required" "stranger cannot complete pickup"
expect_fail_as "$STAFF" "select public.food_complete_pickup('$O1')" "not a pickup order" "complete_pickup refuses delivery orders"
as "$STAFF" "select public.food_complete_pickup('$P1')" >/dev/null
expect "select status||(picked_up_at is not null)::text||(delivered_at is not null)::text from public.food_orders where id='$P1'" "deliveredtruetrue" "picked up = delivered + picked_up_at"

# --- cancel request (store decides refund) ---------------------------------
as "$STAFF" "select public.food_transition_order('$P2','preparing')" >/dev/null
expect_fail_as "$BUYER2" "select public.food_cancel_order('$P2','เปลี่ยนใจ')" "order cannot be cancelled by customer" "accepted order cannot be cancelled directly"
expect_fail_as "$BUYER" "select public.food_request_cancel('$P2','ไม่ใช่ของฉัน')" "order not found" "another customer cannot request cancel"
expect_fail_as "$BUYER" "select public.food_request_cancel('$O1','x')" "cancel request is for pickup orders" "request cancel is pickup-only"
as "$BUYER2" "select public.food_request_cancel('$P2','ไม่ว่างไปรับ')" >/dev/null
expect_fail_as "$BUYER2" "select public.food_request_cancel('$P2','อีกที')" "cancel already requested" "one open request"
expect_fail_as "$BUYER2" "select public.food_resolve_cancel_request('$P2', true, true, null)" "order management role required" "customer cannot resolve own request"
as "$STAFF" "select public.food_resolve_cancel_request('$P2', false, false, 'ทำเสร็จแล้ว')" >/dev/null
expect "select status||coalesce(cancel_requested_at::text,'null') from public.food_orders where id='$P2'" "preparingnull" "rejected request keeps order"
expect_fail_as "$BUYER2" "select public.food_request_cancel('$P2','ขออีกครั้ง')" "cancel request not available" "one request per order after a rejection"

P4=$(as "$BUYER2" "select public.food_create_order_v3('$STORE','ลูกค้า2','0800000001','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
db "update public.food_orders set payment_status='submitted' where id='$P4'" >/dev/null
expect_fail_as "$BUYER2" "select public.food_request_cancel('$P4','x')" "cancel request not available" "no cancel request while the slip is unchecked"
db "update public.food_orders set payment_status='paid' where id='$P4'" >/dev/null
as "$STAFF" "select public.food_transition_order('$P4','preparing')" >/dev/null
as "$BUYER2" "select public.food_request_cancel('$P4','ไม่ว่างไปรับ')" >/dev/null
as "$STAFF" "select public.food_resolve_cancel_request('$P4', true, false, 'อาหารทำแล้ว')" >/dev/null
expect "select status||'|'||refund_status||'|'||coalesce(refund_requested_at::text,'null') from public.food_orders where id='$P4'" "cancelled|none|null" "approved without refund"
expect "select count(*) from public.notifications where recipient_id='$BUYER2' and reason like '%ร้านไม่คืนเงิน%'" "1" "customer told there is no refund"

P5=$(as "$OTHER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
db "update public.food_orders set payment_status='paid' where id='$P5'" >/dev/null
as "$STAFF" "select public.food_transition_order('$P5','preparing')" >/dev/null
as "$STAFF" "select public.food_transition_order('$P5','ready_for_delivery')" >/dev/null
as "$OTHER" "select public.food_request_cancel('$P5','มาไม่ทัน')" >/dev/null
as "$STAFF" "select public.food_complete_pickup('$P5')" >/dev/null
expect "select status||coalesce(cancel_requested_at::text,'null') from public.food_orders where id='$P5'" "deliverednull" "collecting the order closes an open cancel request"

P3=$(as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
db "update public.food_orders set payment_status='paid' where id='$P3'" >/dev/null
as "$BUYER" "select public.food_request_cancel('$P3','ขอยกเลิก')" >/dev/null
as "$STAFF" "select public.food_resolve_cancel_request('$P3', true, true, null)" >/dev/null
expect "select status||'|'||refund_status from public.food_orders where id='$P3'" "cancelled|pending" "approved with refund owes a refund"

# --- store refund with slip --------------------------------------------------
expect_fail_as "$OWNER" "select public.food_store_mark_refunded('$P3','refunds/$P3/slip.jpg',null)" "refund slip is required" "refund slip must exist"
db "insert into storage.objects values ('food-private','refunds/$P3/slip.jpg'), ('food-private','refunds/$P1/x.jpg')" >/dev/null
expect_fail_as "$OWNER" "select public.food_store_mark_refunded('$P3','refunds/$P1/x.jpg',null)" "refund slip is required" "slip must belong to this order"
expect_fail_as "$STAFF" "select public.food_store_mark_refunded('$P3','refunds/$P3/slip.jpg',null)" "refund role required" "orders role cannot mark refunds"
as "$OWNER" "select public.food_store_mark_refunded('$P3','refunds/$P3/slip.jpg','โอนคืนแล้ว')" >/dev/null
expect "select refund_status||'|'||payment_status||'|'||refund_slip_path||'|'||(refunded_by_store_at is not null)::text from public.food_orders where id='$P3'" "refunded|refunded|refunds/$P3/slip.jpg|true" "store refund recorded"
expect_fail_as "$OWNER" "select public.food_store_mark_refunded('$P3','refunds/$P3/slip.jpg',null)" "no refund pending" "refund recorded once"

# --- delivery turned off: no client can still order delivery ------------------
as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, false, false, 20)" >/dev/null
expect_fail_as "$BUYER" "select public.food_create_order_v2('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null)" "delivery_not_available" "v2 client cannot order delivery when it is off"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'delivery',null,'transfer')" "delivery_not_available" "v3 delivery refused when off"
P6=$(as "$OTHER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','','',$ITEMS,null,null,null,'pickup','$SLOT','transfer')")
expect "select fulfillment_type from public.food_orders where id='$P6'" "pickup" "pickup still works with delivery off"

# --- COD ---------------------------------------------------------------------
as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, true, false, 20)" >/dev/null
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'delivery',null,'cod')" "cod_not_available" "COD refused when store has it off"
as "$OWNER" "select public.food_store_set_fulfillment('$STORE', true, true, true, 20)" >/dev/null
C1=$(as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'delivery',null,'cod')")
expect "select payment_method||'|'||(payment_due_at is null)::text||'|'||gp_rate_bp||'|'||delivery_fee::int from public.food_orders where id='$C1'" "cod|true|0|20" "COD: no deadline, no GP, fee kept"
expect "select gp_rate_bp from public.food_orders where id='$O1'" "1000" "transfer orders keep GP"
expect_fail_as "$BUYER" "select public.food_submit_payment('$C1','$BUYER/slips/$C1/s.jpg')" "cod order takes no slip" "COD takes no slip"
as "$STAFF" "select public.food_transition_order('$C1','preparing')" >/dev/null
expect "select status||payment_status from public.food_orders where id='$C1'" "preparingpending" "COD accepted before payment"
as "$STAFF" "select public.food_transition_order('$C1','ready_for_delivery')" >/dev/null
as "$STAFF" "select public.food_transition_order('$C1','out_for_delivery')" >/dev/null
db "insert into storage.objects values ('food-private','delivery/$C1/p.jpg')" >/dev/null
as "$STAFF" "select public.food_complete_delivery('$C1','direct',null,'delivery/$C1/p.jpg')" >/dev/null
expect "select status||'|'||payment_status||'|'||payment_provider||'|'||(paid_at is not null)::text from public.food_orders where id='$C1'" "delivered|paid|cash|true" "COD paid on delivery"
expect "select count(*) from public.food_order_events where order_id='$C1' and event_type='cod_collected'" "1" "COD cash event"
T1=$(as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'delivery',null,'transfer')")
expect_fail_as "$STAFF" "select public.food_transition_order('$T1','preparing')" "payment must be verified first" "unpaid transfer order still cannot be accepted"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'delivery',now() + interval '1 hour','transfer')" "invalid_pickup_time" "delivery takes no pickup time"
expect_fail_as "$BUYER" "select public.food_create_order_v3('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null,'drone',null,'transfer')" "invalid fulfillment type" "unknown fulfillment refused"

# --- paid delivery cancel by store keeps the refund ---------------------------
db "update public.food_orders set payment_status='paid' where id='$T1'" >/dev/null
as "$STAFF" "select public.food_transition_order('$T1','cancelled')" >/dev/null
expect "select refund_status from public.food_orders where id='$T1'" "pending" "store cancel of a paid order still owes a refund"

# --- table constraints --------------------------------------------------------
expect_fail_as "$OWNER" "update public.food_orders set payment_method='cod' where id='$P1'" "violates check constraint" "pickup+COD blocked by constraint"
expect_fail_db "update public.food_stores set pickup_enabled=false, delivery_enabled=false where id='$STORE'" "food_stores_fulfillment_mode_check" "store must keep a mode"

# --- rollback ------------------------------------------------------------------
if err="$(run -f "$ROOT/supabase/rollbacks/20261026120000_zoky_fulfill_001_rollback.sql" 2>&1)"; then echo "FAIL: rollback ran with pickup/COD orders"; exit 1; fi
[[ "$err" == *"rollback would lose it"* ]] || { echo "FAIL: rollback guard ($err)"; exit 1; }
db "delete from public.food_orders where fulfillment_type <> 'delivery' or payment_method <> 'transfer' or cancel_requested_at is not null or refund_slip_path is not null" >/dev/null
if err="$(run -f "$ROOT/supabase/rollbacks/20261026120000_zoky_fulfill_001_rollback.sql" 2>&1)"; then echo "FAIL: rollback ran with feature events"; exit 1; fi
[[ "$err" == *"order events exist"* ]] || { echo "FAIL: rollback event guard ($err)"; exit 1; }
db "delete from public.food_order_events where event_type in ('cancel_requested','cancel_request_rejected','pickup_scheduled','cod_selected')" >/dev/null
run -f "$ROOT/supabase/rollbacks/20261026120000_zoky_fulfill_001_rollback.sql" >/dev/null
expect "select count(*) from information_schema.columns where table_name in ('food_orders','food_stores') and column_name in ('fulfillment_type','payment_method','pickup_enabled','cod_enabled')" "0" "rollback drops new columns"
expect "select count(*) from pg_proc where proname in ('food_create_order_v3','food_complete_pickup','food_store_mark_refunded','food_orders_fulfillment_guard','food_stores_fulfillment_settings_guard')" "0" "rollback drops new functions"
expect "select count(*) from pg_trigger where tgname in ('food_orders_fulfillment_guard','food_stores_fulfillment_settings_guard')" "0" "rollback drops new triggers"
O9=$(as "$BUYER" "select public.food_create_order_v2('$STORE','ลูกค้า','0800000000','บ้าน','',$ITEMS,16.181,103.301,null)")
expect "select delivery_fee::int||status from public.food_orders where id='$O9'" "20pending_acceptance" "v2 orders still work after rollback"

echo "PASS zoky_fulfill_001"
