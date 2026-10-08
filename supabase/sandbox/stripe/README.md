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


## Additional verified sandbox QA (same date; synthetic fixture records retained)

A second, **persistent synthetic-only** SQL verification was run on the Sandbox (distinct from the earlier rolled-back transaction above):
- `WF000001`: database-generated simulated `checkout.session.completed` -> `paid` on order and ledger, then simulated `charge.refunded` -> `refunded` on both.
- `WF000002`: database-generated simulated failed/expired Stripe event -> order `payment_status=issue`.
- The RPC rejected mismatched amount with error `amount mismatch`, and mismatched Stripe Account ID with error `stripe account mismatch`.
- A duplicate webhook event claim was accepted once (`true`) and denied on its second attempt (`false`).
- The test identifiers (e.g., `acct_SYNTHETIC_DB_FIXTURE_NO_STRIPE`) are NOT valid Stripe resources, and no Stripe API requests or live transactions were made.
- **These two synthetic order records and their ledger rows remain in Sandbox for later inspection**; they were NOT rolled back. They are clearly tagged `TEST_MODE_SQL_ONLY`.
- Direct HTTP E2E against the Sandbox Edge URLs could not be completed from the testing runtime owing to a DNS resolution error. No successful signature test or actual Checkout/Connect/refund on Stripe's Test API has occurred.
- Final SQL verified `food_apply_stripe_event`: no EXECUTE for anon/authenticated, yes for service_role; Stripe account/payment tables enforce `livemode=false` with CHECK constraints.
- 39 Supabase migrations, 23 public RLS tables, 5 ACTIVE functions as observed at last read. This is a deliberately selective scaffold, NOT the full Food/Merchant production feature schema.

**Pending approvals:** altering the external Stripe Test Mode account (webhook endpoint + signing secret), and publishing distinct Food/Merchant preview environments. Neither action has been carried out by this QA run.
