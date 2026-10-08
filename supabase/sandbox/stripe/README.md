# WYNOS Stripe Sandbox — isolated test mode

Project: `pcatuxtenluqzjzzwsvl` (Singapore). Production project `kqokpocajhfbidcxpvhh` is NOT a deployment target.

All five Edge Functions deploy ONLY to the sandbox project. Four user-facing functions require JWT; `stripe-webhook` does not require JWT and verifies Stripe signatures. Sandbox source MUST reject all non-`sk_test_` keys and Stripe events with `livemode=true`.

## Required sandbox secrets (set in Supabase Dashboard, never in GitHub)

- `STRIPE_SECRET_KEY`: Stripe TEST restricted/secret key beginning `sk_test_`.
- `STRIPE_PUBLISHABLE_KEY`: publishable TEST key beginning `pk_test_`.
- `STRIPE_WEBHOOK_SECRET`: TEST snapshot webhook signing secret.
- `STRIPE_V2_WEBHOOK_SECRET`: TEST thin-event webhook signing secret, if subscribed to Accounts v2 events.
- `WYNOS_STRIPE_SANDBOX_FOOD_URL`: distinct HTTPS staging/preview app, NOT `food.wynos.online`.
- `WYNOS_STRIPE_MERCHANT_TEST_URL`: distinct HTTPS staging/preview app, NOT `merchant.wynos.online`.

Webhook endpoint: `https://pcatuxtenluqzjzzwsvl.supabase.co/functions/v1/stripe-webhook`

*Until all secrets and separate frontend preview environment are provided, Stripe Checkout/Connect E2E has not been verified.*

## Applied additional safeguards

- `003_storage_isolation_policies.sql`: explicit store-scoped policies for `food-public` and `food-private`.
- `004_test_mode_db_guard.sql`: SQL CHECK constraints rejecting live Stripe account/payment records.
- Stripe sandbox functions must not be merged to `main` or deployed to production.

## Validation record (2026-10-08)

Sandbox database SQL transaction with simulated data: paid -> refunded, failed -> issue, duplicate webhook event rejected, amount mismatch rejected. Transaction was rolled back. This is DB RPC verification, not Stripe Test API or browser End-to-End verification.
