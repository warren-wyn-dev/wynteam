# Task — WYN-217 — WYNOS Merchant: order alert audible on iPhone, sticky push

Status: released via PR #983 (merged 2026-10-06); i18n follow-up in fix/merchant-alert-tips-i18n
Owner: AI Coding / AI QA & Security
Date: 2026-10-06
Branch: fix/merchant-order-alert-sound

## Founder direction

- "ระบบเสียงแจ้งเตือน ไม่ได้ยิน เสียงที่ต้องการ แล้วก็ไม่ดังนานๆ จนกว่าจะกดรับ … เหมือนแอปใหญ่ๆ" → "ทำAก่อน" (2026-10-06).
- Option A = web-only fixes. Option B (native Merchant app) is not part of this task.

## Scope (web only)

- iOS 17+: the order sound asks for a "playback" audio session, so the silent switch no longer mutes it while Merchant is open.
- Sound tries to resume when Merchant returns to the foreground.
- Merchant push banners: `requireInteraction`, `renotify` (only with a tag), long vibration. Other apps are unchanged.
- Tips in notification settings updated.
- Out of scope / platform limit: web push cannot play the WYNOS sound or ring continuously when Merchant is closed.

## QA & Security

Feature: Merchant order alert sound + merchant push banner
Environment: Linux container; Node test runner; Chromium 1194 (Playwright, real service worker + CDP push delivery); no real iOS/Android device
Test Cases:
1. iOS 17+ audioSession becomes "playback" before the sound plays (executed module, mocked navigator)
2. No audioSession (older browsers) → sound still plays
3. audioSession setter throws → no crash, sound still plays
4. Already "playback" → not reassigned
5. Server render (no window) → returns false, no crash
6. Real Chromium: merchant order push → requireInteraction true, renotify true, vibrate 7 steps
7. Merchant push without tag → shown, renotify false (no TypeError)
8. Social / Food / malformed `data.app` → unchanged plain banner
9. Same-tag re-delivery replaces instead of stacking (1 banner)
10. Regression: `test:notifications` (45), `merchant-order-screen` (5), Playwright native-push + wynos-merchant source specs (132), typecheck, eslint
11. Secret scan of the diff
Passed: 1–11
Failed: none from this change. 3 Playwright cases (`wynos-merchant.spec.ts:57`, live page) could not run: WebKit/headless shell not installed in the container (environment, also fails without the change)
Severity: no CRITICAL/HIGH. MEDIUM-1, LOW-1 below
Reproduction Steps: n/a
Expected / Actual: matched for all executed cases
Security Findings: none. `data.app` is compared as a strict string; no new data, routes, permissions or secrets
Recommendation:
- MEDIUM-1 (verify on device in staging): on iPhone the "playback" session may pause music the shop is playing from another app once Merchant audio starts. Acceptable for an order alert; confirm on a real iPhone.
- LOW-1: every Merchant push (ads credit, store suspension, tests) is sticky, not only orders. Optional follow-up: limit to pushes with `order_number`.
- Before production: real-device check on iPhone (iOS 17+, silent switch on) and Android Chrome (screen off, push banner stays).
Final Status: PASS

## Release

Merging `main` auto-deploys web → Founder approval required before merge.
Rollback: revert the merge commit.

## Post-merge finding

- `web` CI failed on PR #983: `test:i18n` ("every Thai UI string has English"). The two new tips had no English entry in `lib/i18n/en.ts`. QA ran `test:notifications` but not `test:i18n` — missed.
- Fix: English entries added, old tip entry removed. Every npm step of the `web` CI job (lint, typecheck, all test suites incl. i18n, build) passes locally.
- Lesson: before PR, run every step of `.github/workflows/web-next-ci.yml` → `web`, not only the related suites.
- Renamed WYN-216 → WYN-217 (WYN-216 is already used by store reviews).

## Follow-up — Android: WYNOS sound when Merchant is closed (2026-10-06)

Founder: "ทำให้มีเสียงแจ้งเตือน ของแอป ได้ไหม" → "ทำแค่ของเว็บแอป ก่อน".

- Web push cannot choose its sound. Android lets the store pick a sound per app/site channel, so Notification settings gets a card with a "ดาวน์โหลดเสียง WYNOS" link (`WYNOS-Merchant.wav`) and the steps. iPhone: not possible (stated in the card).
- QA LOW-1 fixed: only order pushes (`order_number`) are sticky; store news closes as usual.
- Missing English template from `c061dee` ("ออเดอร์ใหม่ #{0} · {1}") added; `main` failed `test:i18n` without it.
- Tests: every npm step of the `web` CI job passes locally (lint, typecheck, all suites, build); Merchant browser specs 45/45 incl. the live page on chromium desktop + android.
- Not tested: the Android sound picker on a real phone (menus differ by brand).
