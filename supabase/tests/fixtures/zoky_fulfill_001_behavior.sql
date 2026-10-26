-- Freeze only the server-only test seam in this disposable database. Production retains now().
create or replace function internal.food_fulfillment_now() returns timestamptz language sql stable set search_path='' as $$select '2026-10-26 05:01:00Z'::timestamptz$$;
-- Synthetic identities and assertions. All queries run in a disposable local DB.
create function public.qa_assert(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; raise notice 'ok - %',label; end $$;
create function public.qa_error(statement text,pattern text,label text) returns void language plpgsql as $$
begin
  begin execute statement; exception when others then
    if sqlerrm ilike '%'||pattern||'%' then raise notice 'ok - %',label; return; end if;
    raise exception 'FAIL: % expected % got %',label,pattern,sqlerrm;
  end;
  raise exception 'FAIL: % unexpectedly succeeded',label;
end $$;
insert into public.profiles(id,username) values
 ('00000000-0000-0000-0000-000000000001','buyer'),('00000000-0000-0000-0000-000000000002','other'),
 ('00000000-0000-0000-0000-000000000003','owner'),('00000000-0000-0000-0000-000000000004','orders');
insert into public.food_stores(id,name,address,is_open,is_published,merchant_account_id,latitude,longitude,business_schedule)
select '00000000-0000-0000-0000-000000000101','Synthetic','Test address',true,true,'00000000-0000-0000-0000-000000000201',16,103,
jsonb_build_object('weekly',jsonb_object_agg(d,jsonb_build_object('enabled',true,'open','12:00','close','11:59')))
from unnest(array['mon','tue','wed','thu','fri','sat','sun']) d;
insert into public.food_stores(id,name,is_open,is_published,merchant_account_id,latitude,longitude) values('00000000-0000-0000-0000-000000000102','Foreign',true,true,'00000000-0000-0000-0000-000000000202',16,103);
insert into public.merchant_memberships values ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000003','owner',true),('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000004','orders',true);
insert into public.food_menu_items(id,store_id,name,price) values('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000101','Synthetic meal',100);
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.food_store_set_fulfillment('00000000-0000-0000-0000-000000000101',true,true,true,5);
select public.qa_error($q$select public.food_store_set_fulfillment('00000000-0000-0000-0000-000000000101',false,false,false,15)$q$,'at_least_one_mode','must keep one mode');
select public.qa_error($q$select public.food_store_set_fulfillment('00000000-0000-0000-0000-000000000101',true,false,true,15)$q$,'cod_requires_delivery','COD needs delivery');
select public.qa_error($q$select public.food_store_set_fulfillment('00000000-0000-0000-0000-000000000102',true,true,false,15)$q$,'role required','foreign store rejected');
select set_config('test.uid','00000000-0000-0000-0000-000000000004',false);
select public.qa_error($q$select public.food_store_set_fulfillment('00000000-0000-0000-0000-000000000101',true,true,false,15)$q$,'role required','orders role cannot configure');
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.qa_error($q$update public.food_stores set cod_enabled=false where id='00000000-0000-0000-0000-000000000101'$q$,'','direct settings cannot bypass RPC');
reset role;
select set_config('test.uid','00000000-0000-0000-0000-000000000001',false);
-- Fixed clocks exercise slot math independent of current local wall time.
select public.qa_assert((select min(t)='2026-10-26 05:15Z'::timestamptz from internal.food_pickup_slots('00000000-0000-0000-0000-000000000101','2026-10-26 05:01Z') t),'server prep rounded up to 15 minute slot');
select public.qa_assert(not exists(select 1 from internal.food_pickup_slots('00000000-0000-0000-0000-000000000101','2026-10-26 16:58Z')),'no cross-day pickup slots');
select public.qa_error($q$select public.food_create_order_v3('00000000-0000-0000-0000-000000000101','Buyer','0811111111','',null,'[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',null,null,null,'pickup',now()-interval '1 day','transfer')$q$,'invalid pickup time','past pickup refused');
select public.qa_error($q$select public.food_create_order_v3('00000000-0000-0000-0000-000000000101','Buyer','0811111111','',null,'[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',null,null,null,'pickup',now()+interval '1 day','cod')$q$,'cod_unavailable','pickup COD refused');
-- Create helpers switch buyer for each scenario to preserve rate-limit protections.
create function public.qa_order(mode text,payment text) returns uuid language plpgsql as $$
declare result uuid; slot timestamptz;
begin
  perform set_config('test.uid',gen_random_uuid()::text,false);
  select min(t) into slot from internal.food_pickup_slots('00000000-0000-0000-0000-000000000101') t;
  result:=public.food_create_order_v3('00000000-0000-0000-0000-000000000101','Buyer','0811111111','Synthetic address',null,'[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',16,103,null,mode,case when mode='pickup' then slot else null end,payment);
  return result;
end $$;
create table public.qa_orders(kind text,id uuid);
grant select on public.qa_orders to authenticated;
insert into qa_orders values('pickup',qa_order('pickup','transfer')),('cod',qa_order('delivery','cod')),('transfer',qa_order('delivery','transfer'));
select public.qa_assert((select delivery_fee=0 and delivery_latitude is null and pickup_code is not null from food_orders where id=(select id from qa_orders where kind='pickup')),'pickup fee zero, no buyer pin, generated code');
select public.qa_assert((select gp_rate_bp=0 and payment_due_at is null from food_orders where id=(select id from qa_orders where kind='cod')),'COD zero GP and no unpaid deadline');
select public.qa_assert((select gp_rate_bp=1000 and payment_due_at is not null from food_orders where id=(select id from qa_orders where kind='transfer')),'transfer preserves GP/deadline');
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.qa_error(format('select public.food_transition_order(%L,''preparing'')',(select id from qa_orders where kind='pickup')),'payment must be verified','unpaid transfer cannot accept');
select public.food_transition_order((select id from qa_orders where kind='cod'),'preparing');
select public.food_transition_order((select id from qa_orders where kind='cod'),'ready_for_delivery');
select public.food_transition_order((select id from qa_orders where kind='cod'),'out_for_delivery');
select public.qa_error(format('select public.food_complete_delivery(%L,''direct'')',(select id from qa_orders where kind='cod')),'delivery photo is required','COD still needs evidence');
insert into storage.objects(bucket_id,name) select 'food-private','delivery/'||id||'/proof.jpg' from qa_orders where kind='cod';
select public.food_complete_delivery((select id from qa_orders where kind='cod'),'direct',null,'delivery/'||(select id from qa_orders where kind='cod')||'/proof.jpg');
select public.qa_assert((select status='delivered' and payment_status='paid' and payment_provider='merchant_cash' from food_orders where id=(select id from qa_orders where kind='cod')),'COD completes with paid cash');
select public.food_set_payment_status((select id from qa_orders where kind='pickup'),'paid');
select public.food_transition_order((select id from qa_orders where kind='pickup'),'preparing');
select public.qa_error(format('select public.food_transition_order(%L,''ready_for_delivery'')',(select id from qa_orders where kind='pickup')),'invalid order transition','pickup rejects delivery path');
select public.food_transition_order((select id from qa_orders where kind='pickup'),'ready_for_pickup');
select public.food_transition_order((select id from qa_orders where kind='pickup'),'picked_up');
select public.qa_assert((select picked_up_at is not null from food_orders where id=(select id from qa_orders where kind='pickup')),'pickup terminal has timestamp');
-- Cross-customer visibility and mutation boundaries remain server enforced.
select set_config('test.uid','00000000-0000-0000-0000-000000000002',false);
set role authenticated;
select public.qa_assert((select count(*)=0 from food_orders),'other customer cannot read codes/orders');
reset role;
select public.qa_error(format('select public.food_request_cancel(%L,''Not mine'')',(select id from qa_orders where kind='transfer')),'order not found','other customer cannot request cancellation');
select public.qa_error(format('select public.food_transition_order(%L,''preparing'')',(select id from qa_orders where kind='transfer')),'role required','other customer cannot transition');
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
set role authenticated;
select public.qa_error(format('update food_orders set status=''delivered'' where id=%L',(select id from qa_orders where kind='transfer')),'order state requires RPC','direct state updates blocked');
reset role;
select public.food_set_payment_status((select id from qa_orders where kind='transfer'),'paid');
select public.food_transition_order((select id from qa_orders where kind='transfer'),'preparing');
select set_config('test.uid',(select buyer_id::text from food_orders where id=(select id from qa_orders where kind='transfer')),false);
select public.qa_error(format('select public.food_cancel_order(%L)',(select id from qa_orders where kind='transfer')),'cannot be cancelled','accepted customer cancellation blocked');
select public.food_request_cancel((select id from qa_orders where kind='transfer'),'Changed plans');
select public.qa_assert((select status='preparing' and cancel_requested_at is not null from food_orders where id=(select id from qa_orders where kind='transfer')),'request does not cancel accepted order');
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.food_resolve_cancel_request((select id from qa_orders where kind='transfer'),false,false,'Cooking');
select public.qa_assert((select status='preparing' and cancel_requested_at is null from food_orders where id=(select id from qa_orders where kind='transfer')),'rejection preserves order and clears banner');
select public.food_store_cancel_order((select id from qa_orders where kind='transfer'),false,'No show');
select public.qa_assert((select status='cancelled' and refund_status='none' from food_orders where id=(select id from qa_orders where kind='transfer')),'no-show cancellation honors no refund');
-- Separate paid cancellation owes a refund; no automatic completion is permitted.
insert into qa_orders values('refund',qa_order('delivery','transfer'));
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.food_set_payment_status((select id from qa_orders where kind='refund'),'paid');
select public.food_store_cancel_order((select id from qa_orders where kind='refund'),true,'Refund approved');
select public.qa_assert((select refund_status='pending' from food_orders where id=(select id from qa_orders where kind='refund')),'paid approved refund remains owed until slip');
select public.qa_error(format('select public.food_store_mark_refunded(%L,''food-refund-slips/foreign/order/slip.jpg'')',(select id from qa_orders where kind='refund')),'refund slip required','foreign evidence rejected');
select public.qa_error(format('select public.food_store_mark_refunded(%L,%L)',q.id,'food-refund-slips/00000000-0000-0000-0000-000000000101/'||q.id||'/missing.jpg'),'refund slip required','nonexistent evidence rejected') from qa_orders q where kind='refund';
select set_config('test.uid','00000000-0000-0000-0000-000000000004',false);
set role authenticated;
select public.qa_error(format('insert into storage.objects(bucket_id,name) values(''food-private'',%L)','food-refund-slips/00000000-0000-0000-0000-000000000101/'||(select id from qa_orders where kind='refund')||'/refund.jpg'),'row-level security','orders role cannot upload refund slip');
reset role;
select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
set role authenticated;
insert into storage.objects(bucket_id,name) select 'food-private','food-refund-slips/00000000-0000-0000-0000-000000000101/'||id||'/refund.jpg' from qa_orders where kind='refund';
select public.qa_assert((select count(*)=1 from storage.objects where name like 'food-refund-slips/%'),'authorized manager can read refund evidence');
with changed as (delete from storage.objects where name like 'food-refund-slips/%' returning 1) select public.qa_assert((select count(*)=0 from changed),'refund evidence deletion blocked');
with changed as (update storage.objects set name=name||'.changed' where name like 'food-refund-slips/%' returning 1) select public.qa_assert((select count(*)=0 from changed),'refund evidence replacement blocked');
reset role;
select public.food_store_mark_refunded(q.id,'food-refund-slips/00000000-0000-0000-0000-000000000101/'||q.id||'/refund.jpg') from qa_orders q where kind='refund';
select public.food_store_mark_refunded(q.id,'food-refund-slips/00000000-0000-0000-0000-000000000101/'||q.id||'/refund.jpg') from qa_orders q where kind='refund';
select public.qa_assert((select refund_status='refunded' and refunded_by_store_at is not null from food_orders where id=(select id from qa_orders where kind='refund')),'refund completes only with slip; retries idempotent');
select set_config('test.uid','00000000-0000-0000-0000-000000000002',false);
set role authenticated;
select public.qa_assert((select count(*)=0 from storage.objects where name like 'food-refund-slips/%'),'unrelated customer cannot read refund slip');
reset role;
-- Existing timeout, old paid cancel semantics, coupon and report regressions.
insert into qa_orders values('timeout',qa_order('delivery','transfer')),('cod-timeout',qa_order('delivery','cod'));
update food_orders set payment_due_at=now()-interval '1 minute' where id in(select id from qa_orders where kind in('timeout','cod-timeout'));
select set_config('test.role','service_role',false);
select public.qa_assert(public.food_timeout_cancel((select id from qa_orders where kind='timeout')),'unpaid transfer still times out');
select public.qa_assert(not public.food_timeout_cancel((select id from qa_orders where kind='cod-timeout')),'COD never times out even malformed deadline');
select set_config('test.role','authenticated',false);
select public.qa_error($q$select public.admin_food_orders_v2()$q$,'Only admins','Admin read model rejects customer');
select set_config('test.uid','00000000-0000-0000-0000-000000000002',false);
insert into qa_admin_permissions values('00000000-0000-0000-0000-000000000002','food','edit'),('00000000-0000-0000-0000-000000000002','merchant','view');
select public.qa_assert(jsonb_array_length(public.admin_food_orders_v2(null,null,null,100,'pickup',null))=1,'Admin filters pickup before pagination');
select public.qa_assert(public.admin_food_fulfillment_summary((now() at time zone 'Asia/Bangkok')::date,(now() at time zone 'Asia/Bangkok')::date)->'rows' is not null,'Admin aggregation accepts valid bounded range');
select public.qa_error($q$select public.admin_food_fulfillment_summary(current_date,current_date+366)$q$,'Invalid date range','Admin aggregation bounds range');

select set_config('test.uid','00000000-0000-0000-0000-000000000003',false);
select public.qa_error(format('select public.food_set_payment_status(%L,''paid'')',(select id from qa_orders where kind='refund')),'refund evidence is final','paid status cannot undo completed refund');
select public.qa_error(format('select public.merchant_set_refund_status(%L,''pending'')',(select id from qa_orders where kind='refund')),'refund evidence is final','legacy refund RPC cannot undo completed refund');
select public.qa_error($q$select internal.food_set_scheduled_order('00000000-0000-0000-0000-000000000999',now()+interval '1 day')$q$,'delivery scheduling is unavailable','legacy scheduling cannot bypass same-day pickup contract');

insert into qa_orders values('legacy-ownerless',qa_order('delivery','transfer'));
update food_orders set buyer_id=null where id=(select id from qa_orders where kind='legacy-ownerless');
select public.qa_error(format('select public.food_cancel_order(%L)',(select id from qa_orders where kind='legacy-ownerless')),'order not found','ownerless legacy order cannot be cancelled by arbitrary customer');
select public.qa_error(format('select public.food_submit_payment(%L,''not-a-slip'')',(select id from qa_orders where kind='legacy-ownerless')),'order not found','ownerless legacy payment cannot be claimed');
insert into public.food_campaigns(id,platform_campaign_id) values('00000000-0000-0000-0000-000000000ca1','00000000-0000-0000-0000-000000000ca2');
insert into public.food_coupon_codes(id,code,platform_campaign_id,max_uses_per_user) values('00000000-0000-0000-0000-000000000ca3','SYNTH','00000000-0000-0000-0000-000000000ca2',1);
select set_config('test.uid',gen_random_uuid()::text,false);
select public.qa_assert((public.food_quote_order_v3('00000000-0000-0000-0000-000000000101','[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',null,null,'SYNTH','pickup')->>'total')::numeric=90,'pickup quote preserves coupon pricing');
select public.food_create_order_v3('00000000-0000-0000-0000-000000000101','Buyer','0811111111','',null,'[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',null,null,'SYNTH','pickup',(select min(t) from internal.food_pickup_slots('00000000-0000-0000-0000-000000000101') t),'transfer');
select public.qa_assert((select count(*)=1 from public.food_coupon_redemptions),'pickup creation redeems existing coupon once');
select public.qa_error($q$select public.food_create_order_v3('00000000-0000-0000-0000-000000000101','Buyer','0811111111','',null,'[{"menu_item_id":"00000000-0000-0000-0000-000000000301","quantity":1}]',null,null,'SYNTH','pickup',(select min(t) from internal.food_pickup_slots('00000000-0000-0000-0000-000000000101') t),'transfer')$q$,'coupon_already_used','pickup cannot double-redeem coupon');
