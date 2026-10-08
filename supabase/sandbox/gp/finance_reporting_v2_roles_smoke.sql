-- WYNOS Finance v2 PostgreSQL ROLE regression on QA pcatuxtenluqzjzzwsvl ONLY.
-- Role switching approximates PostgREST auth context but NOT signed HTTP JWT.
-- Everything is reverted by ROLLBACK; Stripe refund API never called.
BEGIN;
DO $$
declare v_order uuid;v_store uuid;v_other uuid;v_owner uuid;v_outsider uuid;v_r jsonb;
begin
 select o.id,o.store_id,mm.user_id into v_order,v_store,v_owner
 from public.food_orders o join public.food_stores s on s.id=o.store_id
 join public.merchant_memberships mm on mm.merchant_account_id=s.merchant_account_id
 and mm.active and mm.role='owner'
 where o.order_number='WF000005' limit 1;
 select id into v_other from public.food_stores where id<>v_store limit 1;
 select id into v_outsider from auth.users where id<>v_owner limit 1;
 if v_order is null or v_other is null or v_owner is null or v_outsider is null
  or exists(select 1 from public.food_gp_store_rates where store_id=v_store)
  or exists(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
  or exists(select 1 from public.food_gp_admin_allowlist) then
  raise exception 'Refuse polluted QA fixtures';
 end if;
 perform set_config('qa.v2.store',v_store::text,true);
 perform set_config('qa.v2.other',v_other::text,true);
 perform set_config('qa.v2.owner',v_owner::text,true);
 perform set_config('qa.v2.outsider',v_outsider::text,true);
 perform set_config('qa.v2.order',v_order::text,true);
 insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
 values(v_store,750,v_owner);
 v_r:=public.food_gp_capture_order_qa(v_order);
 if v_r->>'status'<>'snapshotted' then raise exception 'GP fixture failed';end if;
 v_r:=public.food_finance_capture_order_qa(v_order);
 if v_r->>'status'<>'projected' then raise exception 'Projection fixture failed';end if;
 v_r:=public.food_finance_append_refund_qa(v_order,'QA-ROLE-V2-REF',1111,0,'Role isolation simulation');
 if v_r->>'status'<>'adjusted' then raise exception 'Refund fixture failed';end if;
end;$$;

select set_config('request.jwt.claim.sub',current_setting('qa.v2.owner'),true);
set local role authenticated;
DO $$
declare v_s uuid:=current_setting('qa.v2.store')::uuid;
 v_other uuid:=current_setting('qa.v2.other')::uuid;
 v_order uuid:=current_setting('qa.v2.order')::uuid;v_r jsonb;
begin
 v_r:=public.merchant_food_finance_buckets_v2_qa(v_s,now()-interval '1 day',now()+interval '1 day','day');
 if v_r->>'mode'<>'simulation_only'
  or (select coalesce(sum((j->>'projection_count')::bigint),0) from jsonb_array_elements(v_r->'buckets') j)<>1 then
  raise exception 'Authenticated owner v2 buckets failed';end if;
 v_r:=public.merchant_food_finance_order_details_v2_qa(v_s,v_order);
 if (v_r->>'refund_event_count')::int<>1 then
  raise exception 'Authenticated owner v2 detail failed';end if;
 begin
   perform public.merchant_food_finance_buckets_v2_qa(v_other,now()-interval '1 day',now()+interval '1 day','month');
   raise exception 'Cross-store v2 data allowed';
 exception when sqlstate '42501' then null;end;
 begin
   perform public.admin_food_finance_order_details_v2_qa(v_order);
   raise exception 'Owner is not allowlisted Admin';
 exception when sqlstate '42501' then null;end;
 begin
   perform wynos_finance_qa_private.food_finance_buckets_core_v2_qa(now()-interval '1 day',now()+interval '1 day',v_s,'day');
   raise exception 'Privileged core callable by user';
 exception when sqlstate '42501' then null;end;
end;$$;
reset role;

select set_config('request.jwt.claim.sub',current_setting('qa.v2.outsider'),true);
set local role authenticated;
DO $$
declare v_s uuid:=current_setting('qa.v2.store')::uuid;
 v_order uuid:=current_setting('qa.v2.order')::uuid;
begin
 begin
  perform public.merchant_food_finance_order_details_v2_qa(v_s,v_order);
  raise exception 'Outsider merchant v2 details access';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.admin_food_finance_buckets_v2_qa(now()-interval '1 day',now()+interval '1 day','day',null);
  raise exception 'Outsider admin v2 buckets access';
 exception when sqlstate '42501' then null;end;
end;$$;
reset role;

insert into public.food_gp_admin_allowlist(user_id,note)
values(current_setting('qa.v2.outsider')::uuid,'QA v2 ROLE ROLLBACK');
select set_config('request.jwt.claim.sub',current_setting('qa.v2.outsider'),true);
set local role authenticated;
DO $$
declare v_s uuid:=current_setting('qa.v2.store')::uuid;
 v_order uuid:=current_setting('qa.v2.order')::uuid;v_r jsonb;
begin
 v_r:=public.admin_food_finance_order_details_v2_qa(v_order);
 if v_r->>'status'<>'projected' then raise exception 'Allowlisted QA admin v2 detail denied';end if;
 v_r:=public.admin_food_finance_buckets_v2_qa(now()-interval '1 day',now()+interval '1 day','day',null);
 if v_r->>'mode'<>'simulation_only' then raise exception 'Allowlisted QA admin v2 report denied';end if;
 begin
  perform public.merchant_food_finance_order_details_v2_qa(v_s,v_order);
  raise exception 'QA Admin implicitly became unrelated merchant';
 exception when sqlstate '42501' then null;end;
end;$$;
reset role;

select set_config('request.jwt.claim.sub','',true);
set local role anon;
DO $$
begin
 begin
  perform public.admin_food_finance_buckets_v2_qa(now()-interval '1 day',now()+interval '1 day','day',null);
  raise exception 'Anonymous admin v2 read';
 exception when sqlstate '42501' then null;end;
 begin
  perform public.merchant_food_finance_order_details_v2_qa(
   current_setting('qa.v2.store')::uuid,current_setting('qa.v2.order')::uuid);
  raise exception 'Anonymous merchant v2 read';
 exception when sqlstate '42501' then null;end;
end;$$;
reset role;
ROLLBACK;