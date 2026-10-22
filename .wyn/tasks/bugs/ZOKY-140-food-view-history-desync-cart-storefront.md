# Bug Report — ZOKY-140

Status: fixed — waiting QA re-test
Severity: MEDIUM (navigation/UX regression introduced by the new `?view=food` history entry; no data loss, no security impact)
Owner: AI Debug Engineer
Found by: AI QA & Security, branch `feat/zoky-web-app-design` @ cc823142, 2026-10-19

Bug:
The Home → Food step pushes a history entry (`?view=food`), but leaving Food for the cart tab, another tab or a
storefront does not. Browser back / iPad swipe-back then only changes the URL (popstate updates `homeView`) while the UI
stays on the cart or storefront, so the first back appears to do nothing and the second back leaves the site. `?view=food`
also stays in the URL on other tabs, so a reload lands on Food instead of where the user was.

Reproduction (local production build, Supabase mocked in Playwright, Chromium 390/430/820, prod hosts blocked):
1. Signed in, cart has items. Home → tap "ค้นหาของอร่อย" (URL `/food?view=food`).
2. Tap the floating cart (cart tab opens, URL still `?view=food`). Press browser back.
   Expected: Food page. Actual: URL becomes `/food`, cart stays on screen; another back leaves the site.
3. Home → Food → tap a store row (storefront). Press browser back / swipe-back.
   Expected: Food page. Actual: URL `/food`, storefront stays on screen (no `.zk-food`, no `.zk-home`).
4. Home → Food → tap "จัดส่งที่" (account tab). Reload.
   Expected: not Food (old behaviour: reload opens the home tab). Actual: lands on Food (`?view=food` kept).
Also seen after checkout: orders tab shows while URL keeps `?view=food`.

Root Cause: `web/components/food/wynos-food-developer-app.tsx` — the `popstate` handler only does
`setHomeView(...)`; it ignores `tab` and `storefrontOpen`. `openDirectory` pushes history, but `pickStore`,
`setTab("cart")`, `onLocation` and the tab changes do not update or replace the URL (only `onTab("home")` does).

Fix (suggested, smallest; Architect/CTO to confirm): in the `popstate` handler, if the user is on a non-home tab or
on a storefront, bring them back to discovery (`setTab("home")`, `setStorefrontOpen(false)`) and keep Food when they
came from Food — for example, when leaving Food for a tab or storefront, push a history entry (or keep `zkView`
in state) so that back closes that screen. Alternatively, drop `view` with `replaceState` when leaving the home tab so
a reload does not land on Food. Do not touch `?store=` / `?order=` handling.

Fix (done 2026-10-22): leaving Food for a store or another tab pushes one history entry without `?view=food`
(state `zkScreen`); later moves only replace that entry's screen, and going back to Home clears it. `popstate`
restores tab + storefront from the entry (no `zkScreen` = discovery), so back from cart/store/account returns to Food,
and a reload there does not land on Food. In-app back from the storefront and `openDirectory` use `history.back()` on such
an entry, so entries do not stack. `?store=` / `?order=` handling untouched.
Files Changed: `web/components/food/wynos-food-developer-app.tsx`, `web/tests/browser/wynos-food-developer-preview.spec.ts`
Verification (2026-10-22, local production build, mocked Supabase `sb-mock.test`, synthetic data, other hosts aborted,
Chromium 1194 390x844): 16/16 scenario checks pass — Food→cart→back = Food (forward = cart), Food→store→back = Food
(twice, then back = Home on site), Food→store→cart→back = Food, storefront in-app back = Food without stacking,
Food→account→reload ≠ Food, deep link `?view=food` + in-app back = Home on site. lint 0 errors, typecheck pass,
unit 348/348, Playwright food + merchant 68/68. Not tested: WebKit/real iPad swipe (no WebKit in sandbox).
Tests (requested): add a browser regression: Food → cart → back = Food; Food → store → back = Food; Food → account → reload ≠ Food;
existing back/forward/reload/deep-link checks for `?view=food` must still pass.
Regression Risk: medium — history handling is shared by shared links (`?store=`, `?order=`), pull-to-refresh and nav.
Handoff to QA: rerun ZOKY web Home/Food history matrix (390/430/820).
