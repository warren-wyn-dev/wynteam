# WYNOS Food + Merchant payment readiness review — 2026-10-08

**Scope:** independent QA of order prices, manual slips, Stripe, refunds, promo funding and order-state notifications. No Production mutations performed.

## Read-only Production findings

The Supabase project `kqokpocajhfbidcxpvhh` was inspected using aggregate SELECT-only SQL.

- 16 total Food orders: 3 `paid/delivered`, 13 `pending/cancelled`.
- 0 negative totals, price-formula mismatches, paid orders lacking `paid_at`, refunded orders lacking `refunded_at`.
- 0 stale pending orders past their payment deadline, and 0 submitted slips with an active Stripe session reference.
- 1 applied campaign, 0 negative or above-discount platform funding records.
- 0 Stripe payment records and 0 Stripe webhook event records: **NO production end-to-end Stripe charging or refund proof exists in this data**.
- Counts were observed once and may change as customers place orders. `supabase/qa/food_payment_readiness_readonly.sql` provides a reproducible audit.

## Confirmed risk in effective Production function

`public.food_apply_stripe_event` currently records each distinct Stripe event id and updates `food_stripe_payments.status` to the newly received event status, without protecting terminal states. When events arrive out of order:
1. An additional `failed` event after a successful `paid` event may change the Stripe payment record to failed while the Food order remains paid.
2. A later `paid` or `failed` event after a completed refund may change the Stripe payment record out of sync with the refunded Food order.
3. A `refunded` event arriving before its paid event may record the Stripe payment as refunded before the Food order is paid.

**Fix:** `supabase/migrations/20261008231000_food_stripe_terminal_webhook_ordering.sql` preserves terminal states and rolls back early refund events so Stripe can retry. The function signature, security privileges, store settlement calculations and no-Stripe/manual slip routes remain unchanged.

## QA coverage and rollout safeguards

Existing `supabase/tests/wynos_stripe_payment_core_test.sh` now applies the migration twice and tests:
- Correct paid event and duplicate event idempotency.
- Wrong amount and connected Stripe account rejection.
- Late failed event after paid cannot downgrade order or Stripe payment.
- Refund-before-paid retries without an idempotency tombstone.
- Late paid and failed events after refund cannot undo a refund.
- Service role is still the only role allowed to call the webhook RPC.

**Release gate:** PostgreSQL integration CI must pass, payment and refund test-mode webhooks must be verified with a real Stripe-connected test account, and a reviewer must verify Production before any Migration deploy. The migration is intentionally NOT applied to Production as part of this QA PR. Coupon PR #1039 is independent and unchanged.

**Limitations:** Read-only aggregate checks do not prove 100% reliability or merchant payouts on actual devices. No live Stripe payment or refund was initiated.
