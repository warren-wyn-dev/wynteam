# Zoky Android ↔ Food Customer Web parity — release evidence checklist
**Target reference:** `food.wynos.online` customer experience, bridged through the
Zoky multi-service Home. **Platform:** native Kotlin + Jetpack Compose
(`online.wynos.food`) — never WebView, PWA or TWA.

**Status as of 2026-10-15:** **NOT feature complete.** This is an implementation
and release gate. Do not interpret passing guest UI screenshots as authenticated
checkout/payment/customer↔merchant E2E verification.

## Current coverage and proof still required

| Track | Native implementation currently present | Blockers to equivalent public release |
| --- | --- | --- |
| App-wide Zoky Home | Approved HD 3D art, Thai native text, four tabs, hero, Food entry | Content/marketing final assets and real offer fulfillment must be QA-verified |
| Guest Food discovery | Catalog RPC, search/filter, store/menu/detail; admin banners | Exact Web fixtures, sold-out/closed/empty/offline parity and accessibility scale |
| Shared WYNOS Account | Sign-in, recovery, session restore; signup and account deletion staging-gated | Real test accounts, confirmation/deletion and session-switch security E2E |
| Delivery addresses | Read/select and staging-gated management, structured forms | Map pin/geocoding/service-area QA, editing on physical Android |
| Cart/add-ons | Native option dialogs, single-store cart, quantity and draft notes | Stock race, option constraints, persistence, coupons and fees matching Web |
| Quote | Buyer-auth server `food_quote_order` RPC read; server-calculated totals | Same addresses and coupon fixtures, fail-closed stale quotes |
| Submit / cancel order | Staging-only idempotent create RPC and buyer-owned `food_cancel_order` cancel RPC with explicit debug flag; **ordinary APK creation/cancellation disabled** | Matching Food+Merchant staging API, accepted/rejected/cancelled order, payment and refund E2E |
| Payments | Isolated Stripe test PaymentSheet gated; **no live payment** | Web payment methods, manual slip preview/replace, webhooks, reconciliation, expiry, refunds and duplicate-charge QA |
| Offers/coupons | Real buyer-scoped marketing inbox, read receipts, code copy. Home offers detail | Server coupon collect/apply/eligibility flow and verified marketing settings |
| Order detail/status | Buyer-scoped history/detail + read-only status; direct navigation from Messages | Staging test creation/cancellation/refunds/timeline, notifications/deep links |
| Favorites/reviews | Local guest/buyer-favorite UX, real review feed | Verified-review submission, account sync contract, moderation |
| Chat | Buyer and Merchant staging-only previews in PR #1217; ordinary APK disabled | Full isolated staging RLS, conversation lifecycle, unread, realtime, moderation, two-sided QA |
| Android push | No verified customer-device FCM/token lifecycle | FCM consent/registration, server dispatch, quiet hours, dedupe, receipt/deep links |
| Accessibility/release | Android guest screenshots 320–840dp TH/EN; 720p/1080p | Logged-in Web↔Android QA, typography scaling, keyboard/rotations, signed internal test distribution |

## Changes made in this parity slice
- Order status notices and order rows in Messages open the **actual buyer-owned order-detail dialog**, rather than only changing the tab. The ViewModel rejects order IDs not in the signed-in buyer's server-returned history.
- Buyer marketing notifications with a real coupon code include a **copy button**. Copy is not a claim or proof of coupon eligibility; the server-authoritative quote still decides the discount.
- Empty-order “browse food” takes the user to the **Food catalog**, not the separate Zoky service hub.
- No production schema mutation, order/payment write, Play Store upload or domain change.

## Must-pass staging test matrix before “same as Web”
1. Test with independent buyer A, buyer B, authorized Merchant 1 and unrelated Merchant 2; verify RLS prevents cross-buyer order/address/message access and cross-store chat.
2. Use **complete isolated Food + Merchant + Stripe staging** (current Stripe sandbox alone is not sufficient). Use only synthetic customer data and test cards.
3. One same-account scenario on Web and native: create address + map pin, browse restaurant, choose radio add-ons, cart, validate coupon, quote, submit exactly one order, make test payment/upload slip, merchant accepts, receives status, buyer opens deep link, optionally cancels/refunds, writes verified review and sees receipt.
4. Test denied/expired coupon, double tap/network retry, payment cancellation, bad slip, missing pin, closed/stock-out store, old token, multiple devices, offline/resume and account sign-out.
5. Enable chat/Push **only after** staging, merchant UI, role/RLS, anti-spam, notification permission, deep-link and device receipt tests pass.
6. Release owner separately approves production keys, migration, payment and public rollout. Keep all new behavior draft until that decision.

**Status rule:** Only mark a row complete with backend-specific and device-based QA evidence; never substitute a visual mockup or CI green checkbox for this evidence.
