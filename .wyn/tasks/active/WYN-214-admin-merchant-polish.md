# Product Task — WYN-214 — WYNOS Admin Merchant polish

Status: approved — Founder "อนุมัติ" 2026-10-04; releasing PR #877, migration, Admin deploy
Owner: AI Coding / AI QA & Security
Date: 2026-10-04

## Why

The WYNOS Admin Merchant audit (2026-10-04) found Admin gaps. The Founder asked to continue after WYN-213 ("ทำต่อ").

## Scope

- **Store detail:**
  - A "พื้นที่ให้บริการ" card: inside Maha Sarakham or not, store pin with a map link, delivery radius.
  - What the store still needs before it can publish, in Thai (readiness, including WYN-211 `service_area`).
- **Orders list:**
  - New filters "รอตรวจการชำระ" (slip waiting or payment issue) and "รอคืนเงิน" (refund requested or failed).
  - A refund badge in Thai.
  - Shows up to 300 orders and says so when the list is full.
- **Order detail:**
  - Discount lines (campaign name, delivery discount), so the breakdown adds up to the total.
  - Refund status in Thai, with when it was requested and the note.
- **Merchant applications:**
  - A confirm step before approving (approval is final and creates the store).
  - Statuses and server errors in Thai.
  - A link to the store in Admin.
  - A notice when the list holds its maximum of 200.
- **Stores list:** a notice when it holds its maximum of 500.

**Database:** `supabase/migrations_wynos_admin_merchant_polish_v1.sql`. These are read-only changes to `admin_food_store_detail` and `admin_food_orders`. The admin/moderator rules are unchanged.

## Verification

- `supabase/tests/wynos_admin_merchant_polish_test.sh` passes: area flag, pin, readiness, both new filters, an unknown filter is rejected, and users and moderators are refused as before.
- The workflow verification query was tested locally.
- Admin `tsc` and `lint` pass. Web spec WYN-214 passes.

## Release

1. Merge the PR.
2. Dispatch `food-apply-wyn214.yml` with `APPLY-WYN-214`.
3. Run `deploy-admin.yml`.

## Rollback

Revert the PR, and re-run both functions from `migrations_wynos_admin_food_ops_v1.sql`.
