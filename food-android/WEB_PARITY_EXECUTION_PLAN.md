# WYNOS Food Android — Web feature parity execution plan

Status: **Development / Draft; not production ready**. Updated: 2026-10-14.

## Product contract (confirmed)

- Reference: customer-facing `food.wynos.online` functionality, but **native Kotlin + Jetpack Compose** on Android; no WebView, TWA or PWA wrapper.
- UI: WYNOS Food **on one header line**, search **above** banner, restrained soft-3D icons/CTA; no separate Home delivery/pickup toggle.
- Four bottom tabs remain **Home / Orders / Messages / Account**. Coupons must be reached from Home and Account, **not** replace Messages.
- Real public/authorised data only: no fabricated star ratings, ETA, GPS distances, discounts, merchant status, coupon eligibility, restaurant rankings or driver tracking.
- Thai and English, responsive 360/390/430dp; accessible font scale, keyboard and gesture/3-button navigation.
- Preserve the shared WYNOS Account and the existing staging-only order/payment gates. Production systems, real payments and public release are *out of scope* until separately authorised.

## Current implementation inventory (review against actual Web at release candidate)

| Area | Android status on starting PR #1198 | Required for parity |
| --- | --- | --- |
| Guest browse, store/menu pictures, search, restaurant/multiple menu categories | Public `food_public_catalog`, native store/menu | Compare signed-out Web results, filters, edge cases |
| Home discovery and soft-3D layout | Existing native Home and promo banners | This branch: real open/category/fee filters, Thai/EN tests |
| Auth session, login/logout, password reset | Native shared Supabase Auth | Test verification, refresh, expiry, same-account sessions on a physical device |
| Signup / address writes / account delete | Feature-gated staging paths | Match approved Web functionality without enabling risky operations live |
| Store details, add-ons, spicy single-select, quantities, cart | Native forms and local single-store cart | Authenticated E2E, basket state, sold-out/availability and price/quote reconciliation |
| Delivery address and pin | Address selector and partial edit flows | Secure location/map picker, actual geocoding and delivery range logic |
| Order history/details | Buyer-scoped read-only, foreground status refresh | End-to-end order status, cancellation and reorder once API contract is verified |
| Checkout & payment | Staging-gated order submission and Stripe test PaymentSheet | Isolated staging order→Merchant→payment→webhook→refund/cancel/idempotent recovery; zero live charges before approval |
| Coupons / saved codes / offers | **No verified customer coupon feed or collect endpoint** in Android public RPC; truthful Home empty state | Web-backed eligible offers list, collect/own, restrictions, quote and checkout apply; never fake coupons |
| Ratings and reviews | Server-masked review feed reader; writes absent | Real rating/feedback write with RLS, moderation, verified-purchase semantics |
| Favorites, promotional banners and restaurant metadata | Partial; public catalogue lacks trusted ETA/rating/distance fields | Backend contract or verified Web query + proper access control and freshness |
| Chat / Messages | Preserved tab with honest unavailable message | Shared customer↔merchant chat implementation and moderation before calling complete |
| Push / realtime / deep links | Foreground polling/notice only | Android 13+ permission, token registration, quiet hours, routing, anti-spam and opt-out |
| Refund / receipts / order support | Not yet audited in authenticated Android | Match Web for status, receipts, support, return/refund eligibility |
| Play release & privacy | Debug APK and unsigned bundle only | Test account, Play signing, data safety, privacy and account deletion links, accessibility, release roll-back |

**Do not equate the existence of a screen with parity.** Mark each row complete only after the same realistic user journey succeeds on Web, Android emulator and a physical Android device against an approved non-production environment.

## Sequence and exit gates

1. **Discovery and UI parity (in progress)**: Home search, actual store categories/open/verified fee sorting, guest vs signed-in, store gallery, 4 tabs and new 3D treatment. Build, lint, Kotlin unit tests, visual Thai/English 360/390/430dp, accessibility. No backend writes.
2. **Accounts, menu and cart (next)**: shared account session, signed-in state, address picker, add-ons, sold out, stock limits, multi-store prevention, authoritative server quote. Validate user-specific RLS with dedicated test accounts.
3. **Checkout & payment (blocked until staging parity)**: provision *isolated* test Food + Merchant + Stripe test environment, test order creation with idempotency, checkout, PaymentSheet, webhook reconciliation, cancellation, refunds, network failure/replay and retries. Do not modify production or use live keys.
4. **Coupons, reviews and restaurant metadata (backend dependent)**: verify deployed web and mobile contract before adding native API calls. Coupon collect/use must reflect server availability and a single canonical discount engine. No stacked/ineligible offers.
5. **Communication, realtime and support**: implement actual chat/push only after access rules, retention, opt-out, rate limiting and notification permissions have been reviewed. Preserve Messages tab.
6. **Release candidate**: compare signed-out and signed-in Web / Android checklist; signed app on devices, accessibility, privacy, app data deletion, Play Console policy, analytics/diagnostics, rollout guard/rollback. Require product-owner release approval.

## Non-negotiable QA evidence

- Latest commit: `assembleDebug testDebugUnitTest lintDebug bundleRelease` all succeed; do not reuse passes from an earlier SHA.
- TH/EN guest and authenticated images at 360, 390, 430dp, including very long Thai store names, large fonts and small viewports.
- Real API responses: loading/empty/error/suspended stores, no menu, sold-out, minimum order and known/unknown fees.
- Cross-account & permission tests: user A cannot see orders, addresses, coupons or messages of user B.
- Isolated staging order lifecycle trace (cart quote, idempotency, pending acceptance, accept/reject/cancel, merchant status, payment webhook, refund) with explicit ledger evidence.
- Track each remaining gap in a PR or issue with owner, backend dependency, test plan and release gate. **Not complete** until all required customer journeys pass, not merely because an APK exists.

## Explicit blockers

- Existing guest catalog cannot provide real coupon collectability, GPS distance, live ETA, authentic ratings or personalised ranking.
- Android live order creation and payment are intentionally disabled; test-mode Stripe functionality is insufficient evidence for real transactions.
- Current Messages tab is not a real chat inbox. Android review submission is not implemented.
- Native map pin/address E2E and device notification delivery are not verified.
- This plan does not approve a database migration, secrets change, production merge, release signing or Google Play submission.
