# Bug Report — ZOKY-141

Status: bugs
Severity: LOW (accessibility gaps vs spec section 10; the `Sheet` component and the badge order already behaved this way
on `release/zoky-web-20261018` @ 0533fb36 — not a regression, but the new Home/Food now rely on more sheets)
Owner: AI Debug Engineer
Found by: AI QA & Security, branch `feat/zoky-web-app-design` @ cc823142, 2026-10-19

Bug:
1. Sheets (ร้านโปรด, ร้านยอดนิยม "ดูทั้งหมด", รวมโค้ดลดเพิ่ม, ตัวกรอง, สั่งอีกครั้ง) do not close on `Esc`, do not move focus
   inside when opened and do not give focus back when closed. Spec 10: "เปิด sheet ย้าย focus เข้า, ปิดคืน focus เดิม, `Esc` ปิดได้".
2. Bottom nav order badge is read before the tab name: accessible name "1 ออเดอร์ที่กำลังดำเนินการ ออเดอร์".
   Spec 7.1: badge read after the tab name.

Reproduction (local production build, mocked Supabase, Chromium 390/430/820): open Home → tap the heart → press `Esc`:
dialog still open (same on base build 0533fb36); `document.activeElement` is not inside `[role=dialog]`. ARIA snapshot of
`nav "เมนูหลัก"` shows `button "1 ออเดอร์ที่กำลังดำเนินการ ออเดอร์"`.

Root Cause: `Sheet` in `web/components/food/wynos-food-developer-app.tsx` has no keydown/focus handling;
`ZokyBottomNav` in `web/components/food/zoky-web-ui.tsx` renders the badge before `<small>{label}</small>`.

Fix (suggested): add an `Escape` listener + initial focus + focus restore in `Sheet`; for the nav, give the button an
explicit `aria-label` of `{label}` / `{label}, {n} ออเดอร์ที่กำลังดำเนินการ` and hide the badge from the name.
Files Changed: (to be filled)
Tests: browser check Esc closes and focus returns; ARIA name of the orders tab starts with "ออเดอร์".
Regression Risk: low (Sheet is used by cart/checkout/order sheets too — verify those).
Handoff to QA: can ship after ZOKY-140 or be scheduled as a follow-up (Founder/CTO decision).
