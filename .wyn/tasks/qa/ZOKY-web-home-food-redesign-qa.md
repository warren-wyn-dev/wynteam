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

## Re-test 2026-10-22 — ZOKY-140 fix (commit 9d0d41f4)

Environment: branch `feat/zoky-web-app-design` @ 9d0d41f4, local production build (`next start` :3100, fake env
`sb-mock.test`), Supabase mocked in Playwright with synthetic data only, all other hosts aborted (0 seen), Chromium 1194,
viewports 390x844 / 430x932 / 820x1180. Scripts: dev scenario script (16/16 pass) plus an extended QA script (54 checks
per viewport). Each check asserts the screen and that the URL matches the UI (Food shown only when the URL has `?view=food`).

Results (same at 390 / 430 / 820):
- PASS: back/forward chain Home→Food→cart (back = Food, back = Home, forward = Food then cart; 3x back leaves the site, forward = Home).
- PASS: browser double back from a store = Home. Double tap on the in-app back with real pointer events (0–250 ms) also = Home,
  because the second tap hits the Food back button. Only Playwright's same-frame `dblclick` skips two entries
  (deep link Food → store → off site). This cannot happen with a real tap, so it is informational only, not a bug.
- PASS: nav tabs after leaving Food: account → orders → back = Food, forward = orders; nav Home → back = Food → back = Home;
  account → messages → back = Food.
- PASS: reorder from orders (different store) → cart → back = Food.
- PASS: `?order=` deep link without view (order opens, param removed, back leaves the site, no extra entry); `?view=food&order=`
  (orders without view, back = Food without `?order`, reload = Food without reopening the order).
- PASS: `?store=` deep link without view (storefront, param removed, in-app back = Food as before, browser back leaves the site);
  `?view=food&store=` (back = Food, then the site is left).
- PASS: checkout (mocked `food_create_order`) → orders tab without view → back = Food → back = Home.
- PASS: reload on a cart/store entry = Home (not Food), back = Food, in-app back = Home, forward works; back to Food → reload =
  Food → forward = cart.
- PASS: guest Home ↔ Food back/forward and Food in-app back.
- FAIL (new, guest only): guest Food → store keeps `?view=food`; browser back changes the URL to `/food` but the storefront stays,
  the second back leaves the site, and "ดูร้านทั้งหมด" then opens Home instead of Food.

New bug:
- ZOKY-143 MEDIUM — the ZOKY-140 desync on the signed-out (guest) path. `web/components/food/food-guest-browse.tsx`
  (added to `?view=food` in cc823142, not touched by 9d0d41f4): `popstate` only does `setView(...)` and ignores
  `selectedId` / `showBasket`, and `pickStore` keeps `?view=food`.
  Repro: no cookie, open `/food` → tap the hero → tap a store row → browser back. Expected: Food list. Actual: URL `/food`
  but the storefront stays; back again leaves the site.
  Fix direction: same approach as 9d0d41f4 for the guest store/basket.

Security: diff only touches client history state (`zkScreen` is compared to known values and never used as a URL or
HTML); no secrets, no new requests, no auth change. Not tested: WebKit/real iPad swipe-back, real devices.

ZOKY-140 (signed-in scope, as reported): fixed. No regression found in the signed-in matrix.
Final Status: FAIL — ZOKY-143 MEDIUM, the same history desync on the guest path, blocks this redesign gate just as
ZOKY-140 did. Handoff: AI Debug Engineer (fix ZOKY-143), then QA re-runs the guest history checks.

### Developer verification of the ZOKY-143 fix (2026-10-22, not a QA sign-off)
- Guest fix in `food-guest-browse.tsx` (same approach as ZOKY-140). The QA re-test script, with guest checks added for
  forward, the in-app back, reload, and on-site back, now passes 174/183 at 390/430/820. Every guest check passes (39/39).
- The 9 remaining failures are the B2–B4 Playwright `dblclick` probes. QA classified these as not reproducible with
  real taps, so they are not counted as bugs. Original scenario script: 16/16. Unit tests: 348/348.
  Playwright food + merchant: 68/68. Lint and typecheck pass.
- Waiting on the QA re-test of the guest + signed-in history matrix.
