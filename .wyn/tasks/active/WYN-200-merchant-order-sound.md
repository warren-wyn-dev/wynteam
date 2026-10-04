# Product Task — WYN-200 — Wynos Merchant: own order alert sound

Status: review — PR open, waiting for Founder approval to merge (web only)
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "เพิ่มเสียงการแจ้งเตือน ที่เป็นของตัวเอง ไม่ติดลิขสิทธิ์" (2026-10-04).

## Scope (web only)

- `web/public/sounds/wynos-merchant-order.wav`: an original 1.45 s rising four-note chime.
  - `web/scripts/generate-merchant-order-sound.py` synthesizes it from plain sine tones, with no samples or third-party audio, so WYN owns it outright.
  - Running the script rebuilds the exact same file.
- The new-order alert (WYN-198) plays this sound. If the file cannot load, it falls back to the old tones.
- Preview buttons:
  - "ลองฟังเสียงแจ้งเตือน" in the notification sheet (WYN-199).
  - "เสียงแจ้งเตือนออเดอร์" in Merchant → ร้านค้า. Tapping it also unlocks sound on that phone.

## Known limit

- The sound plays inside the open Merchant app.
- Push notifications that arrive while the app is closed use the phone's own notification sound, because web apps cannot set a custom sound for system notifications on Android Chrome or iOS.
- A custom sound for closed-app notifications needs a native app (the Flutter app), as a separate task.

## Release

Merge (web auto-deploys). Rollback: revert the merge commit.
