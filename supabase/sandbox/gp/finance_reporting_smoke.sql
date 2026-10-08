-- WYNOS Finance Reporting QA regression; pcatuxtenluqzjzzwsvl ONLY.
-- All rates, allowlist, events, and projections are temporary and ROLLBACK.
-- Never invoke Stripe, refund gateway, webhooks, payouts or Production.
BEGIN;
DO $$
DECLARE
  v_order uuid;
  v_store uuid;
  v_other_store uuid;
  v_owner uuid;
  v_r jsonb;
  v_m jsonb;
  v_events jsonb;
  v_from timestamptz := now()-interval '1 day';
  v_to timestamptz := now()+interval '1 day';
  v_count bigint;
BEGIN
  select o.id,o.store_id,mm.user_id
  into v_order,v_store,v_owner
  from public.food_orders o
  join public.food_stores s on s.id=o.store_id
  join public.merchant_memberships mm on mm.merchant_account_id=s.merchant_account_id
     and mm.active and mm.role='owner'
  where o.order_number='WF000005'
  limit 1;
  select id into v_other_store from public.food_stores where id<>v_store limit 1;
  if v_order is null or v_owner is null or v_other_store is null then
    raise exception 'QA fixtures missing; never attempt on Production';
  end if;
  if exists (select 1 from public.food_gp_store_rates where store_id=v_store)
     or exists (select 1 from public.food_finance_order_projections_qa where order_id=v_order)
     or exists (select 1 from public.food_gp_admin_allowlist where user_id=v_owner) then
    raise exception 'Refuse to overwrite pre-existing QA GP/Finance/admin state';
  end if;

  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  begin
    perform public.admin_food_finance_report_qa(v_from,v_to,null);
    raise exception 'Nonallowlisted user read admin reporting';
  exception when SQLSTATE '42501' then null;
  end;
  begin
    perform public.merchant_food_finance_report_qa(v_other_store,v_from,v_to);
    raise exception 'Owner of another store read private merchant reporting';
  exception when SQLSTATE '42501' then null;
  end;
  begin
    perform public.merchant_food_finance_events_qa(v_other_store,v_from,v_to);
    raise exception 'Owner of another store read private events';
  exception when SQLSTATE '42501' then null;
  end;

  insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
    values(v_store,750,v_owner);
  v_r:=public.food_gp_capture_order_qa(v_order);
  if v_r->>'status'<>'snapshotted' then
    raise exception 'GP snapshot fixture failed: %',v_r;
  end if;
  v_r:=public.food_finance_capture_order_qa(v_order);
  if v_r->>'status'<>'projected' then
    raise exception 'Projection fixture failed: %',v_r;
  end if;

  v_r:=public.food_finance_append_refund_qa(v_order,'REPORT-QA-FIRST',3333,0,'First simulated reversal');
  if v_r->>'status'<>'adjusted' then
    raise exception 'First QA refund failed %',v_r;
  end if;
  v_r:=public.food_finance_append_refund_qa(v_order,'REPORT-QA-SECOND',1667,0,'Second simulated reversal');
  if v_r->>'status'<>'adjusted' then
    raise exception 'Second QA refund failed %',v_r;
  end if;

  v_m:=public.merchant_food_finance_report_qa(v_store,v_from,v_to);
  if (v_m->'totals'->>'projection_count')::bigint<>1
     or (v_m->'totals'->>'refund_event_count')::bigint<>2
     or (v_m->'totals'->>'projected_customer_paid_satang')::bigint<>5000
     or (v_m->'totals'->>'estimated_platform_gp_satang')::bigint<>375
     or (v_m->'totals'->>'estimated_merchant_food_satang')::bigint<>4625
     or (v_m->'totals'->>'simulated_customer_refund_satang')::bigint<>5000
     or (v_m->'totals'->>'simulated_gp_reversal_satang')::bigint<>375
     or (v_m->'totals'->>'simulated_merchant_food_reversal_satang')::bigint<>4625
     or (v_m->'totals'->>'period_gp_projection_less_reversals_satang')::bigint<>0
     or jsonb_array_length(v_m->'stores')<>1
     or v_m->>'stripe_fee_status'<>'unknown'
     or v_m->>'merchant_payout_status'<>'not_reconciled'
     or v_m->'merchant_net_payout_satang'<>'null'::jsonb then
    raise exception 'Merchant reporting totals/unknown payout incorrect: %',v_m;
  end if;
  v_events:=public.merchant_food_finance_events_qa(v_store,v_from,v_to,2,0);
  if (v_events->>'total_events')::int<>3
     or jsonb_array_length(v_events->'events')<>2
     or v_events::text like '%stripe_payment_intent_id%'
     or v_events::text like '%recipient_phone%' then
    raise exception 'Merchant event pagination/privacy incorrect';
  end if;
  v_events:=public.merchant_food_finance_events_qa(v_store,v_from,v_to,2,2);
  if jsonb_array_length(v_events->'events')<>1 then
    raise exception 'Page 2 should contain one event';
  end if;

  insert into public.food_gp_admin_allowlist(user_id,note)
    values(v_owner,'Reporting regression rollback only');
  v_r:=public.admin_food_finance_report_qa(v_from,v_to,null);
  if v_r->'totals' is distinct from v_m->'totals' then
    raise exception 'Admin and merchant totals diverge for single store';
  end if;
  v_events:=public.admin_food_finance_events_qa(v_from,v_to,null,50,0);
  if (v_events->>'total_events')::int<>3
      or jsonb_array_length(v_events->'events')<>3 then
    raise exception 'Admin full event ledger missing events';
  end if;

  v_r:=public.admin_food_finance_report_qa('2020-01-01'::timestamptz,'2020-01-02'::timestamptz,null);
  if (v_r->'totals'->>'projection_count')::int<>0
     or jsonb_array_length(v_r->'stores')<>0 then
    raise exception 'Empty date window should have no events';
  end if;
  begin
    perform public.merchant_food_finance_report_qa(v_store,v_to,v_from);
    raise exception 'Reversed date range accepted';
  exception when SQLSTATE '22023' then null;
  end;
  begin
    perform public.merchant_food_finance_events_qa(v_store,v_from,v_to,101,0);
    raise exception 'Oversized page accepted';
  exception when SQLSTATE '22023' then null;
  end;
  if has_function_privilege('anon',
        'public.admin_food_finance_report_qa(timestamptz,timestamptz,uuid)','EXECUTE')
    or has_function_privilege('anon',
        'public.merchant_food_finance_report_qa(uuid,timestamptz,timestamptz)','EXECUTE')
    or has_function_privilege('authenticated',
        'wynos_finance_qa_private.food_finance_report_core_qa(timestamptz,timestamptz,uuid)','EXECUTE')
    or has_function_privilege('authenticated',
        'wynos_finance_qa_private.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)','EXECUTE') then
    raise exception 'Reporting RPC core/client grants unsafe';
  end if;

  perform set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
  begin
    perform public.merchant_food_finance_report_qa(v_store,v_from,v_to);
    raise exception 'Ordinary user could see store financial totals';
  exception when SQLSTATE '42501' then null;
  end;
  begin
    perform public.admin_food_finance_events_qa(v_from,v_to,null);
    raise exception 'Ordinary user could see admin events';
  exception when SQLSTATE '42501' then null;
  end;

  if (select payment_status from public.food_orders where id=v_order)<>'paid'
    or (select refund_status from public.food_orders where id=v_order)<>'none'
    or (select status from public.food_stripe_payments where order_id=v_order)<>'paid' then
    raise exception 'Existing payment was mutated';
  end if;
  raise notice 'PASS reporting QA: accurate 1 order/2 refunds, pagination, owner only, cross-store denial, allowlisted admin, unknown fees/net, no PII, date validation and payment unchanged';
END;
$$;
ROLLBACK;
