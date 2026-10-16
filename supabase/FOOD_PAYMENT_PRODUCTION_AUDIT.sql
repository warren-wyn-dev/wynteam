-- WYNOS Food/Merchant: read-only Production payment readiness audit
-- Run using a trusted operator with read access. SELECT only: no writes.
-- Result contains aggregate numbers, not customer identities or payment secrets.
WITH
  orders AS (
    SELECT
      count(*) AS total_orders,
      count(*) FILTER (WHERE total < 0) AS negative_totals,
      count(*) FILTER (WHERE abs(total - (
        subtotal + delivery_fee - coalesce(campaign_discount,0) - coalesce(delivery_discount,0)
      )) > 0.01) AS incorrect_order_totals,
      count(*) FILTER (WHERE payment_status='paid' AND paid_at IS NULL) AS paid_missing_timestamp,
      count(*) FILTER (WHERE payment_status='refunded' AND refunded_at IS NULL) AS refund_missing_timestamp,
      count(*) FILTER (WHERE payment_status='paid' AND status='cancelled') AS cancelled_paid_orders,
      count(*) FILTER (WHERE payment_provider='stripe' AND stripe_payment_intent_id IS NULL
        AND payment_status IN ('paid','refunded')) AS stripe_paid_missing_intent
    FROM public.food_orders
  ),
  stripe AS (
    SELECT
      count(*) AS stripe_rows,
      count(*) FILTER (WHERE amount_satang<=0) AS non_positive_stripe_amounts,
      count(*) FILTER (WHERE p.status='paid') AS stripe_paid_rows,
      count(*) FILTER (WHERE p.status='refunded') AS stripe_refunded_rows,
      count(*) FILTER (WHERE p.status='paid' AND p.paid_at IS NULL) AS stripe_paid_missing_timestamp,
      count(*) FILTER (WHERE p.status='refunded' AND p.refunded_at IS NULL) AS stripe_refund_missing_timestamp,
      count(*) FILTER (WHERE p.order_id IS NOT NULL AND abs(p.amount_satang - round(o.total*100)::bigint)>0) AS stripe_order_amount_mismatch,
      count(*) FILTER (WHERE p.order_id IS NOT NULL AND p.store_id IS DISTINCT FROM o.store_id) AS stripe_order_store_mismatch,
      -- Catch the precise out-of-order event bug: order PAID but the
      -- Stripe payment row overwritten to FAILED, or any other mismatch.
      count(*) FILTER (WHERE
        (o.payment_status IN ('paid','refunded') AND p.status IS DISTINCT FROM o.payment_status)
        OR (p.status IN ('paid','refunded') AND o.payment_status IS DISTINCT FROM p.status)
      ) AS stripe_order_payment_state_conflicts,
      count(*) FILTER (WHERE p.order_id IS NOT NULL AND p.status='paid' AND o.payment_status='refunded') AS stripe_row_unreconciled_refund,
      count(*) FILTER (WHERE p.order_id IS NOT NULL AND p.status='refunded' AND o.payment_status='paid') AS order_unreconciled_refund
    FROM public.food_stripe_payments p
    LEFT JOIN public.food_orders o ON o.id=p.order_id
  ),
  missing_stripe AS (
    SELECT count(*) AS paid_stripe_orders_missing_payment_row
    FROM public.food_orders o
    LEFT JOIN public.food_stripe_payments p ON p.order_id=o.id
    WHERE o.payment_provider='stripe' AND o.payment_status IN ('paid','refunded') AND p.order_id IS NULL
  ),
  webhooks AS (
    SELECT count(*) AS processed_stripe_webhook_events FROM public.food_stripe_webhook_events
  )
SELECT to_jsonb(orders) || to_jsonb(stripe) || to_jsonb(missing_stripe) || to_jsonb(webhooks)
  AS payment_readiness_summary
FROM orders CROSS JOIN stripe CROSS JOIN missing_stripe CROSS JOIN webhooks;
