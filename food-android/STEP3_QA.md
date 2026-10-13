# Step 3 QA gate and safe handoff

## What changed
- Offline cart draft with single-store enforcement, required add-ons, vertical
  radio controls, multi-choice checkboxes, quantity limits and indicative
  totals only; checkout remains disabled.
- Authenticated own-order history read-only, filtered by `buyer_id` and
  subject to RLS. No order creation/cancellation/refund/payment.
- Public catalog still comes through the existing `food_public_catalog` RPC.

## Backend observations (read-only metadata, 2026-10-13)
- Wynos.web Supabase project has `food_public_catalog()` and grants EXECUTE
  to `anon`; it also has `food_quote_order` and `food_create_order`.
- The separately connected WYNOS Stripe Sandbox project **does not** contain
  `food_public_catalog()`; it cannot validate the current guest API as-is.
- No schema change has been made to either project.

## Required before real order flow
1. Confirm a proper Food staging project with compatible auth, public
   catalog/quote/order contracts and RLS.
2. Run device-level integration QA with dedicated test account and fixtures.
3. Validate account/permissions, closed stores, sold-out stock, required
   add-ons, delivery address and promos against the *server* quote.
4. Ensure Stripe Android checkout works with native client authentication:
   the current live `food-stripe-checkout` function requires the web Origin.
   Never spoof it from the app.
5. Review payment webhooks, cancellation/refund, idempotency, notifications,
   privacy, data deletion and store review requirements before release.
6. Create and protect Google Play signing key and complete Console review.

**This branch is not a production release.** No production data modifications,
secret keys, deployment, or Play upload have been performed.
