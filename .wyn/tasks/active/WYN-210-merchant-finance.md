# Product Task — WYN-210 — Wynos Merchant finance page redesign

Status: approved — Founder "อนุมัติ" 2026-10-04; releasing PR #849 and applying the migration
Owner: AI Product Manager / AI Design / AI Coding
Date: 2026-10-04

## Founder direction

- Shared a screen recording of another delivery app's finance page as an example of the content, and said not to copy it ("อย่าก็อป").
- Reviewed designs A–D, then specified the page:
  - "การเงิน / สรุป"
  - Periods: "วันนี้ เมื่อวาน สัปดาห์นี้ เดือนนี้", plus a calendar to pick a date range: "ปฎิทินเลือกวันได้ว่าวันไหนถึงวันไหน".
  - Headline numbers: "ยอดขายสุทธิ" and "รายได้".
- WYNOS line: "โอเค ตามนั้น". Rename it "เงินที่ WYNOS จะโอนให้ร้าน" and hide it when the amount is 0.

## Scope

- Period chips: วันนี้ · เมื่อวาน · สัปดาห์นี้ (Monday start) · เดือนนี้ · เลือกวัน.
  - เลือกวัน opens a calendar sheet: tap the first day, then the last day.
  - Future days are disabled. A range can be at most 1 year.
- **ยอดขายสุทธิ** = what customers paid in the range (food + delivery − promotion discounts) − refunds.
- **รายได้ร้าน** = ยอดขายสุทธิ − ad spend + WYNOS's share of campaign discounts.
- Each headline number has a breakdown card.
- Mini stats: orders, average per order, and change vs the previous period of the same length.
- "เรื่องเงินที่ต้องดู" lists:
  - slips waiting for review, which opens the orders tab;
  - "เงินที่ WYNOS จะโอนให้ร้าน", which opens the campaigns tab.
  - Each row shows only when it is above 0.
- CSV download for the range: one row per day plus a total row, UTF-8 with BOM so Thai text opens correctly in Excel.
- Payment channels (masked to the last 4 digits) stay at the bottom.
- The old "รายการล่าสุด" list is removed; the orders tab already lists every order.
- Not included, because WYNOS does not have them: GP commission and an e-payment wallet.

## Technical design

- New read-only RPC `public.merchant_finance_summary(store, from, to)` in `supabase/migrations_wynos_merchant_finance_v1.sql`.
  - Days are counted in Bangkok time.
  - Sales are counted by `paid_at`, refunds by `refunded_at`, ads by `click_day`.
  - WYNOS share is counted for delivered, non-refunded orders.
  - Discounts are derived as `subtotal + delivery_fee − total`, so the lines always add up.
- Access: the store's owner, admin or manager only (legacy `food_staff`: owner only).
  - This is narrower than the old page, which any merchant role could open, because these are store finances.
  - The check is written in the RPC instead of using `merchant_has_store_role()`, which lets every developer account into any store and ignores roles for legacy `food_staff` (Codex review on PR #849).
  - `security definer`, `stable`, no grant to anon. The range is limited to 366 days.
- The numbers are no longer limited to the 250 most recent orders.
- Pull to refresh reloads the summary.
- **Staged rollout (WYN-125):** developer accounts see the new page. Every other store keeps the previous finance page, unchanged.
  - Opening it to everyone needs the Founder's explicit go-ahead ("เปิดให้ทุกคน").
- The calendar sheet moves focus in when it opens, closes on Escape, keeps Tab inside, and returns focus to "เลือกวัน" when it closes.

## Verification

- `supabase/tests/wynos_merchant_finance_test.sh` passes. It covers:
  - roles: manager and legacy owner can read; delivery staff, legacy delivery staff, a developer account outside the store, another store's owner and signed-out users cannot. The test uses the production helper, including its broad branches;
  - Bangkok day boundaries;
  - every line, refunds, ads and WYNOS share; that the lines add up; the previous period;
  - daily rows, slips waiting, WYNOS owed before and after settlement;
  - empty ranges, invalid and too-long ranges, privileges.
- Mutation checks confirmed the test fails when the income formula, the role list or the timezone is wrong, or when the check goes back to `merchant_has_store_role()`.
- The workflow verification query was tested on a local database.
- `tsc`, `eslint` and `test:i18n` pass. `wynos-merchant` and `food-developer-preview` specs: 108 passed.

## Release

1. Merge the PR. Web auto-deploys.
   - Until step 2 runs, developer accounts see "ระบบการเงินยังไม่เปิดใช้งาน"; everyone else is unaffected.
2. Dispatch `food-apply-wyn210.yml` with `APPLY-WYN-210`.

## Rollback

- Revert the PR.
- Optionally `drop function public.merchant_finance_summary(uuid, date, date)`.
- No data changes to undo.

## Opened to everyone (2026-10-04)

- The Founder said "เปิดทุกคน". The WYN-125 gate is removed, so every store now gets the new finance page.
- The previous order-based `FinancePanel` is deleted.
