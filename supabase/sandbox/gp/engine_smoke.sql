-- WYNOS GP Engine smoke test. QA ONLY (pcatuxtenluqzjzzwsvl).
-- Execute using Supabase SQL editor/DB admin on QA only.
-- Requires the existing PromptPay test order WF000005 and an auth test user.
-- All example GP rates and snapshots are transaction-local; ALWAYS ROLLBACK.
BEGIN;

DO $$
DECLARE
  v_order uuid;
  v_store uuid;
  v_actor uuid;
  v_first jsonb;
  v_again jsonb;
  v_snapshot public.food_gp_order_snapshots%rowtype;
BEGIN
  SELECT id,store_id INTO v_order,v_store FROM public.food_orders
    WHERE order_number='WF000005';
  SELECT id INTO v_actor FROM auth.users ORDER BY created_at LIMIT 1;
  IF v_order IS NULL OR v_actor IS NULL THEN
    RAISE EXCEPTION 'QA smoke fixtures not found; never use production';
  END IF;
  IF EXISTS (SELECT 1 FROM public.food_gp_store_rates WHERE store_id=v_store) THEN
    RAISE EXCEPTION 'QA store already configured: refuse to overwrite';
  END IF;
  IF EXISTS (SELECT 1 FROM public.food_gp_order_snapshots WHERE order_id=v_order) THEN
    RAISE EXCEPTION 'QA order already snapshotted: refuse to overwrite';
  END IF;

  -- Unconfigured is distinct from a real 0% draft; do not save an implicit 0.
  v_first := public.food_gp_capture_order_qa(v_order);
  IF v_first->>'status' <> 'rate_not_configured' OR
    EXISTS(SELECT 1 FROM public.food_gp_order_snapshots WHERE order_id=v_order) THEN
    RAISE EXCEPTION 'GP without a configured rate must not persist a snapshot';
  END IF;

  -- Arithmetic and mandatory zero real collection.
  IF (public.food_gp_calculate_qa(50000,1000)->>'estimated_gp_satang')::bigint <> 5000
      OR (public.food_gp_calculate_qa(1,5000)->>'estimated_gp_satang')::bigint <> 1
      OR (public.food_gp_calculate_qa(10000,750)->>'estimated_store_food_satang')::bigint <> 9250
      OR (public.food_gp_calculate_qa(12345,10000)->>'estimated_gp_satang')::bigint <> 12345
      OR (public.food_gp_calculate_qa(999,0)->>'actually_collected_gp_satang')::bigint <> 0
  THEN RAISE EXCEPTION 'GP integer arithmetic / rounding failed'; END IF;

  -- These rows will never commit.
  INSERT INTO public.food_gp_store_rates(store_id,rate_bps,updated_by)
  VALUES (v_store,1000,v_actor);

  v_first := public.food_gp_capture_order_qa(v_order);
  v_again := public.food_gp_capture_order_qa(v_order);
  IF v_first->>'status' <> 'snapshotted' OR
     v_again->>'status' <> 'already_snapshotted' THEN
    RAISE EXCEPTION 'capture or idempotent repeat failed';
  END IF;

  UPDATE public.food_gp_store_rates SET rate_bps=2000 WHERE store_id=v_store;
  SELECT * INTO v_snapshot FROM public.food_gp_order_snapshots WHERE order_id=v_order;
  IF v_snapshot.rate_bps <> 1000 OR v_snapshot.estimated_gp_satang <> 500
     OR v_snapshot.estimated_store_food_satang <> 4500
     OR v_snapshot.actually_collected_gp_satang <> 0
     OR v_snapshot.mode <> 'simulation_only' THEN
    RAISE EXCEPTION 'immutable snapshot drift or GP actually collected';
  END IF;

  BEGIN
    UPDATE public.food_gp_order_snapshots SET rate_bps=2000 WHERE order_id=v_order;
    RAISE EXCEPTION 'immutable snapshot UPDATE unexpectedly accepted';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;
  BEGIN
    DELETE FROM public.food_gp_order_snapshots WHERE order_id=v_order;
    RAISE EXCEPTION 'immutable snapshot DELETE unexpectedly accepted';
  EXCEPTION WHEN SQLSTATE '23514' THEN NULL; END;

  IF (SELECT payment_status FROM public.food_orders WHERE id=v_order) <> 'paid'
    OR (SELECT status FROM public.food_stripe_payments WHERE order_id=v_order) <> 'paid' THEN
    RAISE EXCEPTION 'existing PromptPay flow was modified';
  END IF;
  IF has_function_privilege('anon','public.food_gp_capture_order_qa(uuid)','EXECUTE')
    OR has_function_privilege('authenticated','public.food_gp_capture_order_qa(uuid)','EXECUTE')
    OR has_table_privilege('authenticated','public.food_gp_order_snapshots','SELECT')
    OR has_table_privilege('authenticated','public.food_gp_order_snapshots','UPDATE') THEN
    RAISE EXCEPTION 'GP snapshot permission leak';
  END IF;

  RAISE NOTICE 'PASS: no-rate, arithmetic, QA paid snapshot, idempotence, frozen rate, immutable edits, no collected GP, least-privilege, unchanged payment';
END;
$$;

ROLLBACK;
-- Expected persisted after smoke: no new GP rates, snapshots or fees.
