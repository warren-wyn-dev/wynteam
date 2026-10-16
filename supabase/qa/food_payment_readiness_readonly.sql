-- WYNOS Food/Merchant Production financial reconciliation (READ-ONLY).
-- Run with a privileged *read-only* SQL session. Returns aggregate counters only.
-- Does not output customer, merchant, or payment identifiers.
-- All *_mismatch and *_conflict counters should be 0.
WITH
orders AS (
 SELECT COUNT(*) AS total_orders,
        COUNT(*) FILTER (WHERE o.total < 0) AS negative_total,
        COUNT(*) FILTER (WHERE ABS(
           o.total - (COALESCE(o.subtotal,0)+COALESCE(o.delivery_fee,0)
                       -COALESCE(o.campaign_discount,0)-COALESCE(o.delivery_discount,0))
        ) > 0.01) AS amount_mismatch,
        COUNT(*) FILTER (WHERE o.payment_status = 'paid' AND o.paid_at IS NULL) AS paid_without_timestamp,
        COUNT(*) FILTER (WHERE o.payment_status = 'refunded' AND o.refunded_at IS NULL) AS refunded_without_timestamp,
        COUNT(*) FILTER (WHERE o.payment_status = 'submitted' AND o.payment_slip_path IS NOT NULL
                             AND o.stripe_checkout_session_id IS NOT NULL) AS submitted_slip_with_stripe_session,
        COUNT(*) FILTER (WHERE o.source='app' AND o.status='pending_acceptance'
                             AND o.payment_status IN ('pending','issue')
                             AND o.payment_due_at < now()) AS expired_pending
 FROM public.food_orders o
), stripe AS (
 SELECT COUNT(*) AS stripe_records,
        COUNT(*) FILTER (WHERE s.amount_satang <> ROUND(o.total*100)::bigint) AS stripe_amount_mismatch,
        COUNT(*) FILTER (WHERE (o.payment_status='paid' AND s.status='failed')
                            OR (o.payment_status='refunded' AND s.status<>'refunded')) AS stripe_terminal_state_conflict
 FROM public.food_stripe_payments s
 JOIN public.food_orders o ON o.id=s.order_id
), campaigns AS (
 SELECT COUNT(*) AS applied_campaigns,
        COUNT(*) FILTER (WHERE oc.platform_funded < 0
                             OR oc.platform_funded > GREATEST(
                                 COALESCE(oc.campaign_discount,0)+COALESCE(oc.delivery_discount,0),0
                             )) AS platform_funding_mismatch
 FROM public.food_order_campaigns oc
)
SELECT orders.*, stripe.*, campaigns.*,
       (SELECT COUNT(*) FROM public.food_stripe_webhook_events) AS recorded_webhook_events
FROM orders CROSS JOIN stripe CROSS JOIN campaigns;
