# Security Task — WYN-213 — Merchant access hardening

Status: approved — Founder "อนุมัติ" 2026-10-04; releasing PR #874, applying the migration, deploying Admin
Owner: AI QA & Security / AI Coding
Date: 2026-10-04

## Why

The WYNOS Admin Merchant audit (2026-10-04) found these problems:

1. **HIGH.** `merchant_has_store_role()` accepted a legacy `food_staff` row of any role, including delivery, as owner/admin. Such a user could promote themselves, edit the store's bank/PromptPay details, and mark payments paid or refunded.
2. **HIGH.** `merchant_has_store_role()` and `food_has_merchant_access()` let every developer account into every store, including customer personal data, slips and money actions.
3. A WYNOS campaign payout recorded whatever was owed at click time, even if it was more than the admin saw and transferred, so the store was short-paid.
4. One ad top-up slip could be submitted several times and approved twice.
5. The amount WYNOS owed counted orders that were delivered but not verified as paid, and self-orders placed by the store's own team.

## Fix

`supabase/migrations_wynos_merchant_access_hardening_v1.sql`:

- **Helpers:**
  - No developer bypass in `merchant_has_store_role`, `food_has_merchant_access` or `food_store_media_writable`.
  - Legacy `food_staff` roles map to owner → owner, staff → orders, delivery → delivery.
- **Owed amount:** `internal.food_platform_owed_rows` counts only `payment_status = 'paid'` orders that are not refunded and were not placed by a store member or legacy staff.
- **Payout:** `admin_settle_platform_store(store, reference, expected_amount, expected_count, note)` refuses with "owed amount changed" when the amount differs. The old 3-argument version is dropped.
- **Ad slips:** a unique index on `food_ad_topups.slip_path`.
- **Admin UI:** the payout button sends the amount and order count it showed, and the dialog shows the order count.

Customer-side developer access (Food rollout gate, store and menu browsing) is unchanged.

**Effect:** developer accounts need a real store membership to use the Merchant app for a store. Founder accepted this.

## Verification

- `supabase/tests/wynos_merchant_access_hardening_test.sh` passes. It covers:
  - developers denied; members and legacy staff by role; media writes;
  - owed rows: only the paid customer order counts; slip waiting, refunded, owner's self-order and legacy staff's self-order are excluded;
  - payouts: moderator denied, stale or missing amount refused, a matching amount recorded once, no second payout, old signature gone;
  - duplicate slip refused.
- Mutation checks: restoring role-blind legacy staff, or dropping the paid check, both fail the test.
- The workflow verification query was tested locally. Admin `tsc` and `lint` pass. Web spec WYN-213 passes.

## Release

1. Merge the PR.
2. Dispatch `food-apply-wyn213.yml` with `APPLY-WYN-213`.
   - The output prints counts of active legacy staff and developer accounts.
   - If existing duplicate slip paths ever existed, the unique index fails and the whole migration rolls back, with nothing applied.
3. Run `deploy-admin.yml`.
   - Between steps 2 and 3, "บันทึกว่าโอนแล้ว" fails safely, because the old function is gone.

## Rollback

Re-run the previous definitions listed in the workflow header, and drop the unique index.
