# Product Task — WYN-204 — Wynos Merchant: simple Wynos home, 3D shortcuts and four tabs

Status: awaiting Founder approval (PR review and merge)
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- Founder shared LINE MAN Merchant screenshots: "ชอบ LINE MAN มาก ดูใช้งานง่าย".
- Picked all four parts: store header and open-store bar, sales card and shortcuts, setup checklist, and a bottom bar with "หน้าหลัก · รับออเดอร์ · เมนู · เพิ่มเติม".
- Wynos red and our own icons. No LINE MAN logos, images or ads/finance features we do not have.
- Founder: "อยากได้ UX UI ไม่ซ้ำใคร เรียบง่าย ใช้งานง่าย ปุ่มไอคอน 3D สวยๆ". Added Wynos's own 3D icon set (SVG, `merchant-3d-icons.tsx`) for the shortcut tiles and the "เพิ่มเติม" grid.

- Founder asked whether the layout was too close to LINE MAN, reviewed a Wynos alternative, and said: "ผมชอบดีไซน์เรียบๆ ใช้งานง่าย ดูแล้วเข้าใจ ไม่งง". AI recommended the simpler Wynos layout below.

## Scope (web only)

- Home (Wynos layout):
  - One red "today" card holds the store name, the edit button, today's sales (opens reports) and a large open/close switch.
  - Below it, one row of 3D shortcuts: orders to handle (with a count badge), menu, campaigns, reports.
  - Then "ต้องจัดการตอนนี้", then a "ร้านพร้อมขาย x%" bar using the publish readiness rules. The bar is hidden when complete or suspended, and it expands to show each step with a link to fix it.
- Four bottom tabs. "เพิ่มเติม" holds reports, campaigns (moved out of store settings), store settings, notifications, sound test, install and sign out. Each sub-page has a back button.
- The order list "ต้องจัดการตอนนี้" stays on home. No data, API or database changes.

## Acceptance criteria

1. Home and tabs work at 320, 390 and 768 px with no horizontal scroll.
2. The open/close switch behaves as before, including the suspension rules from WYN-203.
3. Reports, campaigns and store settings are reachable from home tiles and from "เพิ่มเติม".
4. Merchant specs, typecheck, lint and i18n pass.

Rollback: revert the merge commit (web only).
