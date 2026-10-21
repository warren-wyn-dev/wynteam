#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"; DB="food_finance_operations_test_$$"
$PSQL -X -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB"
trap '$PSQL -X -q -d postgres -c "drop database if exists $DB"' EXIT
run() { $PSQL -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run <<'SQL'
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
create function public.food_customer_access_enabled() returns boolean language sql stable as $$select auth.uid() is not null$$;
create table public.profiles(id uuid primary key);
create table internal.test_admins(id uuid primary key);
create function internal.has_admin_permission(text,text) returns boolean language sql stable as $$select exists(select 1 from internal.test_admins where id=auth.uid())$$;
create table public.food_stores(id uuid primary key,name text,merchant_account_id uuid);
create table public.merchant_memberships(merchant_account_id uuid,user_id uuid,active boolean,role text);
create table public.food_orders(id uuid primary key,store_id uuid,order_number text,status text,payment_status text,payment_provider text,subtotal numeric,delivery_fee numeric,total numeric,gp_rate_bp integer,paid_at timestamptz,created_at timestamptz default now(),stripe_refund_id text,refunded_at timestamptz,refund_status text default 'none');
create table public.food_order_items(id uuid primary key,order_id uuid,item_name text,unit_price numeric,quantity integer);
alter table public.food_orders add column buyer_id uuid;
alter table public.food_orders add column cancelled_at timestamptz;
alter table public.food_orders add column stripe_checkout_session_id text;
create table public.food_order_events(order_id uuid,event_type text,from_status text,to_status text,note text,actor_id uuid);
create table public.food_order_campaigns(order_id uuid,campaign_discount numeric);
alter table public.food_order_campaigns add column platform_funded numeric default 0;
alter table public.food_order_campaigns add column released_at timestamptz;
alter table public.food_order_campaigns add column platform_campaign_id uuid;
alter table public.food_order_campaigns add column settlement_id uuid;
alter table public.food_orders add column updated_at timestamptz default now();
create table public.food_staff(store_id uuid,user_id uuid,active boolean,role text);
create table public.food_ad_clicks(store_id uuid,click_day date,cost numeric);
create function internal.food_platform_owed_rows(uuid) returns table(order_id uuid,platform_campaign_id uuid,amount numeric) language sql as $$select null::uuid,null::uuid,0::numeric where false$$;
create table public.food_stripe_payments(order_id uuid primary key,payment_intent_id text,stripe_account_id text,livemode boolean,application_fee_satang bigint,amount_satang bigint,status text,application_fee_refunded_satang bigint default 0,application_fee_refunded_at timestamptz);
create table internal.food_auto_refunds(order_id uuid,state text);
create table internal.food_auto_refund_settings(singleton boolean,enabled boolean,store_ids uuid[]);
create table public.food_stripe_accounts(store_id uuid primary key,stripe_account_id text,livemode boolean);
create table public.food_stripe_payouts(payout_id text primary key,status text);
create table public.merchant_gp_rates(id uuid primary key default gen_random_uuid(),store_id uuid,rate_bp integer,effective_from timestamptz,reason text,created_by uuid,idempotency_key uuid unique,request_fingerprint text);
insert into public.profiles values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
insert into internal.test_admins values('00000000-0000-0000-0000-000000000002'),('00000000-0000-0000-0000-000000000003');
insert into public.food_stores values('00000000-0000-0000-0000-000000000010','QA synthetic','00000000-0000-0000-0000-000000000020');
insert into public.merchant_memberships values('00000000-0000-0000-0000-000000000020','00000000-0000-0000-0000-000000000001',true,'owner');
insert into public.food_orders(id,store_id,order_number,status,payment_status,payment_provider,subtotal,delivery_fee,total,gp_rate_bp,paid_at)
values('00000000-0000-0000-0000-000000000030','00000000-0000-0000-0000-000000000010','TEST','preparing','paid','stripe',99.99,20,109.99,1000,now());
insert into public.food_order_items values('00000000-0000-0000-0000-000000000040','00000000-0000-0000-0000-000000000030','item',33.33,3);
insert into public.food_order_campaigns(order_id,campaign_discount) values('00000000-0000-0000-0000-000000000030',10);
insert into public.food_stripe_payments(order_id,payment_intent_id,stripe_account_id,livemode,application_fee_satang,amount_satang,status)
values('00000000-0000-0000-0000-000000000030','pi_test','acct_test',false,900,10999,'paid');
SQL
run --single-transaction -f "$ROOT/supabase/migrations/20261021105659_food_finance_operations.sql"
run --single-transaction -f "$ROOT/supabase/migrations/20261021133000_food_finance_promotion_refunds.sql"
run <<'SQL'
select set_config('test.uid','00000000-0000-0000-0000-000000000001',false);
do $$declare a uuid; b uuid; c uuid; v jsonb; denied boolean:=false; begin
a:=public.merchant_request_item_refund('00000000-0000-0000-0000-000000000030','[{"item_id":"00000000-0000-0000-0000-000000000040","quantity":1}]','missing item','00000000-0000-0000-0000-000000000050');
if a<>public.merchant_request_item_refund('00000000-0000-0000-0000-000000000030','[{"item_id":"00000000-0000-0000-0000-000000000040","quantity":1}]','missing item','00000000-0000-0000-0000-000000000050') then raise exception 'idempotency failed'; end if;
b:=public.merchant_request_item_refund('00000000-0000-0000-0000-000000000030','[{"item_id":"00000000-0000-0000-0000-000000000040","quantity":1}]','missing item','00000000-0000-0000-0000-000000000051');
c:=public.merchant_request_item_refund('00000000-0000-0000-0000-000000000030','[{"item_id":"00000000-0000-0000-0000-000000000040","quantity":1}]','missing item','00000000-0000-0000-0000-000000000052');
if (select sum(food_satang) from internal.food_finance_refunds)<>8999 then raise exception 'cumulative discounted allocation incorrect'; end if;
if (select sum(gp_satang) from internal.food_finance_refunds)<>900 then raise exception 'GP allocation incorrect'; end if;
begin perform public.merchant_request_item_refund('00000000-0000-0000-0000-000000000030','[{"item_id":"00000000-0000-0000-0000-000000000040","quantity":1}]','missing item',gen_random_uuid()); exception when raise_exception then denied:=true; end;
if not denied then raise exception 'over refund allowed'; end if;
v:=public.merchant_finance_order_lines('00000000-0000-0000-0000-000000000010',current_date,current_date);
if v->'orders'->0->>'processor_fee_satang' is not null or v->'orders'->0->>'net_satang' is not null then raise exception 'unknown fee treated as zero'; end if;
end $$;
select public.food_record_payment_facts('00000000-0000-0000-0000-000000000030','ch_test','txn_test',500,10999,0,0,900,current_date,'available');
do $$declare v jsonb; begin
v:=public.merchant_finance_order_lines('00000000-0000-0000-0000-000000000010',current_date,current_date);
if (v->'orders'->0->>'net_satang')::bigint<>9599 then raise exception 'actual fee net incorrect'; end if;
end $$;
select set_config('test.uid','00000000-0000-0000-0000-000000000099',false);
do $$declare denied boolean:=false; begin
begin perform public.merchant_finance_order_lines('00000000-0000-0000-0000-000000000010',current_date,current_date); exception when raise_exception then denied:=true; end;
if not denied then raise exception 'cross-store read allowed'; end if;
end $$;
select set_config('test.uid','00000000-0000-0000-0000-000000000002',false);
select public.admin_food_finance_adjust('00000000-0000-0000-0000-000000000010',10000,'compensation','00000000-0000-0000-0000-000000000060');
do $$declare a uuid; denied boolean:=false; begin
select id into a from internal.food_finance_adjustments;
begin perform public.admin_food_finance_review(a,true,'checked'); exception when raise_exception then denied:=true; end;
if not denied then raise exception 'self approval allowed'; end if;
end $$;
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.admin_food_finance_review((select id from internal.food_finance_adjustments),true,'checked');
do $$begin
if not exists(select 1 from internal.food_finance_adjustments where state='approved' and reviewed_by<>proposed_by) then raise exception 'dual approval failed'; end if;
if has_function_privilege('authenticated','public.food_record_payment_facts(uuid,text,text,bigint,bigint,bigint,bigint,bigint,date,text)','EXECUTE') then raise exception 'browser facts write'; end if;
end $$;
select 'PASS finance operations: allocation, idempotency, limits, authorization, actual fees, dual approval' as result;
insert into internal.food_auto_refund_settings values(true,true,array['00000000-0000-0000-0000-000000000010'::uuid]);
insert into public.food_stripe_accounts values('00000000-0000-0000-0000-000000000010','acct_test',false);
do $$declare j record; n integer; begin
for n in 1..3 loop
select * into strict j from public.food_finance_claim_refunds();
if exists(select 1 from public.food_finance_claim_refunds()) then raise exception 'parallel refund for same order'; end if;
if public.food_finance_finish_refund(j.request_id,gen_random_uuid(),'succeeded','re_test','fr_test') then raise exception 'wrong lease accepted'; end if;
perform public.food_finance_finish_refund(j.request_id,j.lease,'succeeded','re_test','fr_test');
update public.food_order_campaigns set platform_funded=10;
if internal.food_finance_retained_funding('00000000-0000-0000-0000-000000000030')<>(case n when 1 then 6.67 when 2 then 3.33 else 0 end) then raise exception 'promotion refund allocation incorrect'; end if;
end loop;
if (select application_fee_refunded_satang from public.food_stripe_payments)<>900 then raise exception 'cumulative GP ledger incorrect'; end if;
update public.food_orders set status='cancelled';
perform internal.food_reserve_cancelled_refund('00000000-0000-0000-0000-000000000030');
select * into strict j from public.food_finance_claim_refunds();
if j.food_satang<>0 or j.delivery_satang<>2000 or j.gp_satang<>0 then raise exception 'remaining cancellation budget incorrect'; end if;
perform public.food_finance_finish_refund(j.request_id,j.lease,'succeeded','re_final',null);
if (select payment_status from public.food_orders)<>'refunded' then raise exception 'remaining full refund not completed'; end if;
end $$;
-- Provider facts are updated by reconciliation, not inferred from reservations.
select public.food_record_payment_facts('00000000-0000-0000-0000-000000000030','ch_test','txn_test',500,10999,10999,900,900,current_date,'available');
insert into internal.food_finance_issuer(display_name,address) values('Synthetic operator','Synthetic address');
select set_config('test.uid','00000000-0000-0000-0000-000000000001',false);
do $$declare d jsonb; begin
d:=public.merchant_finance_document('00000000-0000-0000-0000-000000000010',current_date,current_date);
if d->>'vat_invoice'<>'false' or d->>'document_number' is null then raise exception 'statement invalid'; end if;
if (select count(*) from internal.food_finance_documents)<>1 then raise exception 'statement not snapshotted'; end if;
end $$;
-- A fresh paid order before the 00:00 cutoff; actual fees reduce the budget.
delete from internal.food_finance_adjustments;
insert into public.food_orders(id,store_id,order_number,status,payment_status,payment_provider,subtotal,delivery_fee,total,gp_rate_bp,paid_at)
values('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000010','PAYOUT','delivered','paid','stripe',100,0,100,1000,now()-interval '1 day');
insert into public.food_stripe_payments(order_id,payment_intent_id,stripe_account_id,livemode,application_fee_satang,amount_satang,status)
values('00000000-0000-0000-0000-000000000031','pi_payout','acct_test',false,1000,10000,'paid');
select public.food_record_payment_facts('00000000-0000-0000-0000-000000000031','ch_payout','txn_payout',500,10000,0,0,1000,current_date,'available');
insert into internal.food_managed_payouts(store_id,account_id,enabled,starts_at) values('00000000-0000-0000-0000-000000000010','acct_test',true,now()-interval '2 days');
select public.food_finance_record_transactions('00000000-0000-0000-0000-000000000010',jsonb_build_array(
jsonb_build_object('id','txn_prior','amount',10000,'fee',1500,'net',8500,'source','ch_payout','kind','charge','created_at',now()-interval '1 day','available_on',current_date,'status','available'),
jsonb_build_object('id','txn_legacyPayout','amount',-2000,'fee',0,'net',-2000,'source','po_legacy','kind','payout','created_at',now()-interval '2 hours','available_on',current_date,'status','available')
),6500,null,true);
do $$declare v_id uuid; v_lease uuid:=gen_random_uuid(); v_amount bigint; begin
insert into internal.food_finance_payout_runs(store_id,account_id,business_day,cutoff_at,lease,lease_until)
values('00000000-0000-0000-0000-000000000010','acct_test',current_date-1,(now() at time zone 'Asia/Bangkok')::date::timestamp at time zone 'Asia/Bangkok',v_lease,now()+interval '3 minutes') returning id into v_id;
v_amount:=public.food_finance_prepare_payout(v_id,v_lease,4000);
if v_amount<>4000 then raise exception 'available balance cap incorrect: %',v_amount; end if;
if public.food_finance_prepare_payout(v_id,v_lease,8000)<>4000 then raise exception 'retry changed payout amount'; end if;
if public.food_finance_finish_payout(v_id,gen_random_uuid(),'submitted','po_test',current_date) then raise exception 'wrong payout lease accepted'; end if;
perform public.food_finance_finish_payout(v_id,v_lease,'submitted','po_test',current_date);
end $$;
select 'PASS refund queue, remaining cancellation, immutable statement and available-balance payout' as result;
create trigger test_refund_enqueue after update of status,payment_status on public.food_orders for each row execute function internal.food_enqueue_auto_refund();
insert into public.food_orders(id,store_id,order_number,status,payment_status,payment_provider,subtotal,delivery_fee,total,gp_rate_bp,paid_at,buyer_id,stripe_checkout_session_id)
values('00000000-0000-0000-0000-000000000032','00000000-0000-0000-0000-000000000010','CUSTOMER','pending_acceptance','paid','stripe',30,0,30,1000,now(),'00000000-0000-0000-0000-000000000001','cs_test');
insert into public.food_stripe_payments(order_id,payment_intent_id,stripe_account_id,livemode,application_fee_satang,amount_satang,status)
values('00000000-0000-0000-0000-000000000032','pi_customer','acct_test',false,300,3000,'paid');
select public.food_cancel_order('00000000-0000-0000-0000-000000000032','customer cancellation');
do $$begin
if not exists(select 1 from internal.food_finance_refunds where order_id='00000000-0000-0000-0000-000000000032' and food_satang=3000 and kind='full') then raise exception 'customer cancellation not queued'; end if;
end $$;
select 'PASS paid customer cancellation queues the refund atomically' as result;
do $$declare v jsonb; begin
v:=public.merchant_finance_summary('00000000-0000-0000-0000-000000000010',current_date,current_date);
if (v->>'refunds')::numeric<>109.99 or (v->>'gp')::numeric<>3 or (v->>'sales_net')::numeric<>30 then raise exception 'summary double-counted partial/full refunds: %',v; end if;
end $$;
select 'PASS summary partial/full refund and GP totals do not double count' as result;
select count(*) as payout_candidates from public.food_finance_payout_candidates();
select count(*) as funding_candidates from public.food_finance_funding_jobs();
select count(*) as account_candidates from public.food_finance_sync_accounts();
select count(*) as payment_candidates from public.food_finance_sync_candidates();
SQL
