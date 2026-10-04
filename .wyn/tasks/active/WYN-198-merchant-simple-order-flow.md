# Product Task — WYN-198 — Wynos Merchant: simpler order flow

Status: approved — released via PR #826
Owner: AI Product Manager / AI Coding
Date: 2026-10-03

## Founder direction

- "Wynos Merchant อยากให้ระบบใช้งานง่ายๆ เหมือนของ LINE MAN Merchant" (2026-10-03).
- AskUserQuestion: selected all four changes (buttons on order cards, new-order pop-up with sound, simple order page, bigger buttons and text). The slip check and accepting the order become **one button**.
- We borrow the ease-of-use patterns only. No LINE MAN branding, colours or layout copying. The Wynos look stays (mostly white, Merchant red accents).

## Scope (web only, no database change)

1. **Order card action**: each card has one big button for the next step.
   - Paid → "รับออเดอร์" (default prep time 30 minutes, or the order's ETA).
   - Slip waiting → "ดูสลิป · รับออเดอร์". It opens the order, because the store must look at the slip.
   - Preparing → "อาหารพร้อมแล้ว". Ready → "เริ่มจัดส่ง".
   - Out for delivery → "ส่งถึงแล้ว · แนบรูป". It opens the order, because the photo is required (WYN-193).
   - An order waiting for payment shows "รอลูกค้าโอนเงิน" instead of a button.
2. **New-order alert**:
   - A full-screen pop-up and a chime (Web Audio, no file), plus vibration. It repeats every 2.5 seconds until the store opens or closes the alert, for at most 3 minutes.
   - It shows for new orders that are paid or have a slip waiting. A new slip after "สลิปมีปัญหา" alerts again.
   - Browsers allow sound only after the first tap, and the alert says so.
3. **Order page**:
   - Four tabs: ใหม่ / กำลังทำ / กำลังส่ง / เสร็จแล้ว.
   - Search and filters sit behind the search button. Closing them clears them.
4. **Order detail**:
   - The next-step box is at the top.
   - "เงินเข้าแล้ว · รับออเดอร์" marks the payment paid and accepts the order in one tap.
   - "สลิปมีปัญหา" asks for a new slip.
5. **Bigger** card text, tabs, buttons and nav labels.

## Unchanged rules

- Accepting still requires a paid order (server). The combined button calls the existing `food_set_payment_status` and then `food_transition_order`. If the second call fails, the order stays paid and the card offers "รับออเดอร์".
- A delivery photo is still required.

## Acceptance criteria

1. A paid new order can be accepted from the card in one tap.
2. A slip-waiting order is accepted in one tap after opening it. The slip is shown above the button.
3. A paid or slip-waiting new order shows the pop-up with sound once the screen has been tapped. Closing it stops the sound.
4. No horizontal overflow at 320px. Thai and English strings are present. Food/Merchant specs, typecheck, lint and i18n pass.

## Also in this PR

- `wynos-merchant.spec.ts:8` expects the new app name "Wynos Merchant" that main set in 45c5818. The test was failing on main.

## Release

Merge (web auto-deploys). No migration. Rollback: revert the merge commit.
