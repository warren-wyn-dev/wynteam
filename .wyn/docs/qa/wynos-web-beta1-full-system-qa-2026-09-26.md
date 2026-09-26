# WYNOS Web Beta1 — Full-System QA & Security (2026-09-26)

Role: AI QA & Security · Requested by Founder ("ตรวจ QA ทั้งระบบให้หน่อย") · Code under test: `main` @ `0214d9d` (includes #721–#724)

```
Feature: WYNOS Web Beta1 (web/) — whole system before opening to users:
         functional, authn/authz, security/privacy, notifications/Push, chat, posts,
         clubs, profile, signup, uploads, account switching
Environment: Cloud sandbox (Linux). Next.js dev server + Playwright Chromium
             (chromium-android, chromium-desktop). No WebKit binary locally (CI covers
             webkit-iphone). No production Supabase credentials and no physical device.
             Production reachable read-only for HTTP header checks (https://wynos.online).
Test Cases:
  A. Automated — `npm run check` (lint, typecheck, all node test suites, production build)
  B. Automated — full Playwright suite, 540 cases on Chromium (all browser specs:
     auth/signup security, password recovery, Google PWA OAuth, account switch
     cross-tab, composer/drafts/uploads (image limit), post detail, quote/repost,
     follow, share, search, trending, profile/external link, clubs, chat inbox,
     notifications, native Push/service worker, PWA install/cache, accessibility)
  C. CI evidence on the same code — GitHub Actions for #724 head `1bfd1bf`:
     web, browser-qa (incl. webkit-iphone), signup-security, Supabase PostgreSQL
     integration (SQL/RLS tests), Edge Functions (Deno), Flutter, Admin — all success
  D. Secret exposure — tracked files scanned for JWT/sbp_/AIza/private keys/.env
  E. Authorization — every table/RPC/bucket the web writes to vs. RLS in
     supabase/schema.sql + migrations_*.sql (RLS enabled, policy per command,
     owner scoping on push_tokens, notifications, messages, conversations,
     profile_private, user_presence, storage paths; private-club isolation in
     migrations_wyn185; is_verified/platform_role guards)
  F. Client security — XSS sinks (dangerouslySetInnerHTML), link rendering
     (javascript:/data: rejection, rel=noreferrer), open redirects, SW push
     click routing (UUID-only targets), image host allow-list (next/image)
  G. Dependencies — `npm audit --omit=dev`
  H. Production HTTP security headers — `curl -sSI https://wynos.online/`
  I. Abuse — rate limits / notification dedupe in DB triggers
Passed:
  A ✅ exit 0 (0 lint errors; 3 pre-existing warnings in untouched files)
  B ✅ 521 passed, 19 skipped (skips are pre-existing conditional specs), 0 failed
  C ✅ all green
  D ✅ no real secrets tracked (only test-generated PEM fixtures and .env.example placeholders)
  E ✅ RLS enabled on all 37 tables the web reads or writes; owner/participant scoping correct;
       ignoreDuplicates upserts compatible with policies; private clubs not exposed
  F ✅ no XSS sink; external links http(s)-only; redirects internal-only; SW push
       targets validated; remote images restricted to the Supabase host
  G ✅ 0 known vulnerabilities in production dependencies
Failed:
  H ❌ WEB-B1-QA-01 — no clickjacking / nosniff / referrer headers on production
  I ❌ WEB-B1-QA-02 — follow/like toggling floods notifications + Push (no dedupe/rate limit)
  E ❌ WEB-B1-QA-03 — storage buckets have no server-side MIME/size limit (pre-existing)
  E ⚠ LOW — profiles.referral_code is user-updatable (vanity/impersonation of codes);
       no bug file, fold into a later hardening task
Severity: CRITICAL 0 · HIGH 0 · MEDIUM 3 · LOW 1
Reproduction Steps: see each bug file in .wyn/tasks/bugs/WEB-B1-QA-0{1,2,3}-*.md
Expected: security headers present; repeated identical events collapse; buckets
          reject non-image/oversized uploads server-side.
Actual: as listed under Failed.
Security Findings: 3 MEDIUM + 1 LOW above. No CRITICAL/HIGH. No secret exposure,
  no cross-user data access path found in RLS review, no dependency CVEs.
Recommendation:
  1. Founder/device smoke test (NOT done by QA — no device/credentials here):
     installed-PWA iPhone + Android — enable Push, background Push banner + tap
     routing, bell and Chat badges count up and clear, account switch then Push
     goes only to the active account, signup → onboarding → first post with image.
  2. Fix WEB-B1-QA-01 (small, config-only) before opening broadly.
  3. Fix or explicitly accept WEB-B1-QA-02 and WEB-B1-QA-03 (DB changes → Founder
     applies migration).
  4. Keep the soft-launch plan (small cohort 2–3 days) until 1–3 are done; ship
     database release #716 (notifications Realtime publication) afterwards.
Final Status: FAIL at the time of this run → **PASS on 2026-09-26** after all findings were
              resolved and the Founder completed the real-device checks (see "Final sign-off")
```

## Why FAIL when there is no CRITICAL/HIGH

Per `.wyn/agents/qa-security.md` QA must not approve anything that was not actually tested.
The highest-risk user journeys for this release — real Push delivery on an installed iPhone/Android
PWA, and end-to-end flows against the live Supabase backend — could not be exercised from this
environment. Three MEDIUM findings are also open. None of them is a release blocker under
AGENTS.md (only CRITICAL blocks; HIGH needs Founder acceptance), so the Founder may choose to
accept them — but QA cannot mark the release PASS until item 1 above is verified.

## Scope notes

- Previously fixed today and verified in this run: background Push after service-worker restart
  (#721), notification list truncation (#721), recipient-scoped Push data (#722), foreground
  listener removal (#723), bell/Chat unread counts + out-of-order guard (#724).
- One WebKit-only CI flake seen today (`composer-handle-drag.spec.ts:52`, passed on re-run and on
  #723/#724) — test hydration timing, not a product bug; proposed test fix is in PR #723's comment.

## Addendum — findings resolved and live (2026-09-26)

| Finding | Resolution | Evidence |
|---|---|---|
| WEB-B1-QA-01 | Security headers on every route (PR #725) | `curl -sSI https://wynos.online/welcome` → `x-frame-options: DENY`, `content-security-policy: frame-ancestors 'none'`, `x-content-type-options: nosniff`, `referrer-policy: strict-origin-when-cross-origin`; `tests/browser/security-headers.spec.ts` |
| WEB-B1-QA-02 | Notification flood guard trigger (production) | apply run `36250193842` verify `flood_guard_trigger=1`; `supabase/tests/web_beta1_qa_hardening_test.sh` in CI |
| WEB-B1-QA-03 | Bucket MIME/size limits (production) + web upload validator | apply run verify `limited_buckets=4`; `tests/upload-image.test.mjs` |
| LOW referral_code | Guard trigger (production) | apply run verify `referral_guard_trigger=1` |
| WebKit composer flake | Test waits for React state | PR #725 CI browser-qa green |

Security status: **CRITICAL 0 · HIGH 0 · MEDIUM 0 open · LOW 0 open.**
Remaining before PASS: real-device smoke test by the Founder (Push on installed iPhone/Android PWA,
badges, account switch, signup → first image post) and a real email-delivery test. Email confirmation
stays off by Founder decision (accepted, temporary bot-signup risk).

## Final sign-off — PASS (2026-09-26)

The only item left in the addendum above, real-device testing, is done. The Founder ran it on their
own phones and reported all of it passing: "ไม่มี เรียบร้อยหมด" (2026-09-26), in reply to the checklist below.

| Check (Founder, real device) | Result |
|---|---|
| Push enabled in installed PWA (iPhone/Android), background banner, tap opens the right screen | Pass |
| Bell and Chat unread badges count up and clear | Pass |
| Account switch: Push reaches only the active account | Pass |
| Signup → onboarding → first post with image | Pass |
| Password-reset email is delivered | Pass |
| Shared link tapped in LINE opens in Safari (PR #729) | Pass |
| Pinch/double-tap zoom disabled (PR #729, Founder decision) | Pass |

Post-QA fixes shipped the same day and included in this sign-off:
- PR #727: `/@username` and @mention links no longer 404; a shared link survives login and
  signup; Open Graph link previews added. WYN-158 Production Deploy #276 success.
- PR #729: LINE's in-app browser is sent on to Safari/Chrome (`openExternalBrowser=1`); a
  notice for other in-app browsers; zoom disabled. WYN-158 Production Deploy #277
  (`36259469284`) success on `d0ed2dc`. Verified on https://wynos.online: LINE UA → 307 to
  `?openExternalBrowser=1`; Safari and LINE preview bot → 200; viewport has
  `maximum-scale=1, user-scalable=no`; security headers present.

Known non-blocking items:
- Email confirmation at signup stays **off** by Founder decision (temporary bot-signup risk, accepted).
- Flaky test, not a product bug: `wynos-food-customer-demo.spec.ts:41` (chromium-android,
  developer-only Food demo) sometimes clicks before hydration. It fails on `main` too.

Security status at sign-off: **CRITICAL 0 · HIGH 0 · MEDIUM 0 open · LOW 0 open.**

**Final Status: PASS.** WYNOS Web Beta1 is cleared for the public launch to the first users.
