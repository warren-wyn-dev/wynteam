# Bug Report — WEB-B1-QA-01 (MEDIUM) No clickjacking / content-sniffing protection headers

Status: resolved — live in production 2026-09-26 (PR #725, deploy #275, DB apply run 36250193842)
Owner: AI Debug Engineer
Found by: AI QA & Security — WYNOS Web Beta1 full-system QA, 2026-09-26
Bug: Production `https://wynos.online/` responses carry only `strict-transport-security`.
There is no `X-Frame-Options` / CSP `frame-ancestors`, no `X-Content-Type-Options: nosniff`,
no `Referrer-Policy`. Neither `web/next.config.ts` (`headers()`), `web/vercel.json` nor a
middleware/proxy sets them.
Reproduction: `curl -sSI https://wynos.online/` → only `strict-transport-security: max-age=63072000`.
Any third-party site can `<iframe src="https://wynos.online/...">` a signed-in user's session and
overlay it (clickjacking on one-tap actions: follow, like, repost, accept message request, club join).
Root Cause: No security header configuration was ever added to the Next.js web app.
Fix: (proposed, not applied) add `headers()` in `web/next.config.ts` for `/:path*`:
`X-Frame-Options: DENY`, `Content-Security-Policy: frame-ancestors 'none'`,
`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.
A full script CSP is a larger change (Firebase, Supabase, Vercel analytics origins) — separate task.
Files Changed: —
Tests: add a Playwright/request test asserting the headers on `/` and `/welcome`.
Regression Risk: Low. Check nothing legitimately frames the app (Google OAuth popup flow does not).
Handoff to QA: re-run `curl -sSI` on a preview deploy.

Resolution (2026-09-26): `web/next.config.ts` headers() + `tests/browser/security-headers.spec.ts` (fails without the headers, passes with them). Ships with the web deploy.
