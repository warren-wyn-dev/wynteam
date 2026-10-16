# WYNOS Food/Merchant — Production Payment QA

## Purpose

Run a **read-only aggregate audit** after payment deployments using `supabase/FOOD_PAYMENT_PRODUCTION_AUDIT.sql`. Do not paste personal details, access tokens, or raw Stripe objects into issue comments.

## Recommended QA gate

1. Run the maintained PostgreSQL integration suite (`supabase/tests/wynos_stripe_payment_core_test.sh`). Assert paid/refunded states cannot be downgraded by late Stripe events, a refund cannot apply before its payment, distinct PaymentIntents cannot overwrite settled charges, and duplicate webhooks are handled safely.
2. Ensure CI Admin, Web, Edge, Schema and PostgreSQL jobs pass on the **latest** branch head. PR #1040 remains separate from Food Promotions PR #1039.
3. In non-production Stripe test mode, confirm payment success, failure, late event delivery, refund, retry, and identical payment amounts in Food, Merchant and Stripe.
4. In non-production Food, verify PromptPay slip upload, submitted/manual review, timeout, cancel, no double payment when switching from Stripe to a bank slip, and Merchant notification isolation.
5. Audit Production **without mutating orders**. Zero mismatches and missing timestamps are required for claims of financial integrity. Stripe tables with zero rows mean there is *no live Stripe history to validate* — not that a live Stripe charge was tested.
6. Only after review and a deployment window, apply the SQL migration once (using Supabase migration tooling) and verify actual function definition and unchanged GRANT/REVOKE access for authenticated and service_role.
7. Monitor Stripe webhook error/retry counts and payment/ordering consistency. Never refund, delete, or mark paid any real order during testing.

## Release and rollback

- A production deployment requires approval after CI and staging tests; do not auto-merge or auto-apply while QA has open issues.
- This PR changes only the service-role `food_apply_stripe_event` function. If rollback is necessary, restore the previous function definition through a reviewed forward migration; **do not delete payment evidence or webhook idempotency records**.
- Code-only rollback does not reverse completed card charges, refunds, or Merchant balances. Reconcile those separately against Stripe.
