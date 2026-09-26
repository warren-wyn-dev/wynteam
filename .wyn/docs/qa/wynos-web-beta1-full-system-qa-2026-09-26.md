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
Final Status: PASS
```

## Status history

- **Initial run (code `0214d9d`): FAIL.** Three MEDIUM findings were open and the real-device checks were not done.
- **Sign-off (release `d0ed2dc`, 2026-09-26): PASS.** See "Final sign-off" below. The "Final Status" field above is the current result.

## Why the initial run was FAIL when there was no CRITICAL/HIGH

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
| WEB-B1-QA-03 | Bucket MIME/size limits (production) + web upload validator. Partial: content is not validated and octet-stream stays allowed → WEB-B1-QA-04 (LOW, open) | apply run verify `limited_buckets=4`; `tests/upload-image.test.mjs` |
| LOW referral_code | Guard trigger (production) | apply run verify `referral_guard_trigger=1` |
| WebKit composer flake | Test waits for React state | PR #725 CI browser-qa green |

Security status at the time of this addendum: **CRITICAL 0 · HIGH 0 · MEDIUM 0 open · LOW 0 open.** (Superseded at sign-off below: WEB-B1-QA-04, LOW, is open.)
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

### Release under sign-off and its evidence

PASS applies to **`main` @ `d0ed2dc4d8f5e1403b02e44046e70fca319489ad`**, which is live on https://wynos.online
(WYN-158 Production Deploy #277, run `36259469284`). The 540-case run above was against `0214d9d`.
The evidence for the released commit is:

| Evidence | Commit | Result |
|---|---|---|
| PR #729 CI: `web` (lint, typecheck, node suites, build), `browser-qa` (full Playwright incl. webkit-iphone, run `36258362960`), `signup-security`, Supabase PostgreSQL SQL/RLS, Edge Functions, Flutter, Admin | `706dd4a` (same tree as `d0ed2dc`: merged with no other change on `main`) | all success |
| `main` push CI after merge (run `36259469147`) and Web Beta1 Signup Security QA (run `36259469170`) | `d0ed2dc` | success |
| Local full Playwright on Chromium (chromium-android + chromium-desktop), code of #729 | `706dd4a` | 555 passed, 19 skipped, 2 failed. Both failures are unrelated to #729: the Food demo flake (see below), and `signup-security.spec.ts:6`, which failed only under full-suite load and passed 6/6 on re-run |
| Production checks (HTTP): LINE UA 307 → `?openExternalBrowser=1`; Safari/preview bot 200; zoom-off viewport; security headers | `d0ed2dc` | pass |
| Founder real-device checks (table above) | `d0ed2dc` | pass |

### Open findings at sign-off

- **LOW — WEB-B1-QA-04 (open, non-blocking):** the upload bucket allow-list still accepts
  `application/octet-stream`, the Flutter fallback type. Nothing server-side checks file
  content, so a signed-in user who calls the Storage API directly can store a non-image file
  (≤10/20 MB) under their own path. Browsers download that type rather than render it, and
  `nosniff` is set, so it cannot run script on wynos.online. The residual risk is file hosting
  or abuse inside WYNOS buckets.
  WEB-B1-QA-03 is therefore resolved only for script-capable and oversized uploads, not for
  content validation. See `.wyn/tasks/bugs/WEB-B1-QA-04-storage-octet-stream-no-content-validation.md`.

Security status at sign-off: **CRITICAL 0 · HIGH 0 · MEDIUM 0 open · LOW 1 open (WEB-B1-QA-04).**
Under AGENTS.md, only CRITICAL blocks a release and HIGH needs Founder acceptance, so the open LOW
does not block.

Result: WYNOS Web Beta1 at `d0ed2dc` is cleared for the public launch to the first users.
