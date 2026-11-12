# Bug Report — ZOKY-145

Status: closed — QA re-test 4 PASS @ 5e232d68 (2026-10-22)
Severity: HIGH (guest sign-in funnel blocked on the first Food visit of each browser session; no data loss, no security impact)
Owner: AI Debug Engineer
Found by: AI QA & Security re-test 3 (ZOKY-144), branch `feat/zoky-web-app-design` @ 136b548b, 2026-10-22
Introduced by: not this branch. Same behaviour on the base `release/zoky-web-20261018` @ 0533fb36 (rebuilt with the fake
env and checked the same way). Production not checked (no access, by rule).

Bug:
Signed out, on the first `/food` load of a browser session (the brand splash plays), any in-app client navigation to
`/food/login` throws `TypeError: Cannot read properties of null (reading 'removeChild')` in React's commit phase. The URL
becomes `/food/login`, but the login form never renders. The previous `/food` DOM stays on screen and ignores every tap.
That covers the Home "เข้าสู่ระบบ" pill, the store "เข้าสู่ระบบ" link, and the basket "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ"
button. In the basket case the dead basket covers the whole screen, so the guest cannot sign in to order. Browser back
then shows the same dead screen, and its "ย้อนกลับ" and +/- buttons do nothing. A reload fixes it. Seen at 390/430/820
in Chromium 1194; WebKit not tested.

Reproduction:
1. New browser session, no cookie, empty sessionStorage. Open `/food` and wait for the splash to finish (even 5 s).
2. Tap "เข้าสู่ระบบ" on Home, or open a store, add an item, tap "ดูตะกร้า", then "เข้าสู่ระบบเพื่อยืนยันคำสั่งซื้อ".
Expected: the Food login screen (Google / email / password).
Actual: URL `/food/login`, the old Home/store/basket DOM stays, there are no inputs, and one `removeChild` pageerror.
Control: with `sessionStorage["wynos-food-splash"]="1"` set before loading (splash skipped), the login form renders and
there are no errors.

Root Cause (QA lead, to confirm): tied to the first-visit splash path in `web/app/food/layout.tsx`
(`FOOD_SPLASH_BOOT_SCRIPT`: prepends a `<meta name="theme-color">` to `<head>` and later `m.remove()`s it, and sets
`data-fx-splash*` attributes on `<html>`), together with React/Next head and DOM reconciliation on client navigation.
The splash markup is also a suspect.
Fix:
Files Changed:
Tests: a browser test that does a fresh-session `/food` → in-app login navigation and expects the login form (no
sessionStorage preset).
Regression Risk: splash behaviour and status-bar theme color on iOS/Android; signed-in Food entry.
Handoff to QA: re-run guest login entry points (Home pill, store link, basket sign-in) in a fresh session, back from
login, and reload; plus `qa143-guest.mjs`, `qa144.mjs` and `zoky140-retest.mjs`.

Root Cause (confirmed 2026-10-22): `FOOD_SPLASH_BOOT_SCRIPT` in `web/app/food/layout.tsx` prepends a temporary
`<meta name="theme-color" data-fx-splash-theme>` to `<head>` and later calls `m.remove()`. React owns `<head>`; after that
node is removed, the next client navigation that changes head content (e.g. to `/food/login`) hits a detached node in
React's commit → `removeChild` on null → page dead. Proof: rewriting only `m.remove()` to `m.removeAttribute('name')` in the
served HTML (Playwright route, no rebuild) made the login form render with 0 page errors.
Fix: the splash meta is switched off (`removeAttribute('name')`) instead of removed. A nameless meta is ignored by
browsers, and ThemeSync already skips `[data-fx-splash-theme]`.
Files Changed: `web/app/food/layout.tsx`, `web/tests/food-standalone-account.test.mjs`
Verification (developer): with a fresh session + splash, the guest Home login link renders the login form with 0 page errors.
probe144f: splash seen=false/true both render the login form with 0 errors.
QA re-test 4 (2026-10-22, @ 5e232d68): PASS. The three guest entries, back, reload, signup, signed-in sign-out and the
share link all work in a new splash session at 390/430/820 with 0 page errors (`qa145.mjs` 159/159). Regression scripts
pass: `qa144` 177/177, `qa143-guest` 156/156, `zoky140-retest` 174/183 (known dblclick probes). Side effect (LOW,
not blocking): ZOKY-146.
