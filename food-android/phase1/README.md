# WYNOS Food Android — Phase 1: real-code + staging readiness audit
**Audit date:** 2026-10-15. **Code base:** stacked Draft PR #1213 at 54c68765eaf4447a0c1be230de310e97d6fdd21f. **Phase 1 status: IN PROGRESS / BLOCKED on compatible isolated staging.**

This is a read-only inventory and reproducible offline metadata safety check. It neither creates a backend nor certifies order/payment E2E, RLS isolation or a release APK.

## Preserve product and security constraints
- Native Kotlin / Jetpack Compose; no WebView, PWA or TWA.
- One shared WYNOS Account, Food / Merchant backend; TH/EN, original founder-approved four bottom tabs Home / Orders / Messages / Account and existing approved Home/store layout.
- Do not change, merge or deploy Production; do not enable real payments; do not use real customers for tests.
- Any new paid Supabase staging project/branch requires explicit product-owner cost approval first.
- Android debug writes/payment flags remain explicitly gated by a separately configured non-primary staging ref and enabled opt-in; release flags remain disabled.

## Source-of-truth code inspected
- Web buyer API: web/lib/food-customer.ts (order quotes, V2 coupon quote, create order, address pin, cancellation, QR/slips, reviews, maps).
- Web customer screens: web/components/food/wynos-food-developer-app.tsx.
- Web auth: web/components/food/food-auth.tsx; promotions: web/components/food/food-promotion-center.tsx.
- Native gateway: food-android/app/src/main/java/online/wynos/food/data/SupabaseFoodGateway.kt.
- Native state and screens: ui/FoodViewModel.kt, ui/FoodApp.kt, ui/FoodParityPages.kt.
- Existing backlog/QA gate: food-android/FULL_WEB_PARITY_IMPLEMENTATION_BACKLOG_2026-10-15.md and Issue #1210.

## Buyer feature parity inventory: code presence does NOT mean E2E passed

| Buyer journey | Web reference | Android current state | Later work and acceptance |
| --- | --- | --- | --- |
| Guest Home/banner/restaurant search | food_public_catalog, home banners, directory | Native read-only catalog, search and banner | P3: same public stores; offline and closed/suspended tests |
| Store details and menu | Web restaurant/menu/options/stock | Native store/menu and category UI | P3: real availability, image 1:1, TH/EN, quantity/option tests |
| Signup, login, recovery, deletion and SSO | Food Auth, WYNOS Account | Supabase Auth; signup/delete staging-gated | P2: shared identity, email verification and account-switch RLS |
| Cart and add-ons | Web cart helpers | Native single-store cart and add-on dialogs | P4: server rechecks stock, totals, stale cart and network retry |
| Delivery address and map pin | food_upsert_customer_address_v3, wynos_search_places, food_delivery_availability | Address actions partial, no verified pin/geocode E2E | P4: accurate geocoder, delivery area and buyer ownership |
| Server quote & coupon | food_quote_order and food_quote_order_v2 | Native calls food_quote_order only | P4/P7: backend amount/fee parity, V2 coupon eligibility |
| Place order, exactly once | food_create_order, food_create_order_v2 | Native staging-only food_create_order_idempotent | P5: **critical contract difference**; RPC absent in inspected primary and sandbox; design/verify isolated staging implementation, never silently swap to live RPC |
| Order history/detail/status/cancellation | Food orders, food_cancel_order | Native buyer-scoped read-only order/history, foreground polling | P5: end-to-end buyer↔Merchant transitions and cancellation |
| Stripe/QR/slip/refund | Web stripe initiation, QR/manual payment, slip upload | Native Stripe test PaymentSheet feature-gated; no full payment parity | P6: ONLY test-mode reconciliation, file preview/replace/delete, refund and replay |
| Coupon collecting/applying | Web promo center + quote V2 | Native inbox reads and copies codes; no verified coupon use | P7: ownership, collect contract and server quote validation |
| Favorites | Browser-local store IDs on Web | Native local account-scoped favorites | P7: verify same local-only expectations; no false cross-device sync |
| Store review feed/replies | food_store_review_feed | Native read-only RPC-based feed | P7: staging auth/feed and moderation |
| Submit verified review | food_submit_store_review | Missing native write | P7: verified order ownership and strict permissions |
| Customer-to-merchant chat | Actual messaging contract pending audited integration | Messages tab is a truthful placeholder | P8: real conversations/realtime, RLS and moderation |
| Promotion inbox/preferences | food_notifications, food_marketing_preferences | Native read-only inbox/unread count; no mark-read/preferences | P7/9: safe write controls and opt-in |
| FCM and Android push | Notification delivery backend | No verified device push; orders foreground polling | P9: token lifecycle, permissions, quiet hours, deep links |
| Large-screen/a11y/locale/security | Customer Web responsive | Guest 320/360/390/430/600/840dp screenshot QA verified | P10: signed-in screens, large fonts, foldables, physical devices and E2E |

