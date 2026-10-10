# Product Task — WYN-205 — Wynos Merchant: finance, ads, campaigns, promotions shortcuts

Status: approved — releasing PR #833
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- Founder, on the live home: "ตรงนี้ให้มีแค่ การเงิน โฆษณา แคมเปญ โปรโมชั่น".
- Asked to build all four systems ("ทำครบทั้ง 4 ระบบเลย"). Decisions:
  - Ads: pay per click, controlled from WYNOS Admin.
  - Ad payment: PromptPay transfer plus slip.
  - Campaigns: WYNOS Admin designs them.
  - Ad placement: recommended stores on the Food home page, plus the top of search.
- Delivered in three releases: WYN-205 (this one), WYN-206 (WYNOS campaigns), WYN-207 (CPC ads).

## Scope (web only, no database change)

- Home shortcut row: การเงิน · โฆษณา · แคมเปญ · โปรโมชั่น, with new 3D icons (wallet, megaphone, gift, price tag).
- การเงิน: a new page built from the store's loaded orders.
  - Money received today, this week and this month.
  - Waiting for slip check, and refunded or pending refunds.
  - Payment channels, masked to the last 4 digits, with an edit link.
  - Recent money activity.
- โปรโมชั่น: the existing store discount system (formerly "Campaign Center", or "แคมเปญ"), renamed so that "แคมเปญ" can mean WYNOS campaigns.
- แคมเปญ and โฆษณา: "เร็วๆ นี้" pages explaining what is coming, until WYN-206 and WYN-207 ship.
- "เพิ่มเติม" lists all of these too.

## Acceptance criteria

1. The four shortcuts open the right pages, and the back button returns to "เพิ่มเติม".
2. Finance totals match paid, submitted and refunded orders, and account numbers are masked.
3. Promotions work exactly as before.
4. Merchant specs, unit tests, typecheck, lint and i18n pass.

Rollback: revert the merge commit (web only).
