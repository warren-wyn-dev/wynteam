# Bug Report — ZOKY-135

Status: verified — closed (QA re-test PASS, 2026-10-18; deploy still pending normal gate)
Severity: HIGH (release blocker for the ZOKY domain cutover; known, carried from handoff)
Owner: AI Debug Engineer (edge function change requires QA Security + Founder approval + deploy)
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ ffd3ac6, 2026-10-18

Bug:
Supabase edge functions still hardcode `https://food.wynos.online` as the only trusted Food origin.
After the web deploy, Food runs on `https://zoky.wynos.online` (food.wynos.online only redirects), so:
- `supabase/functions/food-stripe-checkout/index.ts:69` — live mode rejects `Origin: https://zoky.wynos.online` with 403 `live_stripe_origin_required` → card payment impossible on ZOKY.
- `supabase/functions/food-stripe-cancel/index.ts:71` — same check → cancelling a card-paid order from ZOKY returns 403.
- `supabase/functions/wynos-maps-geocode/index.ts:22-30` (`ALLOWED_ORIGINS`, line 26) — geocode fallback from ZOKY returns 403.
- `supabase/functions/food-stripe-checkout/index.ts:152-153` — success/cancel URLs point to food.wynos.online (works via 307, should move to zoky); `:155` product name `WYNOS Food #…` (Q10, branding only).

Reproduction:
1. Deploy web @ ffd3ac6 with zoky.wynos.online attached, Stripe live mode.
2. On https://zoky.wynos.online place an order and choose card payment.
3. Edge function compares `Origin` to `https://food.wynos.online` → 403.
(Code-level verification only: `grep -rn food.wynos.online supabase/functions`. Not executed against any real project.)

Root Cause:
Origin allowlists not updated for the new canonical Food origin (web change deliberately excluded edge functions).

Fix:
Accept an explicit allowlist `{https://zoky.wynos.online, https://food.wynos.online}` (exact string match, no suffix/regex matching, keep deny-by-default) in all three functions; move success/cancel URLs to zoky. Keep food.wynos.online accepted during transition/rollback. Deploy before or together with the web release.

Files Changed: (to do) supabase/functions/food-stripe-checkout/index.ts, food-stripe-cancel/index.ts, wynos-maps-geocode/index.ts
Tests: add unit tests for origin allowlist (zoky accepted, food accepted, `https://zoky.wynos.online.evil.com`, `https://evil.com`, `null`, missing Origin rejected in live mode).
Regression Risk: Medium — payment path; security-sensitive (Founder approval required).
Handoff to QA: re-test origin allowlist + Stripe test-mode success/cancel on staging.

## Fix Record (AI Coding, 2026-10-18, Founder approval 2026-10-18)

Root Cause: the three functions compared `Origin` to the single string `https://food.wynos.online`; the web move to `zoky.wynos.online` deliberately left edge functions out.

Fix:
- `supabase/functions/food-stripe-checkout/_lib.ts`: `FOOD_WEB_ORIGIN = https://zoky.wynos.online`, `FOOD_WEB_ORIGINS = {zoky, food}` (exact `Set.has`, no suffix/wildcard/regex, deny by default), `isFoodWebOrigin()`, `foodReturnOrigin()` (request origin only if allowlisted, else ZOKY).
- `food-stripe-checkout/index.ts`: live mode requires `isFoodWebOrigin(origin)`; `success_url`/`cancel_url` = `foodReturnOrigin(origin)` + `/?order=…&stripe=success|cancelled`; product name `ZOKY #<order>`.
- `food-stripe-cancel/index.ts`: live mode requires `isFoodWebOrigin(origin)` (imports `../food-stripe-checkout/_lib.ts`, same cross-function pattern as `send-food-promotion`).
- `wynos-maps-geocode/index.ts`: `ALLOWED_ORIGINS` adds `https://zoky.wynos.online` (food kept).
- Test mode unchanged: still no origin check. Note: test-mode return URLs now default to ZOKY (previously food.wynos.online) unless the request comes from an allowlisted origin.

Files Changed: supabase/functions/food-stripe-checkout/{_lib.ts,_lib.test.ts,index.ts}, food-stripe-cancel/index.ts, wynos-maps-geocode/index.ts, web/tests/stripe-payment-core.test.mjs
Tests: `food-stripe-checkout/_lib.test.ts` adds allowlist cases (zoky/food accepted; `zoky.wynos.online.evil.com`, `evil.zoky.wynos.online`, trailing slash, `:443`, `http://`, uppercase, `evil.com`, `null`, empty, missing rejected; return origin falls back to ZOKY). web: lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344 pass, `npm run build` pass. Deno is NOT installed in this environment: `deno check`/`deno test` not run (CI job `edge-functions` runs them); `_lib.ts` logic was executed with Node `--experimental-strip-types` and all edited .ts files parse with the TypeScript compiler (0 syntax diagnostics).
Residual risk: an order whose checkout was opened on one origin and retried on the other within the same `attempt` reuses the open session (old return URL) — harmless because both origins work. Not deployed: deploy of the three functions needs the normal gate (QA → CTO → Founder), before or with the web release.
Commits: 574f12e, 738d481

## QA Re-test (AI QA & Security, 2026-10-18) — PASS

Env: worktree /home/user/wynteam-web @ 729a3e2, local only (no env files, no Supabase/Stripe, no production requests; Chromium runs blocked *.wynos.online/*.supabase.co via host-resolver rules except the mapped local test host).
- Diff review 574f12e/738d481: only the origin comparison changed in checkout and cancel (`!==` single string -> `!isFoodWebOrigin()`); auth, order ownership, status and amount checks in both functions untouched. Geocode: one line added to `ALLOWED_ORIGINS` (both the preflight and POST checks use the same exact `Set.has`). No suffix/regex/wildcard, deny by default.
- Open redirect: `success_url`/`cancel_url` origin comes from `foodReturnOrigin()` = request origin only if it is in the 2-entry set, otherwise the constant ZOKY origin. Probed with Deno: `https://zoky.wynos.online\n`, leading space, `%2f`, `@evil.com`, `HTTPS://…`, trailing slash, `.evil.com`, `null`, missing -> all rejected / fall back to ZOKY. Order number still `encodeURIComponent`-ed.
- Test mode: still no origin check; only change is the default return origin (ZOKY instead of food). Product name `ZOKY #<order>`.
- Deno 2.9.6 (npm package `deno@2`, scratchpad install): `deno check` on the 3 touched index.ts = pass; CI-equivalent `deno check supabase/functions/*/index.ts` (17 functions) = pass; `deno test --allow-read supabase/functions/` = 118 passed / 0 failed; deploy-gate commands per function (`deno check index.ts` + `deno test` in function dir) pass; food-stripe-checkout 9/9 incl. 3 new allowlist tests. Cross-function import `../food-stripe-checkout/_lib.ts` follows the existing `send-food-promotion` pattern.
- Regression: web lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344, `npm run test:notifications` 60/60, `npm run build` pass, freeze guard PASS, Playwright `wynos-food-developer-preview` + `wynos-merchant` on Chromium (chromium-android + chromium-desktop, /opt/pw-browsers/chromium) 134/134 pass against local `next start`.
Notes for CTO (not blocking): (1) Stripe product name changed to `ZOKY #…`, while handoff checklist item 5 / "not done" item 2 still say Stripe branding stays until Q10 — confirm this is intended and update the handoff. (2) Not executed against a real Stripe/Supabase project; staging live-origin + success/cancel check still required. Deploy of the 3 functions must go through the gate before/with the web release.