## Live metadata findings (read-only ONLY, 2026-10-15)
Primary Supabase: kqokpocajhfbidcxpvhh. Examined RPC names include food_public_catalog, food_active_home_banners, food_store_review_feed, food_quote_order, food_quote_order_v2, food_delivery_availability, food_upsert_customer_address_v3, food_cancel_order, food_submit_store_review. Native staging-only food_create_order_idempotent was **not present** in the inspected primary RPC list. Inspected Food tables had RLS enabled; **this does not prove row policies are safe**. Most inspected public Food RPCs were SECURITY DEFINER; review definer bodies, EXECUTE grants and auth.uid checks before reusing them.

Connected Stripe Sandbox: pcatuxtenluqzjzzwsvl. Read-only catalog returned only food_create_order and food_submit_payment from the inspected list of Food RPC names. Examined tables: food_stores, food_menu_items, food_orders, food_order_items and food_order_events (RLS on). It lacks the inspected main Food public-catalog, quote, delivery, review and address API contracts. Several Stripe-related Edge Functions exist, but no food-mobile-payment-intent found. **Not an authenticated Food + Merchant staging environment.** Do NOT point Android at it and claim parity.

The earlier connected Stripe account enumeration exposed a livemode Wynos account, not a confirmed usable Test Mode target; no payment action should be taken without explicit Test Mode verification.

## Offline contract gate added in this PR
Files:
- phase1/contract_manifest.json — scoped RPC/table/RLS/Edge Function requirements; signature-name assertions for key RPC inputs.
- phase1/sandbox_metadata_2026-10-15.json — actual inspected sandbox metadata only, no customer data or credentials.
- scripts/check-staging-contract.py — read-only, offline, fails closed; explicitly refuses primary project ref; no network, database or Stripe calls.
- phase1/test_contract_gate.py — positive synthetic metadata fixture and negative real sandbox, production target, missing coupon argument, disabled RLS, missing native payment function tests.
- .github/workflows/food-android-contract-gate.yml — offline CI; verifies deliberately mismatched sandbox is not wrongly marked ready.

From repository root:

    python3 -m unittest discover -s food-android/phase1 -p 'test_*.py' -v
    python3 food-android/scripts/check-staging-contract.py --scope foundation --snapshot food-android/phase1/sandbox_metadata_2026-10-15.json
    python3 food-android/scripts/check-staging-contract.py --scope full --snapshot food-android/phase1/sandbox_metadata_2026-10-15.json

**Expected:** both sandbox checks exit non-zero: this proves the gate refuses an incompatible existing sandbox, not that its database is unhealthy. Once isolated staging is approved, gather a fresh metadata snapshot using read-only Postgres pg_proc / pg_class queries, list Edge Functions via admin metadata and run both gate scopes. A manually supplied metadata snapshot cannot prove which live credentials it came from, nor prove actual Auth/RLS/payment correctness.

## Phase 1 completion gates
- [x] Verified GitHub baseline and previously passed CI/guest Emulator QA on PR #1213.
- [x] Inventoried Web↔Android customer journeys and risk areas.
- [x] Read-only comparison of primary and sandbox RPC/tables/Edge metadata.
- [x] Added fail-closed executable metadata checker and regression tests (**CI pending on this new SHA until workflow completes**).
- [ ] Select an isolated staging solution; obtain explicit approval before any possible project cost.
- [ ] Provision/verify a Food + Merchant + WYNOS Account compatible backend with disposable buyers/merchants and publishable-only Android config.
- [ ] Obtain a confirmed Stripe Test Mode account and test credentials kept off mobile sources.
- [ ] Run foundation and full checks on the *actual new staging*, inspect SECURITY DEFINER contracts/role grants, prove A/B buyer and Merchant RLS with negative tests.
- [ ] Record sign-off/QA evidence and split Phase 2–10 implementation PRs. Until then **Phase 1 NOT COMPLETE**.

Next non-production work can proceed as isolated Draft PRs, but order/payment feature flags remain OFF and Production untouched.
