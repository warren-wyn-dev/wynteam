# Bug Report — ZOKY-139

Status: fixed — awaiting QA re-test
Severity: MEDIUM (functional regression vs origin/main in phase 1; auth crosses origins; no token/secret leak)
Owner: AI Debug Engineer
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ 2fa7a4a (code b15d2e6), 2026-10-18

Bug:
Phase 1 (`ZOKY_LEGACY_FOOD_REDIRECT` off) promises `food.wynos.online` behaves like `origin/main` and auth never crosses
origins. A customer who signs up for Food by email on `food.wynos.online` gets a confirmation link
`https://food.wynos.online/auth/callback?next=%2Ffood` (`signUpWithEmail(..., "/food")` →
`getEmailConfirmationRedirectUrl` uses `window.location.origin`). The callback page exchanges the code and stores the
session on the food origin, then `web/app/auth/callback/page.tsx` does
`window.location.replace(\`${FOOD_PRODUCTION_ORIGIN}/\`)` (lines ~96, ~101 `legacyFoodReturn`, and ~120
`destination === "/food"`), i.e. `https://zoky.wynos.online/` — where there is no session. On origin/main the target
was `https://food.wynos.online/` (same origin, signed in). The user lands on ZOKY signed out (account is confirmed; they
must sign in again). Phase 2 is unaffected (proxy redirects the callback itself; accepted R4).

Reproduction (local production build, fake Supabase URL mocked in Playwright, no real Supabase/DB, prod hosts blocked):
1. `next build` with `NEXT_PUBLIC_SUPABASE_URL=http://supabase.mock.localhost:54321` + fake publishable key; `next start` flag unset.
2. Chromium `--host-resolver-rules=MAP food.wynos.online 127.0.0.1, ...`; mock `/auth/v1/user`; seed a valid session cookie
   `sb-supabase-auth-token` on `food.wynos.online` (equivalent to a successful code exchange there).
3. Open `http://food.wynos.online:<port>/auth/callback?next=%2Ffood`.
Expected: stays on `food.wynos.online/` signed in (as origin/main).
Actual: navigates to `https://zoky.wynos.online/`; session cookies on zoky = 0, on food = 4.

Root Cause: the ZOKY rebrand replaced the hardcoded `https://food.wynos.online/` with `FOOD_PRODUCTION_ORIGIN` without
the "stay on the Food origin you are on" rule that `foodHomeUrlFor`/`foodAuthOriginFor` already apply elsewhere.

Fix (suggested, smallest): in `web/app/auth/callback/page.tsx` send Food returns to the current origin's `/` when
`isFoodAppHost(window.location.hostname)` (zoky or food), else `FOOD_PRODUCTION_ORIGIN/` (Social-origin handoff) — e.g.
reuse `foodHomeUrlFor(window.location.hostname, window.location.origin)`. Apply to all three replace sites.

Fix Applied (AI Debug Engineer, 2026-10-18): `web/app/auth/callback/page.tsx` adds a local
`foodHome()` = `foodHomeUrlFor(window.location.hostname, window.location.origin)` and uses
`window.location.replace(foodHome())` at all three sites (popup-with-opener fallback, popup, email confirm
`destination === "/food"`). `FOOD_PRODUCTION_ORIGIN` is no longer imported there. Targets: food → `https://food.wynos.online/`,
zoky → `https://zoky.wynos.online/`, wynos.online/www → `https://zoky.wynos.online/` (unchanged handoff),
localhost/preview → `<same origin>/food`. `next` is still only honored via `isSafeReturnPath`; the redirect target is
derived only from the fixed host allowlist or the current origin, so no open redirect.

Files Changed: `web/app/auth/callback/page.tsx`, `web/tests/food-origin.test.mjs` (2 regression tests: callback source
uses `foodHome()` at all 3 replace sites, no `FOOD_PRODUCTION_ORIGIN`, `isSafeReturnPath` kept; per-host targets for
food/zoky/wynos/www/localhost/preview), `web/tests/food-standalone-account.test.mjs` (old assertion pinned the buggy
`${FOOD_PRODUCTION_ORIGIN}/`; now asserts `foodHome()`).
Tests: reproduced first (new test failed on the old callback). After fix: `node --test tests/*.test.mjs` 348/348 pass;
`npm run lint` 0 errors (17 pre-existing warnings); `npm run typecheck` pass; `npm run build` pass (fake
`NEXT_PUBLIC_SUPABASE_URL`/key, no env files); `python3 tools/check_wynos_release_freeze.py` PASS. Browser repro not
re-run by Debug (QA to re-run the Playwright repro above).
Regression Risk: Low (client-only redirect target; Social-origin behavior unchanged).
Handoff to QA: re-test both flag states; confirm email confirm on food → food, on zoky → zoky, on wynos.online → zoky.
