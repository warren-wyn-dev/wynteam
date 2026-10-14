# WYNOS Food Android — Full customer Web parity delivery checklist
**Audit:** 2026-10-15. **Baseline:** Native Compose PR #1207 (`92fc226e0ac32213e2db3162b13ab0c504a23a2d`), stacked on #1206/#1205. **Target:** feature equivalence with *customer* food.wynos.online, NOT 1:1 Web pixels. **Current status:** AUDITED / INCOMPLETE. No release approval.

## Verified reference code
- Web customer flows: `web/components/food/wynos-food-developer-app.tsx` (restaurant/feed, favorites, reviews, cart, checkout, coupon codes, order detail, receipt/payment proof, tracking and cancellation).
- Auth / guest browsing: `web/components/food/food-auth.tsx`, `food-guest-browse.tsx`.
- Promotion notification center: `web/components/food/food-promotion-center.tsx`; actual product messaging is NOT synonymous with general chat.
- Web API facade: `web/lib/food-customer.ts`; Supabase RPCs include `food_quote_order`, `food_create_order`, `food_submit_store_review`, `food_cancel_order`, `food_delivery_availability`, `food_upsert_customer_address_v3`, `food_submit_payment`.
- Native current screens: `food-android/app/src/main/java/online/wynos/food/ui/{FoodApp,FoodWebScreens,FoodParityPages,FoodCartDialogs,FoodViewModel}.kt`; staging order/payment is **feature gated**.
- Existing safety plans: `WEB_PARITY_EXECUTION_PLAN.md`, `STEP3_QA.md`, `STAGING_ORDER_SUBMISSION_QA.md`, `STRIPE_NATIVE_STAGING_QA.md`.

## Implementation tracks: never mark complete without Android/Web/staging E2E comparison
| ID | Web customer journey to match | Android at baseline | Implementation / test acceptance |
| --- | --- | --- | --- |
| P1 | Guest catalog: Home, search, real filters, banner, store, categories, square menu images | Functional native read-only; several designs checked on emulator | Validate empty/offline/closed store/availability, exact count/fees and 320–840dp TH/EN. No fake ETA/rating. |
| P2 | Shared account: sign-in, sign-up, password reset, session, deletion | Native Auth and gated signup/deletion already exist | Real disposable accounts, token refresh, server rejection, delete audit and no session leak when switching accounts. |
| P3 | Menu add-ons, quantities, sold-out, stock and cart | Native menu option dialog and temporary cart | Selection validity, spicy radio, checkout guard, sell-out race, single-store and restore/restart policy match Web. |
| P4 | Customer delivery address edit/default, pin/map search, service zones | Native address management partial, no proven map pin flow | Structured address & pin, actual geocode, delivery availability/fee, update/delete, privacy & keyboard tests. |
| P5 | Server-authoritative quote, coupon validation, delivery & small-order fees | Quote and staging review partial; production checkout disabled | Same backend quote/rounding as Web; minimum order, discounts/merchant funding, incorrect code and stale quote denied. |
| P6 | Order creation & status: submit, merchant acceptance/rejection, cancellations, tracking, history/detail | Buyer-scoped read-only history; staging submission only | Isolated Food+Merchant staging E2E, idempotency across network drop, exactly-one order, buyer RLS & terminal transitions. |
| P7 | Payment: Stripe, QR/transfer, upload slip preview, verification, refund and expiry | Test-only Stripe PaymentSheet gate; live payments disabled | Test modes only, correct Order ID reconciliation/webhook, slip replace/delete/preview, expiry, double-charge/replay prevention, refunds and permission review. |
| P8 | Promo center / collecting codes / coupon ownership and applying at checkout | Native empty coupon strip; no verified collect endpoint | Verify web production/staging coupon contract + customer eligibility/RLS; show only actual eligible offers and server quote discounts. |
| P9 | Store favorite, review feed, post-purchase review | Web has favorites in browser storage and backend review RPCs; Android partially reads reviews only | Account/UX consistency, abuse/moderation, verified purchase, sorting & permission tests. Do not imply cross-device sync if Web is local-only. |
| P10 | Buyer↔merchant chat/messages and support actions | Messages tab exists but intentionally unavailable | Backend conversation contract, attachments/privacy, unread counts, anti-spam, identity-bound RLS, realtime and moderation; preserve 4-tab nav. |
| P11 | Push notices, promotional notifications, quiet hours, deep links | Foreground order polling only | Android POST_NOTIFICATIONS permission, FCM token lifecycle, preferences, no email notifications, notification dedup/rate limit, links to orders/stores. |
| P12 | Localization, UX, accessibility, offline, data privacy and release | TH/EN and 6-size emulator guest QA; not a release gate | Authenticated screenshots; font scale 1.0/1.3/1.5/2.0, keyboard, 3-button/gesture navigation, 320–840dp, real tablet/foldable, app links, destructive flows, crash logging, signed build. |

## Delivery order / dependency gates
1. **A — foundations and buyer identity:** P1–P4, fully stage-tested, no risky production mutation.
2. **B — money and orders:** P5–P7. Set up separate Food+Merchant+Stripe *test* projects with matching RPCs and RLS. Validate legal/accounting treatment and webhook recovery. Production charges remain prohibited until explicit product-owner approval.
3. **C — engagement:** P8–P11, each gated on real API contracts and permissions. Preserve existing Messages tab (coupons via Home/Account).
4. **D — release candidate:** P12 plus complete same-account Web↔Android comparison for P1–P11. Use a coverage dashboard and developer signed internal distribution. Obtain separate approval for Google Play/public switch/production secrets.

## QA and security release criteria
- Latest SHA must pass Gradle `assembleDebug testDebugUnitTest lintDebug bundleRelease` plus project CI.
- Real Web + Android device + Emulator staging user journey evidence, not just matching image. Screens 320/360/390/430/600/840 TH+EN, scrolled/store/menu/after-login.
- Buyer A must never see buyer B's order, coupon, address, message, proof or refund. Merchant can access only authorized store/order. Test RLS and deep links.
- No fake promotions, prices, reviews, stars, distance, ETA or paid actions. Server quote is authoritative. No client trust for monetary amounts or delivery scope.
- No service-role key, live Stripe secret or arbitrary Web JS in Android APK. No changes to Production/Google Play/merchant money without separate approval.
- Release is BLOCKED if no dedicated compatible staging food/merchant/payment backend, missing coupon/message/review permissions, failed staging webhook/idempotency/chargeback test, or unresolved physical device accessibility defects.

## Current blockers confirmed during 2026-10-15 audit
- Android production order and payment remain intentionally disabled in `FoodViewModel.kt` and checkout review UI.
- `WebMessagesPage` is an accurate no-chat-yet placeholder; there is no real native inbox.
- Native CouponPreviewUnavailable is only a truthful empty state; no verified authenticated collect-and-apply flow.
- Web has QR/slip/manual payment, reviews, coupon application and order cancellation flows that Android has not fully implemented.
- Previous emulator screenshots verify primarily **guest** Home/store; they are not evidence of logged-in checkout, payment, chat or device push.
- Full feature parity and a QA-passed release APK **cannot** be promised from a UI-only PR.
