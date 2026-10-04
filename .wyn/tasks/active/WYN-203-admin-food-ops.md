# Product Task — WYN-203 — WYNOS Admin: Food store and order operations

Status: awaiting Founder approval (PR review, merge, production migration)
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- Founder: "ระบบหลังบ้าน WYNOS Admin เพิ่ม Merchant ยัง". AI listed what Admin already had (Merchant applications) and what was missing.
- Founder: **"เพิ่มระบบที่ยังไม่มี"**. That covers the five missing parts below.

## Scope

New Admin section `/food` ("Food Stores & Orders"):

1. **Overview.** Store counts (all, published, open, suspended), orders and sales today, active orders, and orders and sales for the last 7 days.
2. **All-stores list.** Status, owner, team size, orders and sales over 30 days, active orders, last order. Search by name, slug or phone. Suspended stores are listed first.
3. **Store suspension.** A reason is required. The store is hidden from customers, forced closed, and blocked from new orders in the database. Existing orders can still be handled. Owners and admins of the store are notified. Lifting a suspension keeps the store closed until the owner opens and publishes it again.
4. **Cross-store orders for complaints.** Filters for all, active, delivered and cancelled, plus search by order number, name or phone. The order detail shows the customer, items, timeline, payment slip and delivery photo (signed links valid for 10 minutes).
5. **Store team.** Members, roles and active state. An admin can switch a member off or back on. The last active owner cannot be switched off. The legacy `food_staff` row is kept in sync.

Merchant: a suspended store sees a "ร้านถูกระงับโดยทีม WYNOS" banner with the reason. The open and publish switches are disabled, and the errors are shown in Thai.

## Security decisions (need Founder approval)

- Store data (list, overview, team) can be read by **admin and moderator**.
- Customer data (orders, phone numbers, addresses, slips, delivery photos) and every change (suspension, team) are **admin only**.
- New storage policy "Food private readable by WYNOS admin": platform admins can read the `food-private` bucket (slips, delivery photos) for complaints. It is read only, and Admin opens files through short-lived signed URLs.
- Opening an order writes `admin_food_order_viewed` to the audit log. Suspension and team changes are audited too.
- All RPCs are SECURITY DEFINER and re-check `internal.current_platform_role()`. Execute is revoked from public and anon.
- Suspension is enforced by triggers: only an admin can change the suspension fields, and a suspended store cannot reopen, publish or receive orders, even through a direct API call.

## Acceptance criteria

1. A moderator sees the overview, store list and team, but cannot open orders or change anything.
2. A regular user is refused by every RPC.
3. After suspension, the store is unpublished and closed, staff cannot reopen it, and new orders are rejected. After lifting, orders work again.
4. The only owner cannot be switched off.
5. `supabase/tests/wynos_admin_food_ops_test.sh`, the Merchant spec, Admin lint and typecheck, web typecheck and i18n all pass.

## Release (needs Founder approval)

1. Merge. Admin and web auto-deploy. Admin `/food` shows an error until the migration is applied, and Merchant is unaffected.
2. Dispatch `food-apply-wyn203.yml` with `APPLY-WYN-203`.

Rollback: revert the merge commit. The SQL rollback is in the workflow header.
