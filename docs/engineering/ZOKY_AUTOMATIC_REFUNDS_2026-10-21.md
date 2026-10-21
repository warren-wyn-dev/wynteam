# Automatic Stripe refunds

Founder requested automatic refunds after cancellation on 2026-10-21. This
change adds a durable server queue for cancelled, Stripe-paid orders. It does
not change who may cancel an order or which order states allow cancellation.

The database trigger queues cancellation and late payment on a cancelled order.
It does not backfill historical cancellations. A dedicated Vault-authenticated
worker claims jobs with leases and `SKIP LOCKED`, creates a full refund using
the same idempotency key and immutable parameters as the manual fallback, and
polls known refund IDs. Pending provider refunds stay pending. GP is reversed
only after a successful refund and a provider check confirms the application
fee was returned. No raw Stripe payloads, keys or customer data are logged.

Queue retries use backoff; terminal provider failures and exhausted retries
require review and show a failed refund state. Direct bank-transfer/slip
payments remain manual. Card statement posting can take longer than the
provider confirmation. Original Stripe processing fees are separate from GP.

## Deployment

The repository migration creates the queue with processing **disabled**.
Enable only after deploying `food-auto-refund` and the updated manual fallback,
installing pg_net/pg_cron, creating a dedicated Vault key named
`wynos_food_auto_refund_cron_key`, and configuring the private settings row's
project URL and store allowlist. Schedule `internal.food_auto_refund_tick()`
once per minute. Do not extract the Vault key into the browser or CI output.

Sandbox `pcatuxtenluqzjzzwsvl` is enabled only for `zoky-qa-20261021`.
The deployed worker also hard-fails outside that project or with live keys.
No production change, global enablement, old-order refund or new charge was
performed. WF000009 had already been refunded before activation.

## Verification

- SQL tests: scope, no historical backfill, worker-only ACL, dedicated token,
  lease exclusion, wrong lease rejection, pending/success handling, GP ledger,
  repeated completion, backoff, bounded retries and late payment.
- Runtime tests: mode mismatch, immutable provider retry, polling, partial/wrong
  payment rejection, GP verification, pending and provider errors; worker auth,
  durable outcomes and failed database completion.
- Deno check and web TypeScript check pass. Existing Stripe regression suite
  passes. Unauthenticated hosted worker returns 401; Vault-authenticated
  pg_net smoke returns 200 with an empty queue.
- Financial E2E remains pending a fresh paid order cancelled after activation.
  A successful empty-queue smoke is not proof of a real automatic refund.

## Rollback and monitoring

Disable the private settings row and unschedule the Cron job to stop new
processing. Preserve queue rows, order history and application-fee ledger.
Reconcile already submitted refund IDs with Stripe; disabling does not cancel
refunds Stripe has accepted. Do not drop the queue or replay cancellation.
Monitor `needs_review`, old processing leases and Cron failures through trusted
server tools. Never publish the scheduler headers or Vault values.
