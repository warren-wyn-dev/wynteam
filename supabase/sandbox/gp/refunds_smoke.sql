-- WYNOS Finance QA refund-adjustment regression. QA PROJECT ONLY:
-- pcatuxtenluqzjzzwsvl; uses real test-mode PromptPay WF000005 ONLY inside
-- BEGIN/ROLLBACK. NO Stripe requests, GP rate persisted or actual refunds.
BEGIN;
DO $$
DECLARE
  v_order uuid;
  v_store uuid;
  v_actor uuid;
  v_result jsonb;
  v_replay jsonb;
  v_first public.food_finance_refund_adjustments_qa%rowtype;
  v_full public.food_finance_refund_adjustments_qa%rowtype;
  v_sum bigint;
  v_allowed jsonb;
  v_calc jsonb;
BEGIN
  SELECT id,store_id INTO v_order,v_store FROM public.food_orders
    WHERE order_number='WF000005';
  SELECT id INTO v_actor FROM auth.users ORDER BY created_at LIMIT 1;
  IF v_order IS NULL OR v_store IS NULL OR v_actor IS NULL THEN
    RAISE EXCEPTION 'QA fixture missing: never switch to Production';
  END IF;
  IF EXISTS(SELECT 1 FROM public.food_gp_store_rates WHERE store_id=v_store)
    OR EXISTS(SELECT 1 FROM public.food_finance_order_projections_qa WHERE order_id=v_order)
    OR EXISTS(SELECT 1 FROM public.food_finance_refund_adjustments_qa WHERE order_id=v_order) THEN
    RAISE EXCEPTION 'QA fixture prepopulated: refuse overwriting existing finance state';
  END IF;

  v_result:=public.food_finance_append_refund_qa(
    v_order,'QA-REF-UNCONFIGURED',100,0,'No finance projection expected');
  IF v_result->>'status' <> 'finance_projection_not_available' THEN
    RAISE EXCEPTION 'Expected absence of finance projection';
  END IF;

  -- Rate exists only in this transaction and is erased by ROLLBACK.
  INSERT INTO public.food_gp_store_rates(store_id,rate_bps,updated_by)
    VALUES(v_store,750,v_actor);
  v_result:=public.food_gp_capture_order_qa(v_order);
  IF v_result->>'status'<>'snapshotted' THEN
    RAISE EXCEPTION 'GP test snapshot creation failed: %',v_result;
  END IF;
  v_result:=public.food_finance_capture_order_qa(v_order);
  IF v_result->>'status'<>'projected' THEN
    RAISE EXCEPTION 'Finance test projection failed: %',v_result;
  END IF;

  v_result:=public.food_finance_append_refund_qa(
    v_order,'QA-REF-FIRST',3333,0,'Hypothetical partial food refund one');
  IF v_result->>'status'<>'adjusted'
    OR (v_result->'adjustment'->>'refund_kind')<>'partial'
    OR (v_result->'adjustment'->>'estimated_platform_gp_reversal_satang')::bigint<>250
    OR (v_result->'adjustment'->>'estimated_store_food_reversal_satang')::bigint<>3083
    OR (v_result->'adjustment'->>'remaining_customer_paid_satang')::bigint<>1667
    OR (v_result->>'customer_book_balance_satang')::bigint<>0
    OR (v_result->>'food_share_book_balance_satang')::bigint<>0 THEN
    RAISE EXCEPTION 'First refund split / book balances incorrect: %',v_result;
  END IF;
  SELECT * INTO v_first FROM public.food_finance_refund_adjustments_qa
    WHERE order_id=v_order AND simulation_key='QA-REF-FIRST';

  v_replay:=public.food_finance_append_refund_qa(
    v_order,'QA-REF-FIRST',3333,0,'Hypothetical partial food refund one');
  IF v_replay->>'status'<>'already_adjusted'
    OR (v_replay->'adjustment'->>'id')<>v_first.id::text THEN
    RAISE EXCEPTION 'Idempotent replay failed';
  END IF;
  BEGIN
    PERFORM public.food_finance_append_refund_qa(
      v_order,'QA-REF-FIRST',3332,0,'Hypothetical partial food refund one');
    RAISE EXCEPTION 'Mismatched replay was accepted';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'simulation key replay payload mismatch' THEN RAISE; END IF;
  END;
  BEGIN
    PERFORM public.food_finance_append_refund_qa(
      v_order,'QA-REF-EXCESS',1668,0,'Prevent exceeding original food amount');
    RAISE EXCEPTION 'Overrefund was accepted';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'refund exceeds remaining food or delivery' THEN RAISE; END IF;
  END;

  v_result:=public.food_finance_append_refund_qa(
    v_order,'QA-REF-SECOND',1667,0,'Hypothetical remaining food refund');
  IF v_result->>'status'<>'adjusted'
    OR (v_result->'adjustment'->>'refund_kind')<>'full'
    OR (v_result->'adjustment'->>'estimated_platform_gp_reversal_satang')::bigint<>125
    OR (v_result->'adjustment'->>'estimated_store_food_reversal_satang')::bigint<>1542
    OR (v_result->'adjustment'->>'remaining_customer_paid_satang')::bigint<>0
    OR (v_result->'adjustment'->>'remaining_estimated_gp_satang')::bigint<>0
    OR (v_result->'adjustment'->>'remaining_estimated_store_food_satang')::bigint<>0 THEN
    RAISE EXCEPTION 'Final refund should be full, with exact cumulative reversal: %',v_result;
  END IF;
  SELECT * INTO v_full FROM public.food_finance_refund_adjustments_qa
    WHERE order_id=v_order AND simulation_key='QA-REF-SECOND';

  IF (SELECT count(*) FROM public.food_finance_refund_adjustments_qa WHERE order_id=v_order)<>2
    OR (SELECT count(*) FROM public.food_finance_refund_lines_qa
      WHERE adjustment_id IN (v_first.id,v_full.id))<>12 THEN
    RAISE EXCEPTION 'Expected 2 append-only events, 12 balanced reconciliation lines';
  END IF;
  FOR v_sum IN
    SELECT sum(signed_amount_satang)
      FROM public.food_finance_refund_lines_qa l
      WHERE adjustment_id IN (v_first.id,v_full.id)
      GROUP BY adjustment_id,book
  LOOP
    IF v_sum<>0 THEN RAISE EXCEPTION 'One of the refund books is unbalanced'; END IF;
  END LOOP;
  IF (SELECT sum(estimated_platform_gp_reversal_satang)
      FROM public.food_finance_refund_adjustments_qa WHERE order_id=v_order)<>375
    OR (SELECT sum(customer_refund_satang)
      FROM public.food_finance_refund_adjustments_qa WHERE order_id=v_order)<>5000 THEN
    RAISE EXCEPTION 'Cumulative GP reversal or customer refund mismatch';
  END IF;

  BEGIN
    PERFORM public.food_finance_append_refund_qa(
      v_order,'QA-REF-THIRD',1,0,'Do not overrefund after full refund');
    RAISE EXCEPTION 'Refund after full refund was accepted';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM<>'refund exceeds remaining food or delivery' THEN RAISE; END IF;
  END;

  -- Neither updated/deleted historical adjustments nor their lines.
  BEGIN
    UPDATE public.food_finance_refund_adjustments_qa
      SET reason='MUTATED' WHERE id=v_first.id;
    RAISE EXCEPTION 'Refund event UPDATE succeeded';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;
  BEGIN
    DELETE FROM public.food_finance_refund_adjustments_qa WHERE id=v_first.id;
    RAISE EXCEPTION 'Refund event DELETE succeeded';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;
  BEGIN
    UPDATE public.food_finance_refund_lines_qa
      SET signed_amount_satang=0 WHERE adjustment_id=v_first.id;
    RAISE EXCEPTION 'Refund line UPDATE succeeded';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;

  IF has_function_privilege('anon',
     'public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)','EXECUTE')
    OR has_function_privilege('authenticated',
     'public.food_finance_append_refund_qa(uuid,text,bigint,bigint,text)','EXECUTE')
    OR has_table_privilege('authenticated',
     'public.food_finance_refund_adjustments_qa','SELECT')
    OR has_table_privilege('authenticated',
     'public.food_finance_refund_lines_qa','INSERT') THEN
    RAISE EXCEPTION 'Unauthorized refund adjustment access';
  END IF;

  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  BEGIN
    PERFORM public.admin_food_finance_refunds_qa(v_order);
    RAISE EXCEPTION 'Non-allowlisted user was granted access';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
  INSERT INTO public.food_gp_admin_allowlist(user_id,note)
    VALUES(v_actor,'Refund regression transaction only');
  v_allowed:=public.admin_food_finance_refunds_qa(v_order);
  IF (v_allowed->>'refund_adjustments_count')::int<>2
    OR jsonb_array_length(v_allowed->'adjustments')<>2
    OR (v_allowed->>'actual_customer_refunded_satang')::int<>0 THEN
    RAISE EXCEPTION 'Allowlisted read-only refund audit fails: %',v_allowed;
  END IF;

  -- No actual Stripe/API refund or payment mutation, ever.
  IF (SELECT payment_status FROM public.food_orders WHERE id=v_order)<>'paid'
    OR (SELECT refund_status FROM public.food_orders WHERE id=v_order)<>'none'
    OR (SELECT status FROM public.food_stripe_payments WHERE order_id=v_order)<>'paid'
    OR (SELECT count(*) FROM public.food_finance_refund_adjustments_qa
      WHERE order_id=v_order AND
       (actual_customer_refunded_satang<>0
        OR actual_platform_gp_reversed_satang<>0 OR stripe_refund_id IS NOT NULL
        OR stripe_fee_refund_satang IS NOT NULL))<>0 THEN
    RAISE EXCEPTION 'Simulation mutated payment or asserted real refund/fee';
  END IF;

  -- Pure maths for a food+delivery scenario even if QA order delivery is 0.
  v_calc:=public.food_finance_refund_math_qa(10000,2000,1000,3000,1000,7000,1000);
  IF (v_calc->>'customer_refund_satang')::bigint<>8000
    OR (v_calc->>'estimated_platform_gp_reversal_satang')::bigint<>700
    OR (v_calc->>'remaining_customer_paid_satang')::bigint<>0 THEN
    RAISE EXCEPTION 'Hypothetical delivery/food full refund calculations wrong';
  END IF;

  -- Split a 2-satang food refund at 50%: 1 GP satang then 0.
  IF (public.food_finance_refund_math_qa(2,0,5000,0,0,1,0)
        ->>'estimated_platform_gp_reversal_satang')::int<>1
    OR (public.food_finance_refund_math_qa(2,0,5000,1,0,1,0)
        ->>'estimated_platform_gp_reversal_satang')::int<>0 THEN
    RAISE EXCEPTION 'Cumulative rounding could over-reverse GP';
  END IF;
  RAISE NOTICE 'PASS: QA refunds partial/full, no projection, dedupe/conflict, cap, exact cumulative rounding, frozen append-only, two books, RLS/admin, delivery, no real money';
END;
$$;
ROLLBACK;
