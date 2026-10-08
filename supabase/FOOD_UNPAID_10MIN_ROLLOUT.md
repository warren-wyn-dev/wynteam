# WYNOS Food — Unpaid order timeout (10 minutes)

## Policy
- Applies only to **new WYNOS Food customer orders** (`food_orders.source='app'`) created after the schema migration.
- Starts at order creation, **not** when opening Stripe Checkout.
- If the customer has neither completed payment nor submitted a payment slip by the deadline, automatically cancel the order on the next cron tick (typically within 1 minute).
- `payment_status='submitted'`, `paid` and `refunded` are **never** automatically cancelled; a submitted slip is protected while the store/SlipOK verifies it.
- An asynchronous Stripe payment with Checkout `status='complete'` is protected until the webhook finalizes it.
- `payment_status='issue'` may time out when no successful payment exists.
- Old orders retain `payment_due_at=NULL`; merchant-entered orders (`source='manual'`) are never touched.
- The cancellation writes `auto_cancelled_unpaid` to order events. Existing cancellation campaign-release and order-status notification mechanisms run.
- If the Stripe API is unavailable or Checkout cannot be positively expired, the order stays pending for retry. Never cancel first then hope Stripe will fail.

## Release order — production is gated
1. Review and run the new static tests + Deno check and QA in a safe environment. Verify no unexpected payment events.
2. Deploy new `food-unpaid-timeout` Edge worker. It stays inert without the cron key RPC.
3. Apply **schema** migration `20261008113000_food_unpaid_payment_timeout.sql` only; it does NOT start cancellation.
4. Deploy the updated `food-stripe-checkout` Edge function; verify late sessions are rejected and new sessions are expired on a race.
5. Ship customer web changes and confirm countdown / slip / Stripe journeys on iOS Safari and Chrome.
6. Apply **activation** migration `20261008113001_food_unpaid_payment_timeout_enable_cron.sql`. Check job `wynos-food-unpaid-timeout` active and that a test unpaid order gets cancelled at 10 minutes without charging.
7. Verify manually: paid order protected; slip submitted before deadline protected; Stripe open expires first, then cancel; Stripe completed/pending async protected; merchant manual order and all pre-migration orders untouched; customer and merchant get correct cancellation notifications.

## Operational checks
- `select jobid, jobname, active, schedule from cron.job where jobname='wynos-food-unpaid-timeout';`
- Query `cron.job_run_details` for failures and `net._http_response` for non-2xx requests.
- Review newly cancelled orders by `food_order_events.event_type='auto_cancelled_unpaid'`.
- Monitor Stripe logs for session expiry errors and pending webhook events.
- Do not store Stripe keys or the Vault cron key in application code or logs.

## Emergency stop
With Founder approval, unschedule the job by name. Do **not** automatically roll back the database or re-open already cancelled orders: a previously expired Stripe session cannot be reused. Existing orders are not backfilled by this feature.

## Customer-support edge case
A customer could transfer money through direct bank transfer just before the deadline but fail to upload their slip in time. This payment is not visible to WYNOS without a submitted slip; the customer and merchant will need a manual verification/refund process. The checkout UI explicitly warns that the slip must be **submitted** within 10 minutes. Support procedures should be confirmed before enabling Production.
