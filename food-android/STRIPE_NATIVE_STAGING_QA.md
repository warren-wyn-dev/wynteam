# Native WYNOS Food Stripe PaymentSheet — Test-mode only (2026-10-14)

**Deployment state: UNDEPLOYED / NOT production-ready.** This branch changes code
only in a GitHub feature branch; no real Stripe API calls have been made.

## Purpose

Native Android Jetpack Compose integration that uses Stripe's **native
PaymentSheet** SDK instead of a WebView or browser-origin spoof. A dedicated
Supabase Edge Function `food-mobile-payment-intent` creates an authenticated
Stripe **direct-charge PaymentIntent** for the connected restaurant account.
The existing signed webhook has been extended to recognize
`payment_intent.succeeded` and apply the server-verified paid state.

### Safety switches: both MUST explicitly opt in

- Android: `WYNOS_FOOD_STAGING_PROJECT_REF` matching the non-production
  `WYNOS_FOOD_SUPABASE_URL`, with
  `WYNOS_FOOD_ORDER_CREATION_STAGING=true` and
  `WYNOS_FOOD_MOBILE_PAYMENT_STAGING=true`.
- Edge: `WYNOS_FOOD_MOBILE_PAYMENT_STAGING=true`, a valid **nonproduction**
  20-character Supabase project reference, `STRIPE_SECRET_KEY=sk_test_...`
  (or `rk_test_...`), `STRIPE_PUBLISHABLE_KEY=pk_test_...`, a service
  account key server-side only and a connected test Stripe merchant.
- Production ref is rejected both by Android build and by Edge Function.
  Android release APKs hardcode `STAGING_MOBILE_PAYMENT_ALLOWED=false`.
- No live keys, test secrets in APK, client-selected amount, client-supplied
  merchant account, browser Origin spoof, payment confirmation from local UI.

## Verified server contract by inspection

Only a signed-in buyer may request PaymentIntent for their own pending
`food_orders` record, with an unexpired payment window, no payment slip, no
existing Stripe Checkout Session and an eligible connected test merchant.
Amount comes from the database's order total in satang, with merchant GP
calculated by the server. A stable Stripe idempotency key binds each order to
the one intent. Existing intents are retrieved and reused only if unpaid and
compatible. An unknown state blocks further creation, asking for server
reconciliation.

**Important:** Existing WYNOS website Stripe Checkout is unchanged. No
production service has been deployed. In any integration environment,
`stripe-webhook` must have a correctly configured test webhook signing
secret and event subscriptions including `payment_intent.succeeded`,
`payment_intent.payment_failed`, and refunds. The PaymentSheet callback
does **not** mark the order paid; the signed webhook does.

## Known release blockers

1. The current test Supabase project still lacks the full Food catalog,
   address and quote APIs. Seed disposable merchant + buyer fixtures,
   appropriate RLS and the proposed idempotent order migration first.
2. Fully integrate server-atomic payment intent lifecycle, cancellations,
   expired orders, orphaned intents, manual-slip conflict, and asynchronous
   webhook/refund races. Do not permit a card payment on an expired/cancelled
   order. The staging-only initial endpoint is **not** a complete production
   payment state machine.
3. Authenticated instrumented test with real **test-mode Stripe** checkout,
   Merchant receiving and completing an order, refund and interrupted
   network/payment reconciliation. No production orders or charges for QA.
4. Persist/reconcile buyer order-attempt UUID safely across process death,
   retries and cross-device sign-in.
5. Turn on complete WYNOS Food staging parity and verify Auth, Account deletion,
   address CRUD, self delivery, notifications, localization/accessibility,
   Data Safety, legally required policies, release signing and Play review.

## Required QA before any rollout

- [ ] `./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug :app:bundleRelease`
- [ ] `deno check supabase/functions/*/index.ts`
- [ ] `deno test --allow-read supabase/functions/`
- [ ] Postgres buyer-scoped idempotency and RLS regression tests pass
- [ ] Staging webhook signature tamper tests, idempotent webhook replay and
      PaymentIntent account/amount mismatch tests pass
- [ ] Test mode Stripe PaymentSheet card success/failure/cancel flows on a
      **signed-in** emulator and physical Android, Thai and English
- [ ] Merchant sees order **only when webhook marks paid** and every
      status transition is correctly reflected in Native order history
- [ ] Confirm release and Production project cannot activate staging payment

**Until all checks and a specific production rollout are approved, do not
deploy this branch, change Supabase Production or publish a live Android APK.**
