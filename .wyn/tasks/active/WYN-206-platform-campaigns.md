# Product Task — WYN-206 — WYNOS campaigns (Admin designs, stores join, hybrid funding)

Status: approved — releasing PR #835 and applying the migration
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "ตรงนี้ให้มีแค่ การเงิน โฆษณา แคมเปญ โปรโมชั่น", then "ทำครบทั้ง 4 ระบบเลย".
- Campaigns: "แคมเปญ ทางWYNOS Admin จะเป็นคนออกแบบเอง คิดแคมเปญเอง".
- Funding: "แคมเปญ เป็นระบบไฮบริด แล้วแต่จะตั้งยังไง ขึ้นอยู่กับ WYNOS Admin จะเป็นคนออกแคมเปญ".

## Scope

- **Admin `/food/campaigns`:**
  - Create and edit campaigns (name, description for stores, % / baht / free delivery, minimum, maximum, period, per-store usage limit).
  - **WYNOS share 0–100%**: the store pays the rest.
  - Open or close joining, and pause the whole campaign.
  - Moderators can read the list.
- **Merchant แคมเปญ:**
  - Lists open campaigns. Owner, admin or manager can join or leave.
  - Before joining, the store sees who pays what and how the money flows.
  - Shows "WYNOS จะโอนคืนร้าน" and the transfer history.
- **Pricing:**
  - A joined store gets its own `food_campaigns` row, so the existing server-side best-saving logic applies (one discount per order, never stacked).
  - Each order records WYNOS's share (`platform_funded`).
- **Money owed:** customers pay the store directly, so WYNOS's share of delivered, non-refunded orders is owed to the store. Admin transfers it outside the system and records it with a reference. This settles the orders once, notifies the owners and writes the audit log.
- **Food:** a "แคมเปญ WYNOS · name" badge on stores in a running campaign.

## Security decisions (need Founder approval)

- New tables have RLS on with no direct grants. All access goes through role-checked SECURITY DEFINER RPCs.
- A store cannot change a WYNOS campaign's terms with its own promotion tools (guard trigger). Usage counting still works.
- Admin-only:
  - Designing campaigns.
  - Viewing owed amounts, which shows the store's payout details (PromptPay or bank account) so Admin can transfer.
  - Recording transfers. Settling locks the orders, so the same order cannot be paid twice.

## Acceptance criteria

1. Only admins design campaigns. Moderators read. Delivery staff cannot join.
2. Joining twice is harmless. Leaving removes the discount and the Food badge.
3. Orders record WYNOS's share, and editing the share later does not change past orders.
4. Only delivered, non-refunded, non-cancelled orders are owed. Settling requires a reference and works once.
5. `supabase/tests/wynos_platform_campaigns_test.sh` passes (5 of 5 mutants caught). Web and Admin checks pass.

## Release (needs Founder approval)

1. Merge. Web and Admin are safe before the migration: the pages show "not available yet".
2. Dispatch `food-apply-wyn206.yml` with `APPLY-WYN-206`.
3. Run the manual Admin deploy (`deploy-admin.yml`).

Rollback: see the workflow header.
