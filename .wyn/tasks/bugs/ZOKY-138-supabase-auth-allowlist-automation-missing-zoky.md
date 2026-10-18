# Bug Report — ZOKY-138

Status: bugs
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
