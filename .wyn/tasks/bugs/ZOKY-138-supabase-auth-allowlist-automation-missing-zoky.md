# Bug Report — ZOKY-138

Status: verified — closed (QA re-test PASS, 2026-10-18; release consideration below)
Severity: LOW (auditability / config drift; becomes a login blocker if the manual step is missed)
Owner: AI Debug Engineer / DevOps
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ ffd3ac6, 2026-10-18

Bug:
`.github/scripts/sync-auth-password-policy.sh` (+ `.github/scripts/test-auth-password-policy.sh`) asserts the Supabase
Auth `uri_allow_list` contains the food.wynos.online callbacks but has no zoky.wynos.online entries. The handoff relies on a
manual dashboard change for `https://zoky.wynos.online/food/auth/callback`, `/auth/callback?next=%2Ffood`, `/reset-password**`.
If the manual step is missed, Google login / email confirm / password reset from ZOKY fall back to the Site URL
(wynos.online) and fail (PKCE verifier is on the zoky origin). Not a token-leak risk (fallback is a trusted WYNOS origin).

Reproduction: `grep -n zoky .github/scripts/sync-auth-password-policy.sh` → no match.

Fix: in the approved cutover change, add the exact zoky URLs to the script's required list (additive, keep food entries) and its test; or record the manual change + verification in the deployment record.
Tests: `.github/scripts/test-auth-password-policy.sh` with fake state.
Regression Risk: Low (script is additive).
Handoff to QA: verify allowlist on staging Supabase before smoke.

## Fix Record (AI Coding, 2026-10-18, Founder approval 2026-10-18)

Freeze check: `tools/check_wynos_release_freeze.py` only checks the production deploy workflows/acceptance script; it does not cover these scripts and still prints PASS after the change.
Fix: `.github/scripts/sync-auth-password-policy.sh` additively requires and post-verifies `https://zoky.wynos.online/food/auth/callback`, `https://zoky.wynos.online/auth/callback?next=%2Ffood`, `https://zoky.wynos.online/reset-password?returnTo=%2Ffood%2Flogin` (exact URLs, same style as the existing food entries; food entries kept). `test-auth-password-policy.sh` updated (expected list) + new idempotency case with all entries present.
Tests: `bash -n` ok; `bash .github/scripts/test-auth-password-policy.sh` pass (offline fake curl, no Supabase contact); freeze guard PASS.
IMPORTANT: `.github/workflows/web-beta1-auth-password-policy.yml` runs the `apply` job on push to `main` when these scripts change → merging this branch to main will PATCH the production Supabase Auth allowlist immediately (additive only, before the web deploy). Founder/DevOps should treat the merge as that config change, or merge the ZOKY-138 commit together with the release.
Open: whether Supabase matches the reset URL with its query exactly — verify on staging; if not, add `https://zoky.wynos.online/reset-password**` manually.
Commit: 5e0bec5

## QA Re-test (AI QA & Security, 2026-10-18) — PASS

Env: worktree /home/user/wynteam-web @ 729a3e2, local only (no env files, no Supabase/Stripe, no production requests; Chromium runs blocked *.wynos.online/*.supabase.co via host-resolver rules except the mapped local test host).
- Diff review 5e0bec5: add-only. Three exact URLs appended to the required loop and to the post-update `jq` verification; no existing entry removed, no wildcard. Reset URL matches what the app builds (`/reset-password?returnTo=` + `encodeURIComponent("/food/login")` = `%2Ffood%2Flogin`, `web/lib/auth-repository.ts:103`).
- `bash -n` ok; `bash .github/scripts/test-auth-password-policy.sh` pass (fake curl on PATH, offline token, no Supabase contact) incl. new idempotency case (no extra PATCH). Freeze guard PASS.
- RELEASE CONSIDERATION: `.github/workflows/web-beta1-auth-password-policy.yml` job `apply` runs on push to `main` touching these scripts (and after every successful `WYN-158 Production Deploy`) -> merging this branch PATCHes the production Supabase Auth allowlist immediately (additive). Founder/DevOps must treat the merge as that change. Open: confirm on staging that Supabase matches the reset URL with query; otherwise add `https://zoky.wynos.online/reset-password**` manually.
- Regression: web lint 0 errors (17 existing warnings), typecheck pass, `node --test tests/*.test.mjs` 344/344, `npm run test:notifications` 60/60, `npm run build` pass, freeze guard PASS, Playwright `wynos-food-developer-preview` + `wynos-merchant` on Chromium (chromium-android + chromium-desktop, /opt/pw-browsers/chromium) 134/134 pass against local `next start`.
