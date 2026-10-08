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


## Current Vercel integration status (2026-10-08)

The isolated tester is committed to `web/app/stripe-sandbox/page.tsx` on this branch, with guard tests in `web/tests/stripe-sandbox-page.test.mjs`.
The test page supports email/password Sandbox Auth, listing only buyer-owned Sandbox orders,
starting the existing `food-stripe-checkout` Edge Function, and refreshing statuses after Stripe returns.
It intentionally cannot create a merchant/store/order (which requires the missing normal Food APIs).

**BLOCKED deployment:** Creating a new isolated Vercel project `wynos-food-stripe-sandbox`
under team `warren14` returned HTTP 403 (`You don't have permission to create the project`).
The available runtime does not have Vercel CLI for the documented fallback.
Do not edit or redeploy the existing `web` project, which serves Production WYNOS domains.

### Owner-only Vercel setup to unblock

1. In https://vercel.com/new choose team `warren14` and import GitHub `warren-wyn-dev/wynteam`.
2. Create a **NEW** project named `wynos-food-stripe-sandbox`, root directory `web`, framework Next.js.
3. Before exposing the preview to testers, require Vercel Authentication / deployment protection.
4. Make production/preview build source `sandbox/stripe-testmode-20261008` (NOT `main`),
   or deploy a Preview explicitly from that exact branch.
5. Configure ONLY the brand-new project's Preview environment using the three keys in
   `web/.env.stripe-sandbox.example`. The Supabase publishable key is found under
   https://supabase.com/dashboard/project/pcatuxtenluqzjzzwsvl/settings/api-keys.
   Never copy a key from Production Supabase or use the Production Vercel project's environment variables.
6. Open `https://<preview-host>/stripe-sandbox`. The page must say `Supabase Sandbox`,
   never `ปิดการทำงานเพื่อความปลอดภัย` (which indicates a missing guard variable).
7. Set **Sandbox Edge secrets** `WYNOS_STRIPE_SANDBOX_FOOD_URL` to
   `https://<preview-host>/stripe-sandbox` (without trailing slash); configure
   `WYNOS_STRIPE_MERCHANT_TEST_URL` only if/when testing merchant Connect against a working merchant UI.
8. Configure Sandbox Auth URL allow-list for the exact preview host before signing up with a throwaway test email.
9. Test merchant Stripe Connect, create a genuine Sandbox food order from a customer test account,
   then complete an actual Stripe Test payment. Watch both Stripe Dashboard delivery status
   and `public.food_orders.payment_status` through the authorized client.
   Stripe webhook delivery and real Test API calls are NOT yet proven.

**Release gate:** This is an isolated QA preview only. No link or settings on `food.wynos.online`,
`merchant.wynos.online`, `wynos.online`, Vercel `web`, or Production Supabase may be changed.
