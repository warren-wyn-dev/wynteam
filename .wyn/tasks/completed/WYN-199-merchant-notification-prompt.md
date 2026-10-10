# Product Task — WYN-199 — Wynos Merchant: ask for notifications on open

Status: approved — released via PR #827
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "เวลากดเข้าไอคอน ควรถาม/ขออนุญาต เปิดการแจ้งเตือนทันทีนะ" (2026-10-04).

## Scope (web only, no database change)

- When Merchant opens and this device does not receive order notifications yet, a sheet appears right away: "เปิดการแจ้งเตือนออเดอร์".
  - "อนุญาตการแจ้งเตือน" runs the existing Push flow (`subscribeToPushNotifications`): the permission request first, then the device token in `push_tokens`.
  - "ไว้ทีหลัง" hides the sheet until the app is opened again (one browser session).
- The browser only shows its permission dialog after a tap, so the sheet's button provides that tap.
- Already enabled on this device (`isCurrentDevicePushEnabled`) → no sheet.
- Blocked (permission denied) → the sheet explains how to allow it in the phone or browser settings.
- iPhone not installed to the Home Screen → the sheet explains that it needs installing first.
- No browser support or no server Push config → no sheet, so the store isn't nagged about something it can't fix.
- The bell button opens the same sheet. Previously it only asked for the browser permission and did not register the device for Push.
- The sheet never covers the new-order alert or another open sheet.

## Acceptance criteria

1. Opening Merchant on a device without notifications shows the sheet straight away.
2. Allowing registers the device, and the sheet does not appear again.
3. "ไว้ทีหลัง" hides it until the next time the app is opened.
4. The bell button opens the sheet at any time.
5. Merchant specs, typecheck, lint and i18n pass.

## Release

Merge (web auto-deploys). Rollback: revert the merge commit.
