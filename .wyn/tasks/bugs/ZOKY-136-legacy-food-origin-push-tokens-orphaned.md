# Bug Report — ZOKY-136

Status: verified — closed (QA re-test PASS, 2026-10-18; residual risk documented, server-side option needs PM/Founder decision; staging Android check recommended)
Severity: MEDIUM (privacy on shared devices + duplicate notifications; decide before cutover)
Owner: AI Debug Engineer
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ ffd3ac6, 2026-10-18

Bug:
After cutover every URL on food.wynos.online (except /_next/* and /api/*) returns 307 to zoky, including `/sw.js`.
Browsers reject redirected service-worker script updates, so the old SW on food.wynos.online stays installed and its
push subscription (row in `push_tokens`, `app = 'food'`, keyed by token) keeps receiving Food pushes. Because no page can
render on food.wynos.online any more, the user can never sign out / disable push on that origin, so:
1. A user who signs out of ZOKY (which deletes only the ZOKY token) still receives order/promo notifications for that
   account on the device via the old food.wynos.online subscription (shared-device privacy leak).
2. A user who re-enables notifications on ZOKY gets every Food notification twice (old origin + ZOKY).

Reproduction (reasoned from code + local smoke; real push not testable locally):
1. Before cutover: on food.wynos.online sign in, enable notifications (token saved via `push_tokens.upsert(..., onConflict: token)`, web/lib/push-notifications.ts:196).
2. Deploy ffd3ac6. Local smoke: `curl -H 'Host: food.wynos.online' http://127.0.0.1:3917/sw.js` → `307 https://zoky.wynos.online/sw.js` (SW update cannot proceed).
3. Open zoky.wynos.online, sign in, enable notifications, then sign out → old token still exists server-side; pushes still delivered by the food.wynos.online SW.

Root Cause:
Proxy matcher `/((?!_next/|api/).*)` on host food.wynos.online also redirects `/sw.js`; no cleanup path for the legacy origin's subscription.

Fix (options, needs Architect/Founder choice):
- Exclude `/sw.js` from the food.wynos.online redirect and serve, on that host only, a cleanup worker that calls
  `registration.pushManager.getSubscription()?.unsubscribe()` and `registration.unregister()` (FCM token then becomes invalid and is pruned on next send); or
- Server-side: stop sending to tokens registered from the legacy origin (requires recording origin on `push_tokens` — DB migration, after freeze lift).
Document the chosen approach in the cutover communication plan (AC9).

Files Changed: (to do) web/proxy.ts (+ cleanup worker) or DB/edge function
Tests: proxy test that food.wynos.online/sw.js is not redirected (if option 1); unit test for cleanup worker.
Regression Risk: Low–Medium (service worker scope on legacy host only).
Handoff to QA: verify on staging with two origins on Android Chrome.

## Fix Record (AI Coding, 2026-10-18, Founder approval 2026-10-18 — option 1)

Root Cause: confirmed — the food.wynos.online matcher redirected `/sw.js`; browsers refuse redirected worker updates, so the old worker and its push subscription were never replaced.

Fix:
- `web/proxy.ts`: on host `food.wynos.online` only, `/sw.js` is rewritten (not redirected) to `web/public/food/legacy-sw-cleanup.js`; every other legacy URL still 307s to ZOKY. ZOKY/WYNOS keep the real `/sw.js`.
- `web/public/food/legacy-sw-cleanup.js`: on activate → `pushManager.getSubscription()?.unsubscribe()`, delete `wynos-static-*` caches, `registration.unregister()`. A push reaching it before it retires shows only a generic content-free "ZOKY" banner (browsers require one) and unsubscribes; tap opens `https://zoky.wynos.online/`. No payload read, no fetch, no Supabase.
- Server side: the FCM token of the unsubscribed registration becomes invalid; existing senders (`send-push-notification`, `send-food-promotion`, …) already delete tokens on `UNREGISTERED/NOT_FOUND` (`isDeadTokenError`). No migration done. `push_tokens` has no origin column, so retiring legacy-origin tokens proactively would need a migration (add origin/app-host column, backfill impossible for existing rows) — documented only, not done.
- Local smoke (`next start`, Host header): `food.wynos.online/sw.js` → 200 `application/javascript`, `Cache-Control: public, max-age=0`, cleanup worker body; `food.wynos.online/?order=WF0001` → 307 zoky; `zoky.wynos.online/sw.js` → normal worker.

Residual risk (cannot be closed client-side):
1. The cleanup only runs when the browser checks the old registration for an update: on a visit/navigation to food.wynos.online, or after a push/notification event when the last check is older than 24 h. Pushes delivered to the old worker before that check (up to ~24 h after the device last checked, typically the first push after cutover) are still shown with content by the old worker.
2. A page on zoky.wynos.online cannot reach the food.wynos.online registration (cross-origin), so signing out on ZOKY cannot synchronously kill the old subscription. Full server-side guarantee needs the migration above or revoking all of a user's `food` tokens on sign-out (changes multi-device behaviour — needs PM/Founder decision).
3. Browsers that have uninstalled the origin data or are offline keep nothing / clean up on next check.
Communication plan (AC9) should still tell users to re-enable notifications on ZOKY.

Files Changed: web/proxy.ts, web/public/food/legacy-sw-cleanup.js, web/tests/food-legacy-sw-cleanup.test.mjs, web/tests/maps-host-redirect.test.mjs, web/package.json (test:notifications)
Tests: proxy tests (`/sw.js` and `/sw.js?v=2` on food host → rewrite; zoky/wynos untouched; `/sw.json` still redirects); cleanup worker unit tests in a VM (activate order, no subscription, generic banner without payload content, click opens ZOKY only, no fetch/Supabase). web: lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344 pass, `npm run build` pass. Deno is NOT installed in this environment: `deno check`/`deno test` not run (CI job `edge-functions` runs them); `_lib.ts` logic was executed with Node `--experimental-strip-types` and all edited .ts files parse with the TypeScript compiler (0 syntax diagnostics).
Commit: bdcd0a1

## QA Re-test (AI QA & Security, 2026-10-18) — PASS

Env: worktree /home/user/wynteam-web @ 729a3e2, local only (no env files, no Supabase/Stripe, no production requests; Chromium runs blocked *.wynos.online/*.supabase.co via host-resolver rules except the mapped local test host).
- Local `next start` Host-header matrix: food `/sw.js`, `/sw.js?v=2`, `food.wynos.online:443`, `FOOD.WYNOS.ONLINE` -> 200 `application/javascript`, body = `public/food/legacy-sw-cleanup.js` (sha256 match), `Cache-Control: public, max-age=0`. Food `/SW.js`, `/sw.json`, `/`, `/?order=…&stripe=success`, `/s/ABC`, `/food/auth/callback?code=…`, `/icons/…`, `/manifest.webmanifest`, `/food/legacy-sw-cleanup.js` -> 307 to zoky with path+query. zoky/wynos/merchant/maps `/sw.js` -> normal worker (sha256 = `public/sw.js`). `/sw.js/` and `//sw.js` -> Next's own 308 normalisation (pre-existing).
- Real Chromium test (temporary spec, not committed): page on `http://food.wynos.online:3940` (treated as secure, mapped to a local helper) registered the current `sw.js` with scope `/` and caches `wynos-static-v1`, `wynos-static-v2`, `other-cache`; helper then forwarded `/sw.js` to `next start` with the food Host; `registration.update()` -> cleanup worker installed and activated, `wynos-static-*` deleted, `other-cache` kept, `getRegistrations()` empty, zero outbound requests to other hosts. Push unsubscribe and generic banner covered by the VM unit tests (no push service available offline).
- Code review: worker reads no push payload, no fetch handler, no Supabase; notification click opens fixed `https://zoky.wynos.online/` only. Cleanup file reachable on zoky at `/food/legacy-sw-cleanup.js` is harmless (registering it needs same-origin script execution; it would only unregister).
- Residual risk statement reviewed and accurate: pushes reaching the old worker before the browser's next update check still show content; cross-origin sign-out cannot kill the old subscription; full guarantee needs a server-side origin column (migration, after freeze) or a PM/Founder decision on revoking `food` tokens at sign-out. Keep the AC9 communication item.
- Minor: generic banner icon `/icons/zoky/icon-192-v1.png` on the food host is answered with a 307 to zoky; Chromium follows redirects for notification icons, worst case is a missing icon only.
- Regression: web lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344, `npm run test:notifications` 60/60, `npm run build` pass, freeze guard PASS, Playwright `wynos-food-developer-preview` + `wynos-merchant` on Chromium (chromium-android + chromium-desktop, /opt/pw-browsers/chromium) 134/134 pass against local `next start`.
