# QA — ZOKY web Home + Food redesign

Feature: ZOKY web Home + Food (spec `.wyn/docs/design/zoky-web-home-food-spec.md`, DECISIONS 2026-10-19)
Branch / commit: `feat/zoky-web-app-design` @ cc823142 (base `release/zoky-web-20261018` @ 0533fb36)
Tester: AI QA & Security, 2026-10-19
Final Status: FAIL (re-test 3, 2026-10-22: ZOKY-140/143/144 PASS; new ZOKY-145 HIGH, pre-existing on base 0533fb36 — fix or documented Founder risk acceptance needed)

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

## Re-test 2 (ZOKY-143) 2026-10-22

Environment: `feat/zoky-web-app-design` @ f4ac83ab, production build on :3100 (fake env `sb-mock.test`), Supabase mocked
in Playwright with synthetic data only, all other hosts aborted (0 seen), Chromium 1194, 390x844 / 430x932 / 820x1180.
QA wrote its own guest script (`qa143-guest.mjs`, 53 checks per viewport); the developer-added I7–I13 were not relied on.

Guest results (same at all 3 viewports):
- PASS: Food → store → basket → back = Food → Home → off site (store entry replaced, no stacking).
- PASS: store → basket → in-app close = store → back = Food → forward = store.
- PASS: back/forward chains; back then a different store discards the old forward entry; in-app back = Food → Home → off site.
- PASS: switch store with non-empty basket: dismiss = stay on Food, no entry, basket kept; accept = store 2, basket cleared, back = Food → Home.
- PASS: `?store=` without view (opens store, in-app back = list, browser back leaves site); `?view=food&store=` (back/in-app back = Food);
  invalid / unknown store id = Home / Food, no crash.
- PASS: reload on store/basket entry = Home (basket kept) → back = Food; reload on Food = Food.
- PASS: login link from store → `/food/login` → back = store → back = Food.
- PASS: browser double/triple back from store/basket. Playwright `dblclick` on in-app back = Home (same informational class as B2–B4).
- FAIL (new): ZOKY-144 MEDIUM — basket opened from the Food list, closed with in-app "ย้อนกลับ": list shown with URL `/food`,
  back = list again, reload = Home. Introduced by f4ac83ab. Signed-in equivalent checked: not affected.
- FAIL (LOW, pre-existing class): item sheet stays open after browser back (guest: now over the Food list, blocks taps,
  "เพิ่มลงตะกร้า" silently does nothing; signed-in: sheet also stays). No cross-store basket line was produced. Follow-up candidate, not a blocker.
- Info: `?store=` in-app back shows the list while the URL keeps `?store=` and lacks `?view=food` (unchanged, pre-existing).
  Guest → `/food/login` logs a React `removeChild` pageerror also from the Home login pill (not caused by this diff).

Signed-in regression (ZOKY-140 matrix A–H, 3 viewports): 174/183, the 9 failures are the known B2–B4 `dblclick` probes
(informational). No regression.

Security: diff only touches client history state; `zkStore` from history.state is only compared to catalog ids
(never used as URL/HTML); no new requests, no auth change, no secrets. Not tested: WebKit/real iOS swipe-back, real devices.

ZOKY-140: PASS. ZOKY-143 (store/back scenario as reported): fixed, but its fix introduced ZOKY-144.
Final Status: FAIL — ZOKY-144 MEDIUM. Handoff: AI Debug Engineer (`.wyn/tasks/bugs/ZOKY-144-guest-basket-from-food-list-close-desync.md`).

### Developer verification of the ZOKY-144 fix (2026-10-22, not a QA sign-off)
- Fix: the guest basket's "ย้อนกลับ" goes back when the basket was opened from the list. `popstate` now closes the
  item sheet, for both guests and signed-in users.
- QA guest script `qa143-guest.mjs`: 156/156 passed at 390/430/820, including G9a/G9b (the stale item sheet) and
  the ZOKY-144 basket checks.
- Signed-in A–H: 174/183 passed. The 9 failures are the B2–B4 `dblclick` probes, which are informational.
- Original script: 16/16. Unit tests: 348/348. Playwright food + merchant: 68/68. Lint: 0 errors.

## Re-test 3 (ZOKY-144) 2026-10-22

Environment: `feat/zoky-web-app-design` @ 136b548b, production build on :3100 (fake env `sb-mock.test`), Supabase mocked
in Playwright with synthetic data, all other hosts aborted (0 seen), Chromium 1194, 390x844 / 430x932 / 820x1180.
Run by QA, not the developer: `qa143-guest.mjs` 156/156; `zoky140-retest.mjs` 174/183 (the 9 failures are the known
B2–B4 `dblclick` probes, informational); new attack script `qa144.mjs` 174/180 (the 6 failures are ZOKY-145 below).

New attacks (`qa144.mjs`, all 3 viewports):
- PASS: list basket → in-app back = Food (`?view=food`) → fwd = basket → in-app back = Food → reload = Food → back = Home
  (no dead back) → fwd = Food → Food in-app back = Home.
- PASS: 5 list-basket open/close cycles: `history.length` unchanged, back = Home, back = off site (no stacked entries).
- PASS: store basket in-app back = store with no new entry; then list basket in-app back = Food, then back = Home.
- PASS: emptying the list basket keeps it open; in-app back = Food; back = Home. Reload on a list-basket entry = Home, back = Food.
- PASS: Home basket (no Food entry) in-app back = Home, no entry, back = off site. Double tap on basket back = Food.
- PASS: guest item sheet + back = Food without the sheet; fwd = store without the sheet; adding still works; deep-link
  `?store=` sheet + back = off site, fwd = store without the sheet; X close after fwd works.
- PASS: signed-in item sheet + back = Food, fwd = store without the sheet, add works; sheet + back, then another store
  shows no stale sheet; back chain Food → Home → off site; Food cart back/fwd/reload/back with no extra entry.
- FAIL (new, pre-existing): ZOKY-145 HIGH. In the first `/food` load of a browser session (splash plays), every in-app
  navigation to `/food/login` (Home pill, store link, basket "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ") throws React
  `removeChild` and leaves the old DOM, so the login form never shows. From the basket, the dead basket covers the screen.
  Back from login shows the same dead screen. Reload fixes it. Not caused by this branch: same on base 0533fb36 (rebuilt
  with the fake env). With the splash skipped (`wynos-food-splash` preset) the login form renders. Earlier rounds only
  checked the URL (G7a) and logged the pageerror as informational.

Security: the 136b548b diff only touches client history and UI state (`history.back()`, `setSelectedItem(null)`); no new
requests, no auth/authorization change, no secrets. Not tested: WebKit/real iOS swipe-back, real devices, production.

ZOKY-140: PASS (closed). ZOKY-143: PASS (closed). ZOKY-144: PASS (closed). The earlier LOW stale item sheet is also fixed.
Final Status: FAIL — ZOKY-145 HIGH (pre-existing). It needs a fix, or a documented Founder risk acceptance, before
release. Handoff: AI Debug Engineer (`.wyn/tasks/bugs/ZOKY-145-guest-login-navigation-dead-page-after-splash.md`).
Note (13:05): every result above was captured against the 12:26 build of 136b548b, and none had connection errors.
At 12:58 :3100 was rebuilt from the worktree, which now holds an uncommitted ZOKY-145 change (`web/app/food/layout.tsx`:
`m.removeAttribute('name')` instead of `m.remove()`, plus the matching unit test). On that build, `qa144.mjs` passes
177/177 and fresh-session login renders without errors. That is preliminary evidence only, not a sign-off. ZOKY-145
stays open until the fix is committed and re-tested.
