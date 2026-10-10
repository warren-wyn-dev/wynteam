# Product Task — WYN-208 — Wynos Merchant bottom-bar icons

Status: approved — Founder "อนุมัติ" 2026-10-04; releasing PR #840
Owner: AI Design / AI Coding
Date: 2026-10-04

## Founder direction

- "ออกแบบไอคอนด้านล่างให้หน่อย" (screenshot circling the Merchant bottom nav).
- Standing direction: simple and easy to understand, Wynos red leads, no rainbow.

## Scope

- Replace the generic lucide icons in the four bottom tabs with Wynos's own icons (`web/components/merchant/merchant-nav-icons.tsx`):
  - หน้าหลัก: storefront with an awning.
  - รับออเดอร์: order ticket with a torn edge.
  - เมนู: rice bowl with chopsticks (matches the 3D menu icon).
  - เพิ่มเติม: three rounded tiles and a circle.
- Idle tabs: grey outline (`currentColor`). Selected tab: solid Wynos red `#e32636` with white details.
- Labels, layout, badge and tab behaviour are unchanged. Frontend only; no database, API or auth change.

## Verification

- `npx tsc --noEmit`, eslint and `npm run test:i18n` pass.
- `tests/browser/wynos-merchant.spec.ts` and `wynos-food-developer-preview.spec.ts`: 90 passed, including the new WYN-208 assertions.
- Rendered preview with the real `merchant.css` for each selected tab.

## Rollback

Revert the PR; the nav returns to the lucide icons.
