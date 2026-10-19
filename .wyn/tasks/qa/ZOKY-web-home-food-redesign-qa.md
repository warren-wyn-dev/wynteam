# QA — ZOKY web Home + Food redesign

Feature: ZOKY web Home + Food (spec `.wyn/docs/design/zoky-web-home-food-spec.md`, DECISIONS 2026-10-19)
Branch / commit: `feat/zoky-web-app-design` @ cc823142 (base `release/zoky-web-20261018` @ 0533fb36)
Tester: AI QA & Security, 2026-10-19
Final Status: FAIL (ZOKY-140 MEDIUM must be fixed first; no CRITICAL/HIGH)

Environment:
- Local `next build` + `next start` for the branch and for the base (for comparison), fake
  `NEXT_PUBLIC_SUPABASE_URL=http://sb-mock.test` + fake publishable key. No env files, no secrets, no real DB.
- Playwright 1.63 library + Chromium 1194 (`/opt/pw-browsers`). Every `sb-mock.test` request answered by a mock
  (synthetic stores/orders/addresses/notifications, including XSS payloads); all other hosts aborted; WebSockets
  closed; `*.wynos.online`, `*.supabase.co` mapped to NOTFOUND for the repo suite. Blocked-request log: no
  external request apart from the closed realtime WebSocket.
- Viewports: 390x844, 430x932 (mobile), 820x1180 (iPad). WebKit: not installed in `/opt/pw-browsers` — not tested.

Static / automated:
- `npm run lint`: 0 errors (17 warnings, all pre-existing). `npm run typecheck`: pass.
- Unit `node --test tests/*.test.mjs`: 348/348 pass.
- `next build`: pass.
- Playwright `wynos-food-developer-preview` + `wynos-merchant`: 68/68 pass.
- Full Playwright suite (chromium-android, production build): 345 pass, 60 fail, 8 skipped. The 60 failures are Social
  dev-fixture specs (composer/club/chat/content reference/google-pwa); same 60 fail on the base build → not related.

Scenario results (custom mocked suites, 3 viewports): signed-in 87/94 per viewport, guest 20/20, checkout→Stripe
redirect (mocked) pass, pull-to-refresh pass. Failures map to ZOKY-140/141/142 below. A false positive in the English check
(the `฿` sign counted as a Thai character) is ignored; English is translated.

Passed (highlights):
- Home: hero, real popular row (sorted by delivered orders, shown only with ≥2 stores, hidden on directory error,
  skeleton while loading, kept after a failed quiet refresh), promotions center, favorites, cart button + badge only with
  items, nav with real order badge, Social link not covered by the nav, CLS 0.
- No deals / category circles / pickup / "ตัวอย่าง" / demo strings rendered (Home, Food, guest; also grep of source).
- Stars only when `rating_count > 0` and `rating_average > 0`; "ร้านใหม่" when rating ≤ 0; ETA only when both prep times
  are set.
- Food: `?view=food` push, back/forward/reload/deep link, in-app back (incl. after reload / deep link stays on site),
  nav hidden, theme-color `#FFEFF5` and restored, sticky search, server search with debounce/empty/error+retry,
  chips order + rating chip from filter sheet, collect code (same localStorage key), coupon sheet, reorder circles,
  ad click recorded (`food_ad_click`, placement home), storefront in-app back returns to where it was opened, FAB count
  · total + aria-label, FAB does not cover last row, directory loading/error/retry, empty store state, offline bar.
- Shared links: `?store=` opens the store (param removed) and in-app back goes to Food; `?order=` opens the order;
  `/s/<code>` route unchanged (307 → /food with mocked lookup failure).
- Cart → checkout → order created → "จ่ายด้วยบัตร" → `window.location.assign` to the mocked Stripe URL.
- Guest: same look, only `food_public_catalog` requested, login pill → `/food/login`, search, store, basket, FAB.
- Proxy unchanged (diff empty); host checks with `ZOKY_LEGACY_FOOD_REDIRECT` off/on as before; `?view=food` survives
  the legacy 307 to the fixed origin.
- Accessibility: all tap targets ≥ 44 px on Home/Food; visible focus (3 px white on pink, 2 px brand elsewhere); tab
  order = visual order; ARIA tree matches spec order; contrast: white on pink 3.60–4.13 (large text only), all small
  text ≥ 4.58; reduced motion = 0 s transitions.
- Security: no `dangerouslySetInnerHTML`/`innerHTML` added; XSS payloads in store name, promo text, address and
  notification title render as text and never execute; `view` param only compared to "food" (no redirect/injection);
  no secrets in diff; CSP/next.config/vercel.json/layout/manifest/sw unchanged; bento SVG has no script/external href.
- Performance: `/food` initial assets +45.5 KB raw / +10.0 KB gzip (≈ +1.8%); CSS +20 KB raw / +3.7 KB gzip;
  row/popular images `loading="lazy"`, measured 1:1; header causes no layout shift.
- Merchant / Maps / Social: merchant suite pass; Maps/Social specs results identical to base.

Failed / bugs:
- ZOKY-140 MEDIUM — history desync: back from cart/storefront entered from Food only changes the URL; `?view=food`
  kept on other tabs so reload lands on Food.
- ZOKY-141 LOW — sheets: no Esc / focus move / focus return; nav order badge read before the tab name (pre-existing).
- ZOKY-142 LOW — Home theme-color overwritten to white by ThemeSync (pre-existing).

Not tested: WebKit/real iOS Safari, real devices, real Supabase/Stripe, push permission prompt on a device, PWA install
prompt (code unchanged; account panel renders), text-zoom 200% visual pass.

Recommendation: fix ZOKY-140 (Debug Engineer), then QA re-runs the history matrix. ZOKY-141/142 can be follow-ups by
CTO/Founder decision. Not ready for CTO final review until ZOKY-140 is resolved.
