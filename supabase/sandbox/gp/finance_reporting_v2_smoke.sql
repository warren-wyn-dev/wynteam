-- WYNOS Finance Reporting v2 regression QA pcatuxtenluqzjzzwsvl ONLY.
-- Includes date buckets, order details, boundary validation, owner separation.
-- BEGIN/ROLLBACK: no simulated finance data survives this test.
BEGIN;
DO $$
DECLARE
  v_order uuid;v_store uuid;v_other uuid;v_owner uuid;
  v_r jsonb;v_b jsonb;v_d jsonb;v_month jsonb;
  v_from timestamptz:=now()-interval '1 day';
  v_to timestamptz:=now()+interval '1 day';
BEGIN
  select o.id,o.store_id,mm.user_id into v_order,v_store,v_owner
    from public.food_orders o
    join public.food_stores s on s.id=o.store_id
    join public.merchant_memberships mm
      on mm.merchant_account_id=s.merchant_account_id
     and mm.active and mm.role='owner'
    where o.order_number='WF000005' limit 1;
  select id into v_other from public.food_stores where id<>v_store limit 1;
  if v_order is null or v_store is null or v_owner is null or v_other is null
   or exists(select 1 from public.food_gp_store_rates where store_id=v_store)
   or exists(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
   or exists(select 1 from public.food_gp_admin_allowlist where user_id=v_owner)
  then raise exception 'QA fixtures not clean';end if;

  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  begin
    perform public.admin_food_finance_buckets_v2_qa(v_from,v_to,'day',null);
    raise exception 'Owner gained unallowlisted admin v2';
  exception when sqlstate '42501' then null;end;
  begin
    perform public.merchant_food_finance_buckets_v2_qa(v_other,v_from,v_to,'day');
    raise exception 'Owner gained cross-store v2 totals';
  exception when sqlstate '42501' then null;end;
  begin
    perform public.merchant_food_finance_order_details_v2_qa(v_other,v_order);
    raise exception 'Owner gained cross-store v2 detail';
  exception when sqlstate '42501' then null;end;

  insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
    values(v_store,750,v_owner);
  v_r:=public.food_gp_capture_order_qa(v_order);
  if v_r->>'status'<>'snapshotted' then raise exception 'GP fixture failed %',v_r;end if;
  v_r:=public.food_finance_capture_order_qa(v_order);
  if v_r->>'status'<>'projected' then raise exception 'Finance fixture failed %',v_r;end if;
  v_r:=public.food_finance_append_refund_qa(v_order,'V2-QA-FIRST',3333,0,'Reporting QA partial one');
  if v_r->>'status'<>'adjusted' then raise exception 'Refund fixture 1 failed';end if;
  v_r:=public.food_finance_append_refund_qa(v_order,'V2-QA-SECOND',1667,0,'Reporting QA partial two');
  if v_r->>'status'<>'adjusted' then raise exception 'Refund fixture 2 failed';end if;

  v_b:=public.merchant_food_finance_buckets_v2_qa(v_store,v_from,v_to,'day');
  if v_b->>'granularity'<>'day' or v_b->>'timezone'<>'Asia/Bangkok'
    or v_b->>'mode'<>'simulation_only'
    or (select coalesce(sum((j->>'projection_count')::bigint),0)
         from jsonb_array_elements(v_b->'buckets') j)<>1
    or (select coalesce(sum((j->>'refund_event_count')::bigint),0)
         from jsonb_array_elements(v_b->'buckets') j)<>2
    or (select coalesce(sum((j->>'estimated_platform_gp_satang')::bigint),0)
         from jsonb_array_elements(v_b->'buckets') j)<>375
    or (select coalesce(sum((j->>'simulated_gp_reversal_satang')::bigint),0)
         from jsonb_array_elements(v_b->'buckets') j)<>375
    or v_b->'merchant_net_payout_satang'<>'null'::jsonb
  then raise exception 'Finance v2 day buckets failed %',v_b;end if;

  v_month:=public.merchant_food_finance_buckets_v2_qa(
    v_store,v_from,v_to,'month');
  if v_month->>'granularity'<>'month'
    or (select coalesce(sum((j->>'projection_count')::bigint),0)
       from jsonb_array_elements(v_month->'buckets') j)<>1
    or (select coalesce(sum((j->>'refund_event_count')::bigint),0)
       from jsonb_array_elements(v_month->'buckets') j)<>2
    or (select coalesce(sum((j->>'period_gp_projection_less_reversals_satang')::bigint),0)
       from jsonb_array_elements(v_month->'buckets') j)<>0
  then raise exception 'Finance v2 month buckets failed %',v_month;end if;

  v_d:=public.merchant_food_finance_order_details_v2_qa(v_store,v_order);
  if v_d->>'status'<>'projected'
    or (v_d->>'refund_event_count')::bigint<>2
    or (v_d->>'projected_customer_paid_satang')::bigint<>5000
    or (v_d->>'simulated_customer_refunded_satang')::bigint<>5000
    or (v_d->>'simulated_gp_reversal_satang')::bigint<>375
    or (v_d->>'simulated_remaining_gp_satang')::bigint<>0
    or jsonb_array_length(v_d->'refund_events')<>2
    or v_d::text like '%stripe_payment_intent_id%'
    or v_d::text like '%recipient_phone%'
    or v_d->'stripe_processing_fee_satang'<>'null'::jsonb
  then raise exception 'Finance v2 order detail failed %',v_d;end if;

  begin
    perform public.merchant_food_finance_buckets_v2_qa(v_store,v_from,v_to,'year');
    raise exception 'Invalid granularity accepted';
  exception when sqlstate '22023' then null;end;
  begin
    perform public.merchant_food_finance_buckets_v2_qa(
      v_store,v_from,v_from+interval '367 days','day');
    raise exception 'Oversized window accepted';
  exception when sqlstate '22023' then null;end;
  begin
    perform public.merchant_food_finance_buckets_v2_qa(
      v_store,v_to,v_from,'day');
    raise exception 'Invalid window ordering accepted';
  exception when sqlstate '22023' then null;end;

  if has_function_privilege('authenticated',
    'wynos_finance_qa_private.food_finance_buckets_core_v2_qa(timestamptz,timestamptz,uuid,text)','EXECUTE')
    or has_function_privilege('anon',
    'public.merchant_food_finance_buckets_v2_qa(uuid,timestamptz,timestamptz,text)','EXECUTE')
    or has_function_privilege('anon',
    'public.admin_food_finance_order_details_v2_qa(uuid)','EXECUTE')
  then raise exception 'Unprivileged Finance v2 execution granted';end if;

  insert into public.food_gp_admin_allowlist(user_id,note)
    values(v_owner,'Finance v2 regression rollback only');
  v_r:=public.admin_food_finance_buckets_v2_qa(v_from,v_to,'day',null);
  if v_r->'buckets' is distinct from v_b->'buckets' then
    raise exception 'QA Admin and Merchant v2 bucket totals mismatch';end if;
  v_r:=public.admin_food_finance_order_details_v2_qa(v_order);
  if v_r->'refund_events' is distinct from v_d->'refund_events' then
    raise exception 'QA Admin and Merchant v2 details mismatch';end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin
    perform public.merchant_food_finance_order_details_v2_qa(v_store,v_order);
    raise exception 'Unrelated user read merchant Finance v2 order';
  exception when sqlstate '42501' then null;end;
  begin
    perform public.admin_food_finance_order_details_v2_qa(v_order);
    raise exception 'Unrelated user read admin Finance v2 order';
  exception when sqlstate '42501' then null;end;

  if (select payment_status from public.food_orders where id=v_order)<>'paid'
   or (select refund_status from public.food_orders where id=v_order)<>'none' then
    raise exception 'QA payment mutated';end if;
END $$;
ROLLBACK;