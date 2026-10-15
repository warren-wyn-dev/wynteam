# Zoky Android — native customer-Web feature completion plan

Reference: current **food.wynos.online customer Web experience**, not the separate WYNOS Merchant, Social or Maps products. Android package: `online.wynos.food`; Kotlin/Jetpack Compose, same authorized backend API, no WebView/PWA/TWA.

## Integration baseline (2026-10-15)

This **draft branch** stacks on draft PR #1220 (native buyer cancellation, inheriting #1219 order links/coupons and #1217 staged chat) and ports the latest device-only Firebase implementation from draft PR #1221. Both stacks remain **unmerged** and must be reviewed together before any upstream integration.

It combines:
- Signed-in account/session/password recovery and native public catalog.
- Menu/add-ons, one-store cart, buyer-owned read-only orders/details, address selectors and server quotes.
- Home promos, buyer promotion inbox, local favorites and read-only reviews.
- Native order-detail navigation from buyer-owned notification rows and copyable coupon codes.
- Order creation, cancellation, address mutations and Stripe **only behind existing isolated-debug-staging gates**; not available to ordinary builds.
- Staging-only buyer/merchant chat (disabled in ordinary builds).
- Opted-in **debug-only** FCM device QA with channel creation/diagnostics and test-notification routing.
- Combined regression test `web/tests/zoky-android-integrated-parity-guards.test.mjs` plus existing stage/chat/FCM guards.

This is an **integration milestone, not complete customer feature parity**.

## Remaining parity work (not yet implemented / not yet E2E validated)

| Area | Required work | Completion gate |
| --- | --- | --- |
| Staging foundation | Isolated Food+Merchant+Stripe environment, same schema/API contracts as Web, synthetic buyer/merchant fixtures, proper RLS | No production orders/data and server policy tests pass |
| Ordering | Validate real store status, stock, options, fee/coupon rules, address service zone, idempotent create/cancel; merchant receives and acts on order | End-to-end order trace across native and Merchant on staging |
| Payment | Native Stripe sandbox **and** Web-equivalent manual/QR/slip flows with image preview, replace/remove, timeout, webhook reconciliation and refunds | No duplicate charges; server confirms paid state; multiple failure-path tests |
| Offers | Coupon collect/redeem/apply UX, merchant-funded rules, server quote and expiry validation | Identical server-calculated totals to Web |
| Address/Maps | Full pin/geocoding/search and delivery-service-area workflows with permission/privacy controls | Physical Android location/permission QA |
| Reviews/favorites | Buyer-eligible review create/report/moderation and favorites sync contract | Buyer-account isolation and abuse checks |
| Chat | Full customer↔merchant conversation lifecycle, realtime/unread, attachment policy, spam controls, logout isolation | Two-sided staging device QA and RLS |
| Push | Secure buyer-scoped token registration on server, notification event dispatch, anti-spam/quiet hours, deep links, logout and rotation cleanup | Device delivery across foreground/background/killed after explicit consent |
| Accessibility/operations | Thai/English, small screens, screen reader, font scale, offline/resume, rotation, signed internal testing, crash telemetry consent | Independent real-device acceptance checklist |

## Release rules / permissions

1. No production Supabase schema migration, production order write, payment charge, customer-targeted Push, chat rollout, Google Play upload, merged PR or deployment without explicit separate approval.
2. Do not reuse the current connected Stripe sandbox as if it were a full Food staging clone: the catalog/order/merchant contract must first be verified.
3. Keep the existing branch's `verifiedStaging` checks and **all release BuildConfig booleans false**. No production service-role or Firebase server credentials inside the APK.
4. UI and CI build success cannot be called “100% complete”: validate both buyer and merchant actions, payment webhook state, delivery and error branches with isolated synthetic data.
5. Continue feature work in independently reviewable draft PRs against this integration branch; mark each row complete only with CI, backend, and real-device evidence.

## Next implementation order

1. Land this **draft-only** consolidation and its Android/CI tests, preserving all staged feature gates.
2. Establish the isolated Food+Merchant staging API/RLS contract (without touching production).
3. Implement Web-parity checkout and manual slip UX against that contract; test idempotent native order creation and Merchant state transitions.
4. Implement offers, pin/zone, reviews/favorites sync; then two-sided chat and secure device-push lifecycle.
5. Conduct signed internal Android release QA; seek an explicit final launch approval separately.
