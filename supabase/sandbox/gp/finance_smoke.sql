-- WYNOS Finance & Revenue Sharing QA transaction smoke.
-- ONLY Supabase QA pcatuxtenluqzjzzwsvl. All example rates/rows ROLLBACK.
-- Existing Stripe test order WF000005 must remain paid, untouched on commit.
BEGIN;

DO $$
DECLARE
  v_order uuid;
  v_secondary uuid;
  v_store uuid;
  v_actor uuid;
  v_status jsonb;
  v_projection public.food_finance_order_projections_qa%rowtype;
  v_customer_total bigint;
  v_share_total bigint;
  v_admin_read jsonb;
BEGIN
  SELECT id,store_id INTO v_order,v_store FROM public.food_orders
    WHERE order_number='WF000005';
  SELECT id INTO v_secondary FROM public.food_orders
    WHERE order_number='WF000003';
  SELECT id INTO v_actor FROM auth.users ORDER BY created_at LIMIT 1;
  IF v_order IS NULL OR v_store IS NULL OR v_secondary IS NULL
     OR v_actor IS NULL THEN
    RAISE EXCEPTION 'QA fixtures missing; do not run against production';
  END IF;

  IF EXISTS(select 1 from public.food_gp_store_rates where store_id=v_store)
    OR EXISTS(select 1 from public.food_gp_order_snapshots where order_id=v_order)
    OR EXISTS(select 1 from public.food_finance_order_projections_qa where order_id=v_order)
    OR EXISTS(select 1 from public.food_finance_projection_lines_qa where order_id=v_order)
    THEN raise exception 'Preexisting QA projections/rates: refuse overwrite';
  END IF;

  v_status := public.food_finance_capture_order_qa(v_order);
  IF v_status->>'status' <> 'gp_snapshot_not_available' THEN
    RAISE EXCEPTION 'Missing GP snapshot must not generate a finance projection';
  END IF;

  insert into public.food_gp_store_rates (store_id,rate_bps,updated_by)
    values (v_store,1000,v_actor);

  v_status := public.food_gp_capture_order_qa(v_order);
  IF v_status->>'status' <> 'snapshotted' THEN
    RAISE EXCEPTION 'GP snapshot creation failed: %',v_status;
  END IF;

  v_status := public.food_finance_capture_order_qa(v_order);
  IF v_status->>'status' <> 'projected'
    OR (v_status->>'customer_book_balance_satang')::bigint <> 0
    OR (v_status->>'food_share_book_balance_satang')::bigint <> 0 THEN
    RAISE EXCEPTION 'Finance projection/reconciliation failed: %',v_status;
  END IF;
  IF (public.food_finance_capture_order_qa(v_order)->>'status')
     <> 'already_projected' THEN
    RAISE EXCEPTION 'Finance duplicate capture must be idempotent';
  END IF;
  SELECT * INTO v_projection from public.food_finance_order_projections_qa
    WHERE order_id=v_order;
  IF v_projection.customer_paid_satang <> 5000
    OR v_projection.food_gross_satang <> 5000
    OR v_projection.estimated_platform_gp_satang <> 500
    OR v_projection.estimated_store_food_satang <> 4500
    OR v_projection.gp_rate_bps <> 1000
    OR v_projection.stripe_processing_fee_satang IS NOT NULL
    OR v_projection.stripe_fee_status <> 'unknown'
    OR v_projection.merchant_payout_status <> 'not_reconciled'
    OR v_projection.actual_platform_transfer_satang <> 0
    OR v_projection.actually_collected_gp_satang <> 0
    OR v_projection.mode <> 'simulation_only' THEN
    RAISE EXCEPTION 'Unexpected finance amounts/collection/unknown-fee status';
  END IF;
  IF (select count(*) from public.food_finance_projection_lines_qa
    WHERE order_id=v_order) <> 7 THEN
    RAISE EXCEPTION 'Expected exactly seven reconciliation lines';
  END IF;
  SELECT sum(signed_amount_satang) INTO v_customer_total
    FROM public.food_finance_projection_lines_qa
    WHERE order_id=v_order and book='customer_reconciliation';
  SELECT sum(signed_amount_satang) INTO v_share_total
    FROM public.food_finance_projection_lines_qa
    WHERE order_id=v_order and book='food_share_projection';
  IF v_customer_total <> 0 or v_share_total <> 0 THEN
    RAISE EXCEPTION 'Finance reconciliation books unbalanced';
  END IF;

  UPDATE public.food_gp_store_rates SET rate_bps=2000
    WHERE store_id=v_store;
  IF (select gp_rate_bps from public.food_finance_order_projections_qa
      where order_id=v_order) <> 1000 THEN
    RAISE EXCEPTION 'Finance allocation must freeze original rate';
  END IF;

  BEGIN
    UPDATE public.food_finance_order_projections_qa
      SET gp_rate_bps=2000 WHERE order_id=v_order;
    RAISE EXCEPTION 'Mutating immutable finance projection wrongly permitted';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;
  BEGIN
    DELETE FROM public.food_finance_projection_lines_qa where order_id=v_order;
    RAISE EXCEPTION 'Deleting immutable finance lines wrongly permitted';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;
  BEGIN
    UPDATE public.food_finance_projection_lines_qa SET signed_amount_satang=0
      WHERE order_id=v_order;
    RAISE EXCEPTION 'Updating immutable finance lines wrongly permitted';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL;
  END;

  -- A legacy paid fixture without explicit PromptPay payment_method must NOT
  -- be accepted as PromptPay merely because payment_status='paid'.
  v_status := public.food_gp_capture_order_qa(v_secondary);
  IF v_status->>'status' <> 'snapshotted' THEN
    RAISE EXCEPTION 'Secondary QA GP snapshot fixture unavailable: %',v_status;
  END IF;
  v_status := public.food_finance_capture_order_qa(v_secondary);
  IF v_status->>'status' <> 'ineligible_payment' THEN
    RAISE EXCEPTION 'Non-PromptPay/unknown payment method must be rejected: %',v_status;
  END IF;

  IF has_table_privilege('authenticated',
      'public.food_finance_order_projections_qa','SELECT')
    OR has_table_privilege('authenticated',
      'public.food_finance_projection_lines_qa','INSERT')
    OR has_function_privilege('anon',
      'public.food_finance_capture_order_qa(uuid)','EXECUTE')
    OR has_function_privilege('authenticated',
      'public.food_finance_capture_order_qa(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'Finance projections incorrectly exposed to clients';
  END IF;

  PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
  BEGIN
    PERFORM public.admin_food_finance_order_qa(v_order);
    RAISE EXCEPTION 'Unapproved user could access WYNOS Finance';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
  INSERT INTO public.food_gp_admin_allowlist (user_id,note)
    VALUES (v_actor,'Transaction-only authorized admin read test');
  v_admin_read := public.admin_food_finance_order_qa(v_order);
  IF (v_admin_read->>'exists')::boolean IS DISTINCT FROM true
    OR jsonb_array_length(v_admin_read->'lines') <> 7 THEN
    RAISE EXCEPTION 'Authorized read-only admin projection failed';
  END IF;

  IF (SELECT payment_status FROM public.food_orders where id=v_order) <> 'paid'
    OR (SELECT status FROM public.food_stripe_payments where order_id=v_order)
       <> 'paid' THEN
    RAISE EXCEPTION 'Existing Stripe PromptPay status changed';
  END IF;
  RAISE NOTICE 'PASS Finance QA: no-rate, two balanced books, GP allocation frozen, duplicate calls, immutable ledger, unknown Stripe fee, PromptPay-only, RLS/admin, no money moved';
END;
$$;
ROLLBACK;
