-- Refund edge-case regression. QA project pcatuxtenluqzjzzwsvl ONLY.
-- All changes enclosed in BEGIN/ROLLBACK; never call Stripe/refund APIs.
BEGIN;
DO $$
DECLARE
  v_order uuid;
  v_other uuid;
  v_store uuid;
  v_actor uuid;
  v_r jsonb;
  v_before_rate integer;
  v_snap_rate integer;
  v_refund_count integer;
BEGIN
  select id,store_id into v_order,v_store
    from public.food_orders where order_number='WF000005';
  select id into v_other from public.food_orders where order_number='WF000003';
  select id into v_actor from auth.users order by created_at limit 1;
  if v_order is null or v_other is null or v_actor is null
     or exists(select 1 from public.food_gp_store_rates where store_id=v_store)
     or exists(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
     or exists(select 1 from public.food_finance_refund_adjustments_qa where order_id=v_order)
  then raise exception 'QA fixture missing or prepopulated; abort test'; end if;

  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-REF-ZERO',0,0,'Zero disallowed');
    raise exception 'Zero refund was accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'invalid refund amount' then raise; end if;
  end;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-REF-NEG',-1,0,'Negative disallowed');
    raise exception 'Negative refund was accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'invalid refund amount' then raise; end if;
  end;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-REF-NEGDEL',1,-1,'Negative delivery disallowed');
    raise exception 'Negative delivery was accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'invalid refund amount' then raise; end if;
  end;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-REF-NULL',null,0,'Null refund disallowed');
    raise exception 'Null refund was accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'invalid refund amount' then raise; end if;
  end;
  begin
    perform public.food_finance_refund_math_qa(5000,0,750,0,0,0,0);
    raise exception 'Pure refund calculator allowed zero refund';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'refund exceeds remaining food or delivery' then raise; end if;
  end;
  begin
    perform public.food_finance_refund_math_qa(5000,0,750,0,0,-1,0);
    raise exception 'Pure refund calculator allowed negative amount';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'invalid QA refund calculator arguments' then raise; end if;
  end;
  if (public.food_finance_refund_math_qa(2,0,5000,0,0,1,0)
        ->>'estimated_platform_gp_reversal_satang')::integer<>1
     or (public.food_finance_refund_math_qa(2,0,5000,1,0,1,0)
        ->>'estimated_platform_gp_reversal_satang')::integer<>0
  then raise exception '1 satang GP reversal rounding failed'; end if;
  begin
    perform public.food_finance_refund_math_qa(5000,0,750,4999,0,2,0);
    raise exception 'Pure math allowed cumulative overrefund';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'refund exceeds remaining food or delivery' then raise; end if;
  end;

  insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
    values(v_store,750,v_actor);
  v_r:=public.food_gp_capture_order_qa(v_order);
  if v_r->>'status'<>'snapshotted' then raise exception 'Snapshot fixture failed'; end if;
  v_r:=public.food_finance_capture_order_qa(v_order);
  if v_r->>'status'<>'projected' then raise exception 'Projection fixture failed'; end if;
  v_r:=public.food_finance_append_refund_qa(v_order,'EDGE-PARTIAL-01',1,0,'One satang refund');
  if v_r->>'status'<>'adjusted' or
    (v_r->'adjustment'->>'estimated_platform_gp_reversal_satang')::int<>0
  then raise exception 'One satang first refund failed: %',v_r; end if;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-PARTIAL-01',1,0,'Different reason mismatch');
    raise exception 'Changed replay reason accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'simulation key replay payload mismatch' then raise; end if;
  end;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-PARTIAL-01',2,0,'One satang refund');
    raise exception 'Changed replay amount accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'simulation key replay payload mismatch' then raise; end if;
  end;

  -- Rate change is only inside this rollback transaction; the frozen projection
  -- (not the new store draft rate) must drive the second refund.
  update public.food_gp_store_rates set rate_bps=2000 where store_id=v_store;
  select rate_bps into v_snap_rate from public.food_gp_order_snapshots where order_id=v_order;
  if v_snap_rate<>750 or
      (select gp_rate_bps from public.food_finance_order_projections_qa
       where order_id=v_order)<>750 then
    raise exception 'Existing rate snapshot drifted';
  end if;

  -- Temporary mock refunded status; restore before ROLLBACK and never call API.
  update public.food_orders set refund_status='refunded' where id=v_order;
  v_r:=public.food_finance_append_refund_qa(v_order,'EDGE-PAID-REFUNDED',2,0,'Already externally refunded');
  if v_r->>'status'<>'payment_state_not_eligible' then
    raise exception 'Previously refunded order accepted: %',v_r;
  end if;
  update public.food_orders set refund_status='none' where id=v_order;

  v_r:=public.food_finance_append_refund_qa(v_order,'EDGE-PARTIAL-02',4999,0,'Last remaining satang refund');
  if v_r->>'status'<>'adjusted'
    or (v_r->'adjustment'->>'refund_kind')<>'full'
    or (v_r->'adjustment'->>'cumulative_gp_reversal_satang')::integer<>375
    or (v_r->'adjustment'->>'remaining_customer_paid_satang')::int<>0
  then raise exception 'Cumulative final GP reversal not frozen or misrounded: %',v_r; end if;
  begin
    perform public.food_finance_append_refund_qa(v_order,'EDGE-PARTIAL-03',1,0,'Refund after full disallowed');
    raise exception 'Overrefund after full was accepted';
  exception when sqlstate 'P0001' then
    if sqlerrm<>'refund exceeds remaining food or delivery' then raise; end if;
  end;

  v_r:=public.food_gp_capture_order_qa(v_other);
  if v_r->>'status'<>'snapshotted' then
    raise exception 'Secondary snapshot fixture failed: %',v_r;
  end if;
  v_r:=public.food_finance_capture_order_qa(v_other);
  if v_r->>'status'<>'ineligible_payment' then
    raise exception 'Non-PromptPay order incorrectly projected: %',v_r;
  end if;
  select count(*) into v_refund_count
   from public.food_finance_refund_adjustments_qa where order_id=v_order;
  if v_refund_count<>2
    or (select sum(estimated_platform_gp_reversal_satang)
        from public.food_finance_refund_adjustments_qa where order_id=v_order)<>375
    or (select refund_status from public.food_orders where id=v_order)<>'none'
    or (select payment_status from public.food_orders where id=v_order)<>'paid'
    or (select status from public.food_stripe_payments where order_id=v_order)<>'paid' then
    raise exception 'Refund count, cumulative GP or payment state mismatch';
  end if;
  raise notice 'PASS refund edges: zero, negative, null, key mismatch amount/reason, frozen rate, already refunded, fully refunded, non PromptPay, one-satang cumulative and unchanged payment';
END;
$$;
ROLLBACK;
