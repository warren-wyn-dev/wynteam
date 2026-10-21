#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="food_auto_refund_test_$$"
$PSQL -X -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB"
trap '$PSQL -X -q -d postgres -c "drop database if exists $DB"' EXIT
run() { $PSQL -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run <<'SQL'
create schema internal; create schema vault;
create table vault.decrypted_secrets(name text,decrypted_secret text);
insert into vault.decrypted_secrets values('wynos_food_auto_refund_cron_key',repeat('x',64));
create table public.food_orders(id uuid primary key,store_id uuid,status text,payment_status text,payment_provider text,
  stripe_payment_intent_id text,stripe_refund_id text,refund_status text default 'none',refund_requested_at timestamptz,refunded_at timestamptz);
create table public.food_stripe_payments(order_id uuid primary key,status text,application_fee_satang bigint,
  application_fee_refunded_satang bigint default 0,application_fee_refunded_at timestamptz);
insert into public.food_orders(id,store_id,status,payment_status,payment_provider,stripe_payment_intent_id)
values('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000010','cancelled','paid','stripe','pi_old');
SQL
run -f "$ROOT/supabase/migrations/20261021102938_food_automatic_stripe_refunds.sql"
run <<'SQL'
do $$ begin
if exists(select 1 from internal.food_auto_refunds) then raise exception 'Historical refund backfilled'; end if;
if has_function_privilege('authenticated','public.food_claim_auto_refunds()','EXECUTE')
or has_function_privilege('anon','public.food_finish_auto_refund(uuid,uuid,text,text)','EXECUTE')
or has_function_privilege('authenticated','public.food_auto_refund_authorized(text)','EXECUTE') then raise exception 'Browser worker privileges'; end if;
if not public.food_auto_refund_authorized(repeat('x',64)) or public.food_auto_refund_authorized('bad') then raise exception 'Cron authentication'; end if;
end $$;
update internal.food_auto_refund_settings set enabled=true,store_ids=array['00000000-0000-0000-0000-000000000010'::uuid];
insert into public.food_orders(id,store_id,status,payment_status,payment_provider,stripe_payment_intent_id)
values('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000010','pending_acceptance','paid','stripe','pi_new'),
('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000099','pending_acceptance','paid','stripe','pi_other'),
('00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000010','pending_acceptance','paid','slip',null),
('00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000010','cancelled','pending','stripe','pi_late');
update public.food_orders set status='cancelled' where id in ('00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004');
insert into public.food_stripe_payments(order_id,status,application_fee_satang) values('00000000-0000-0000-0000-000000000002','paid',300);
do $$ declare j record; begin
if (select count(*) from internal.food_auto_refunds)<>1 then raise exception 'Wrong cancellation scope'; end if;
select * into strict j from public.food_claim_auto_refunds();
if exists(select 1 from public.food_claim_auto_refunds()) then raise exception 'Active lease claimed twice'; end if;
if public.food_finish_auto_refund(j.order_id,gen_random_uuid(),'succeeded','re_wrong') then raise exception 'Wrong lease accepted'; end if;
perform public.food_finish_auto_refund(j.order_id,j.lease_token,'pending','re_test');
if (select application_fee_refunded_satang from public.food_stripe_payments where order_id=j.order_id)<>0 then raise exception 'Pending GP reversed'; end if;
if (select payment_status from public.food_orders where id=j.order_id)<>'paid' then raise exception 'Pending payment marked refunded'; end if;
update internal.food_auto_refunds set next_attempt_at=now() where order_id=j.order_id;
select * into strict j from public.food_claim_auto_refunds();
if j.refund_id<>'re_test' then raise exception 'Refund id lost on retry'; end if;
perform public.food_finish_auto_refund(j.order_id,j.lease_token,'succeeded','re_test');
if public.food_finish_auto_refund(j.order_id,j.lease_token,'succeeded','re_test') then raise exception 'Duplicate completion accepted'; end if;
if (select payment_status from public.food_orders where id=j.order_id)<>'refunded' then raise exception 'Success not recorded'; end if;
if (select application_fee_refunded_satang from public.food_stripe_payments where order_id=j.order_id)<>300 then raise exception 'GP not returned'; end if;
end $$;
update public.food_orders set payment_status='paid' where id='00000000-0000-0000-0000-000000000005';
do $$ declare j record; begin
if (select count(*) from internal.food_auto_refunds)<>2 then raise exception 'Late paid cancellation not queued'; end if;
select * into strict j from public.food_claim_auto_refunds();
perform public.food_finish_auto_refund(j.order_id,j.lease_token,'retry',null);
if (select next_attempt_at<=now() from internal.food_auto_refunds where order_id=j.order_id) then raise exception 'Retry has no backoff'; end if;
update internal.food_auto_refunds set attempts=8,state='processing',lease_until=now()-interval '1 second' where order_id=j.order_id;
perform * from public.food_claim_auto_refunds();
if (select state from internal.food_auto_refunds where order_id=j.order_id)<>'needs_review' then raise exception 'Retries not bounded'; end if;
end $$;
select 'PASS: automatic refund queue, lease, authorization, pending/success, GP, retry, late payment and scope' as result;
SQL
