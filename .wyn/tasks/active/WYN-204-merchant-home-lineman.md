# Product Task — WYN-204 — Wynos Merchant: LINE MAN–style home and four tabs

Status: awaiting Founder approval (PR review and merge)
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- Founder shared LINE MAN Merchant screenshots: "ชอบ LINE MAN มาก ดูใช้งานง่าย".
- Picked all four parts: store header and open-store bar, sales card and shortcuts, setup checklist, and a bottom bar with "หน้าหลัก · รับออเดอร์ · เมนู · เพิ่มเติม".
- Wynos red and our own icons. No LINE MAN logos, images or ads/finance features we do not have.

## Scope (web only)

- Home: the store name in large type, an open/close pill (a switch) with an edit-store button, then tiles:
  - today's sales (opens reports)
  - orders to handle (opens orders)
  - campaigns
  - menu (dishes on sale)
  - store settings
- "เตรียมร้านให้พร้อมขาย (x/4)" checklist, built from existing data: logo, payment method, at least one dish on sale, published. It is hidden when complete or suspended, and each step links to where it is fixed.
- Four bottom tabs. "เพิ่มเติม" holds reports, campaigns (moved out of store settings), store settings, notifications, sound test, install and sign out. Each sub-page has a back button.
- The order list "ต้องจัดการตอนนี้" stays on home. No data, API or database changes.

## Acceptance criteria

1. Home and tabs work at 320, 390 and 768 px with no horizontal scroll.
2. The open/close switch behaves as before, including the suspension rules from WYN-203.
3. Reports, campaigns and store settings are reachable from home tiles and from "เพิ่มเติม".
4. Merchant specs, typecheck, lint and i18n pass.

Rollback: revert the merge commit (web only).
