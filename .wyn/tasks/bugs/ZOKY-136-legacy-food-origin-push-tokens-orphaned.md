# Bug Report — ZOKY-136

Status: bugs
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
