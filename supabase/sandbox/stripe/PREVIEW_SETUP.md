# WYNOS Stripe Sandbox: preview and release gates (2026-10-08)

## Isolation and deployment

- Only Supabase project `pcatuxtenluqzjzzwsvl`; NEVER `kqokpocajhfbidcxpvhh`.
- Source branch: `sandbox/stripe-testmode-20261008` (never merge to `main` without explicit approval).
- The five Edge Functions are already deployed to this Sandbox and require `sk_test_`; the webhook also requires signed test events (`livemode === false`).
- `sandbox_stripe_webhook_state_monotonicity` prevents late failed/paid Stripe events from rolling back already-paid/refunded states.
- `test_webhook_ordering.sql` is a rollback-only synthetic regression test, executed successfully in the Sandbox.

## Preview configuration — not deployed

A separate Vercel preview / staging host is needed before browser E2E testing. This is a separate external service change and needs owner approval. It must not share the production Supabase project.

Public **preview** build environment:
- `NEXT_PUBLIC_SUPABASE_URL=https://pcatuxtenluqzjzzwsvl.supabase.co`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`: only the publishable key from this Sandbox project.

Supabase **Sandbox Edge Functions > Secrets**:
- `STRIPE_SECRET_KEY=sk_test_...` (never `sk_live_`)
- `STRIPE_PUBLISHABLE_KEY=pk_test_...` (never `pk_live_`)
- `WYNOS_STRIPE_SANDBOX_FOOD_URL=https://<private-preview-host>/food`
- `WYNOS_STRIPE_MERCHANT_TEST_URL=https://<private-preview-host>/merchant`
- `STRIPE_WEBHOOK_SECRET=whsec_...` (test snapshot event destination)
- `STRIPE_V2_WEBHOOK_SECRET=whsec_...` (test thin-event destination when used)

Do not commit any actual secrets. The generated preview must point at this Sandbox for Auth/Database/API. Configure the preview hostname in Sandbox Auth redirect allow-list; never change Production Auth settings.

## Webhook event destination to create in Stripe TEST mode

Target URL:
`https://pcatuxtenluqzjzzwsvl.supabase.co/functions/v1/stripe-webhook`

Use Stripe Workbench **Test mode**. Configure the relevant connected-account events:
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `payment_intent.payment_failed`
- `charge.refunded`
- `refund.created`, `refund.updated`, `refund.failed`
- `payout.created`, `payout.updated`, `payout.paid`, `payout.failed`
- `account.updated`

If using Stripe Accounts v2 thin account events, create the required Test-mode account event destination and configure the second `whsec_` secret in the Sandbox. The actual API compatibility must be verified with the account's test key; it has not been verified E2E.

## Missing wider web app dependencies (read-only audit)

The current sandbox was bootstrapped as a focused Stripe/checkout data model, not a full clone of the production WYNOS backend. Static scan of client libraries identified 46 distinct RPC names and 10 table names; in the 2026-10-08 sandbox snapshot, only 11 of these 56 names existed. Not all are needed on every payment page. Important missing functionality includes:
- `food_quote_order`, `food_customer_access_enabled`, `food_customer_addresses`, `food_cancel_order`, `food_transition_order`
- `merchant_finance_summary`, `merchant_store_readiness`, `merchant_sales_report`, `merchant_staff_members`
- Many reviews, delivery zone, campaign, store place and notification routines.

Do not bulk-run production SQL migrations without dependency and RLS review. Stage only reviewed, additive migrations in the Sandbox; use synthetic auth and order data only.

## Gate summary

**Tested in sandbox database:** webhook payment paid/failed/refund transitions, duplicate event ID, amount and Stripe account mismatch denial, out-of-order event monotonicity, test-mode-only DB constraints, hidden Stripe ledger grants, Merchant cross-store SELECT RLS. All synthetic SQL regression transactions rolled back.

**Not tested:** actual Stripe Test API Connect/Checkout/Refund, actual Stripe-signed HTTP delivery, browser checkout/merchant finances UI, hosted preview, Auth signup/email, card decline UX, real payment status in Merchant UI. No live money or live API calls used.

Further setup cannot be completed through the currently available Supabase connector, which does not expose a secrets-writing action. Stripe connector currently offers only a live-mode account, and must not be used for test transactions. Set secrets in the Sandbox Dashboard as the account owner.
