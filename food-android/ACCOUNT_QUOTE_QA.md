# WYNOS Food Android — Account and Quote Handoff

## Implemented in this development branch

- **Read-only** delivery-address list for authenticated WYNOS users, using
  `food_customer_addresses` with explicit `user_id` filter plus required RLS.
- Native address selection (no Android write yet).
- Server-side **read-only price quote** using the same
  `public.food_quote_order(p_store_id, p_items, p_latitude, p_longitude)`
  RPC as the Food website.
- Validated selected option group/choice IDs sent to the server. Client price
  labels are intentionally *not* trusted by the RPC.
- Native cart shows the selected address and subtotal, server delivery fee,
  campaign and delivery discounts, total, and a warning when a delivery pin
  is needed. No local discount logic used for payment.
- Cart changes and address changes invalidate old quotes; stale async quotes
  cannot replace the current cart quote.
- Auth account logout clears customer addresses and quotes.
- JUnit tests for request shape, invalid price/quote, address ordering,
  invalid delivery pins and empty cart.

**No order creation/payment writes were added.** Android Native remains
Kotlin + Jetpack Compose (no WebView/PWA/TWA).

## Confirmed existing server API

Supabase (WYNOS Web) already defines:
- `food_customer_addresses` owner-scoped table and
  `food_upsert_customer_address_v3` / `food_delete_customer_address`
- `food_quote_order` and `food_quote_order_v2`
- `food_create_order` and `food_create_order_v2`
- Stripe edge checkout / webhook through server functions.

The Android client **does not** call create_order or Stripe checkout yet.
Do not copy browser-origin restrictions or spoof Origin headers from Android.
Do not put Stripe secret keys, Supabase service_role or sb_secret keys in APKs.

## Hard release blockers before production checkout

1. Prepare a real **Food staging environment** matching auth, catalog,
   address RLS, quote, order, promotions and Stripe test-mode functions.
   The connected Stripe Sandbox project lacks the same Food public catalog RPC,
   and no production schema was modified here.
2. Implement/verify the native checkout payment contract with a supported
   authenticated mobile flow. The existing Food Web Stripe checkout edge
   function checks browser Origin and is not a compatible drop-in mobile API.
3. Add server-enforced idempotency/payment-confirmation and retry handling;
   test cancellations, refunds, failed/partial payments, and push/order status.
4. E2E with QA accounts and seeded orders in *staging*, then verify accessible
   personal address and order data obey RLS. Do not create live transactions.
5. Compare screenshots for Home, Guest Store, Menu Detail, Cart, Login,
   Account, Orders, Address and Checkout at 360/390/430 dp and accessibility
   font scales, with Thai and English locales.
6. Release-signed AAB, privacy/data-safety disclosures, account deletion
   journeys and required Play Console testing, before enabling release.

## Scope and safety

Only `food-android/**` was modified on a feature branch. No merge, deploy,
live orders, real charges, admin changes or production database writes.
