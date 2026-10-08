-- WYNOS Finance authorization regression: ONLY Supabase QA pcatuxtenluqzjzzwsvl.
-- Tests actual DB roles anon/authenticated + transaction-local simulated JWT sub.
-- This is NOT an HTTP request or a signed JWT verification test.
-- Every test fixture is inside BEGIN/ROLLBACK.
BEGIN;
DO $$
declare
 v_order uuid;
 v_store uuid;
 v_other_store uuid;
 v_owner uuid;
 v_outsider uuid;
 v_result jsonb;
begin
 select o.id,o.store_id,mm.user_id into v_order,v_store,v_owner
 from public.food_orders o
 join public.food_stores s on s.id=o.store_id
 join public.merchant_memberships mm
   on mm.merchant_account_id=s.merchant_account_id and mm.active and mm.role='owner'
 where o.order_number='WF000005' limit 1;
 select u.id into v_outsider from auth.users u where u.id<>v_owner limit 1;
 select id into v_other_store from public.food_stores where id<>v_store limit 1;
 if v_order is null or v_owner is null or v_outsider is null
   or v_other_store is null
   or exists(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
   or exists(select 1 from public.food_gp_store_rates where store_id=v_store)
   or exists(select 1 from public.food_gp_admin_allowlist where user_id in (v_owner,v_outsider))
 then raise exception 'QA fixture unavailable or unexpectedly prepopulated'; end if;

 perform set_config('qa.finance.owner',v_owner::text,true);
 perform set_config('qa.finance.outsider',v_outsider::text,true);
 perform set_config('qa.finance.store',v_store::text,true);
 perform set_config('qa.finance.other_store',v_other_store::text,true);
 insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
 values(v_store,750,v_owner);
 v_result:=public.food_gp_capture_order_qa(v_order);
 if v_result->>'status'<>'snapshotted' then raise exception 'GP snapshot fixture failed %',v_result;end if;
 v_result:=public.food_finance_capture_order_qa(v_order);
 if v_result->>'status'<>'projected' then raise exception 'Finance projection fixture failed %',v_result;end if;
 v_result:=public.food_finance_append_refund_qa(v_order,'AUTHZ-QA-01',100,0,'Transaction-only auth test refund');
 if v_result->>'status'<>'adjusted' then raise exception 'Refund fixture failed %',v_result;end if;
 perform set_config('qa.finance.order',v_order::text,true);
end;
$$;

-- A legitimate active store owner can see only their store, not Admin,
-- raw finance tables, the privileged core, or mutation RPCs.
SELECT set_config('request.jwt.claim.sub',current_setting('qa.finance.owner'),true);
SET LOCAL ROLE authenticated;
DO $$
declare v_s uuid:=current_setting('qa.finance.store')::uuid;
 v_other uuid:=current_setting('qa.finance.other_store')::uuid;
 v_oid uuid:=current_setting('qa.finance.order')::uuid;
 v_report jsonb;
begin
 if current_user <> 'authenticated' then raise exception 'Role switching failed';end if;
 v_report:=public.merchant_food_finance_report_qa(v_s,now()-interval '1 day',now()+interval '1 day');
 if (v_report->'totals'->>'projection_count')::int<>1
 or (v_report->'totals'->>'refund_event_count')::int<>1 then
  raise exception 'Owner reporting totals mismatch';end if;
 if jsonb_array_length(public.merchant_food_finance_events_qa(v_s,now()-interval '1 day',now()+interval '1 day',50,0)->'events')<>2 then
  raise exception 'Owner event timeline mismatch';end if;
 begin
  perform public.merchant_food_finance_report_qa(v_other,now()-interval '1 day',now()+interval '1 day');
  raise exception 'Cross-store report allowed';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.merchant_food_finance_events_qa(v_other,now()-interval '1 day',now()+interval '1 day',50,0);
  raise exception 'Cross-store event timeline allowed';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.admin_food_finance_report_qa(now()-interval '1 day',now()+interval '1 day',null);
  raise exception 'Owner has unauthorized admin reporting';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.admin_food_finance_refunds_qa(v_oid);
  raise exception 'Owner has unauthorized admin refunds';
 exception when sqlstate '42501' then null;end;
 begin
  perform count(*) from public.food_finance_refund_adjustments_qa;
  raise exception 'Owner read raw private finance table';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.food_finance_report_core_qa(now()-interval '1 day',now()+interval '1 day',null);
  raise exception 'Owner bypassed finance report core';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.food_finance_append_refund_qa(v_oid,'AUTHZ-QA-BLOCK',1,0,'Unauthorized call');
  raise exception 'Owner invoked privileged refund mutation';
 exception when sqlstate '42501' then null;end;
end;$$;
RESET ROLE;

-- Unrelated signed-in user: both Admin and Merchant RPC deny access.
SELECT set_config('request.jwt.claim.sub',current_setting('qa.finance.outsider'),true);
SET LOCAL ROLE authenticated;
DO $$
declare v_s uuid:=current_setting('qa.finance.store')::uuid; begin
 begin
  perform public.admin_food_finance_events_qa(now()-interval '1 day',now()+interval '1 day',null,50,0);
  raise exception 'Unallowlisted outsider read Admin events';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.merchant_food_finance_report_qa(v_s,now()-interval '1 day',now()+interval '1 day');
  raise exception 'Outsider read merchant totals';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.merchant_food_finance_events_qa(v_s,now()-interval '1 day',now()+interval '1 day',50,0);
  raise exception 'Outsider read merchant events';
 exception when sqlstate '42501' then null;end;
end;$$;
RESET ROLE;

-- An allowlisted outsider becomes QA Admin but NEVER store owner.
INSERT INTO public.food_gp_admin_allowlist(user_id,note)
VALUES(current_setting('qa.finance.outsider')::uuid,'Rollback-only QA role assertion');
SELECT set_config('request.jwt.claim.sub',current_setting('qa.finance.outsider'),true);
SET LOCAL ROLE authenticated;
DO $$
declare v_s uuid:=current_setting('qa.finance.store')::uuid; v_r jsonb;begin
 v_r:=public.admin_food_finance_report_qa(now()-interval '1 day',now()+interval '1 day',null);
 if (v_r->'totals'->>'projection_count')::int<>1 then
  raise exception 'QA Admin aggregated report failed';end if;
 v_r:=public.admin_food_finance_events_qa(now()-interval '1 day',now()+interval '1 day',null,50,0);
 if (v_r->>'total_events')::int<>2 then raise exception 'QA Admin timeline failed';end if;
 begin
  perform public.merchant_food_finance_report_qa(v_s,now()-interval '1 day',now()+interval '1 day');
  raise exception 'Admin became merchant owner unexpectedly';
 exception when sqlstate '42501' then null;end;
 begin
  perform count(*) from public.food_finance_refund_adjustments_qa;
  raise exception 'Admin read raw private refunds table';
 exception when sqlstate '42501' then null;end;
end;$$;
RESET ROLE;

-- Anon database role cannot invoke either the Admin or Merchant APIs.
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE anon;
DO $$
declare v_s uuid:=current_setting('qa.finance.store')::uuid;begin
 begin
  perform public.admin_food_finance_report_qa(now()-interval '1 day',now()+interval '1 day',null);
  raise exception 'Anonymous Admin RPC allowed';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.merchant_food_finance_report_qa(v_s,now()-interval '1 day',now()+interval '1 day');
  raise exception 'Anonymous Merchant RPC allowed';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.food_finance_append_refund_qa(current_setting('qa.finance.order')::uuid,'ANON-QA-BLOCK',1,0,'Unauthorized call');
  raise exception 'Anonymous refund mutation RPC allowed';
 exception when sqlstate '42501' then null;end;
end;$$;
RESET ROLE;

-- These changes and allowlist entries disappear in this ROLLBACK.
ROLLBACK;