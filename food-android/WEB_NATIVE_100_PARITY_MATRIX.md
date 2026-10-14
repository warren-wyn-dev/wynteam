# WYNOS Food Android — Web parity contract (2026-10-14)

**Goal:** Native Android delivers 100% functional parity with food.wynos.online and
high visual parity at matching mobile viewports. Kotlin + Jetpack Compose ONLY,
not a WebView/TWA/PWA wrapper. OS keyboard, system bar, permissions and font
rasterization may differ. This is a TESTABLE GOAL, not a statement of readiness.

**Web source of truth:** web/components/food/wynos-food-developer-app.tsx,
web/components/food/food-guest-browse.tsx,
web/components/food/food-promotion-center.tsx,
web/components/food/food-auth.tsx, web/lib/food-customer.ts,
web/app/food/food-app.css. The backend is authoritative for prices, eligibility,
fees, promotions and order state; never trust client-calculated payment totals.

## Audited web-to-Android feature matrix

Partial means a similarly named screen is NOT verified full functionality.
Staging means disposable test backend only, never customer enabled.

| Web customer feature | Native current status | Acceptance requirement |
| --- | --- | --- |
| Guest store/menu browsing and search | Partial | Anonymous browse/cart with matching responsive layout |
| Banner, featured, promo, near/popular/recent sections | Partial | Matching API-ranked sections and positions |
| Free/promo/near/rating filters | Missing | Accurate filters on server-grounded fields |
| Default delivery location in home header | Phase 1 | Display default place/label and open account |
| Restaurant hours, ETA, location and menus | Partial | Real hours/range/stock/category metadata |
| Popular menu, search and recent queries | Partial | Correct stock, recent search and category UX |
| Favorite stores and share links | Missing | Native persisted favorites and Android deep links |
| Store reviews, ratings and merchant replies | Phase 1 added read-only web RPC feed; submission missing | Buyer-masked RLS feed, exact rating/replies and verified-only review write |
| Menu addons/options, quantity and notes | Partial | Required options, stock limit and prices |
| Guest basket + remembered authenticated cart | Partial (session memory) | Process-death persistence, safe guest transfer |
| Cart totals/discounts/minimum and availability | Partial | Exact server quote, refusal rules |
| Promotions codes and notification opt-ins | Missing | Campaign redemption + opt-in settings |
| Login, signup, reset password, session | Partial/staging gates | Password reset deep-link, verification, restore |
| Customer addresses CRUD/default and Thai fields | Partial/staging gates | RLS, safe mutations, address select |
| WYNOS Maps pin/search/reverse geocode | Missing (GPS-only) | Licensed Native map + shared WYNOS Maps API |
| Service zone, fee, promotion and surcharge | Partial quote | Exact server-verified delivery eligibility |
| Buyer-idempotent order submission | Staging only | Atomic server idempotency, E2E |
| Stripe card / PromptPay QR / slip upload | Stripe test preview only | Full authenticated payment + webhook + refund |
| Active/history/details/timeline order updates | Partial read only | Paged realtime status, same dates/transitions |
| Customer cancel, reorder, review purchase | Missing | Server-authoritative mutations + owner checks |
| Delivery proof, tracking and service contact | Missing | Authorized media/track/proof/contacts |
| Messages | Placeholder | Real chat backend and conversation tests |
| Food push notifications, deep links | Missing | Consent, token lifecycle, idempotent delivery |
| Account deletion/privacy/Play policies | Partial/staging | Complete RLS/privacy/signing policy QA |
| Bilingual UX, accessibility, native performance | Partial | Thai/English, TalkBack, fonts, 360/390/430 |

## Exact visual baseline and rationale

- The website fx-store-grid has 2 columns on narrow phones and 3 columns
  from 680px, with 4:3 image tiles and object-fit: cover. Phase 1 restores
  these choices. Prior Android-only 1-column cards and contained images were
  a screenshot-driven deviation and are superseded by the explicit web
  parity requirement; changing Web itself requires separate approval.
- FoodHeader displays the default saved address place_name, falling back
  to label; the location action opens Account. Phase 1 matches this.
- Signed-in web uses 4 tabs Home/Orders/Messages/Account with Cart accessed
  through header or cart tab/action, and the same red/ink/white design tokens.
- Reconcile web recommended/nearby/promoted sections based on real catalog
  source. Never invent a rating, promotion or fee. Screenshots alone are
  not evidence of functional parity.
- Compare authenticated AND guest screens at the same width, OS font scale,
  server dataset and locale. Cover process death, slow network and offline.

## Non-negotiable production release gate

Keep feature PRs and migrations UNMERGED/UNDEPLOYED until disposable full
Food Staging parity, signed-in E2E with Merchant and Stripe Test, reliable
order idempotency, payment/cancel/refund reconciliation, authorized delivery
and Maps, notifications, security/RLS audit, large-font and device QA, Play
signing/policies and explicit production approval.

## Workstreams and deliverable order

1. Phase 1: web layout grids, address header, read-only review feed, regression tests.
2. Discovery and store UI: promos, real featured/near/popular, ratings,
   favorites, shares, category/menu search and stock indicators.
3. Basket/account: local per-account cart and guest transfer, saved address
   CRUD and Maps pin picker.
4. Checkout/payment: server quote, order creation, promo logic, merchant
   self-delivery and complete test payment routes including PromptPay/slip.
5. After order: cancellation, reorder, review, delivery proof, realtime,
   chat, push and notification deep links.
6. Accessibility, Thai/English and realistic Play release certification.

An item counts as completed only with code review AND automated E2E on
disposable staging; passing a static build is not 100% functional parity.
