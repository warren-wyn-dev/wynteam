# Product Task — WYN-207 — WYNOS Food pay-per-click ads (Admin-controlled)

Status: approved — releasing PR #836 and applying the migration
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "ตรงนี้ให้มีแค่ การเงิน โฆษณา แคมเปญ โปรโมชั่น", then "ทำครบทั้ง 4 ระบบเลย".
- Ads: "จ่ายต่อคลิก แต่ต้องให้ระบบ WYNOS Admin ควบคุมได้". Payment: PromptPay transfer plus slip. Placement: recommended stores on the Food home page, plus the top of search.
- "อนุมัติ" to start WYN-207.

## Scope

- **WYNOS Admin `/food/ads`** (admin only):
  - Settings: price per click, minimum top-up, WYNOS PromptPay name and number, and the master switch. **Ads start OFF.**
  - Pending top-up slips with images. Approving adds credit. Rejecting needs a reason.
  - Store ad accounts: credit, spend, 7-day clicks. Admin can stop a store's ads with a reason, or allow them again.
- **Wynos Merchant โฆษณา:**
  - Credit, clicks today and over 7 days, and status. Pause or resume.
  - Where ads show and how charging works.
  - Top-up: WYNOS PromptPay, amount, slip upload to `food-private/ads/<store_id>/`, top-up history.
- **WYNOS Food:**
  - A store directory with search. Live ads come first as "ร้านแนะนำ", or as matches at the top when searching. They always carry the "โฆษณา" label.
  - Picking a store opens it, and the cart is cleared after confirming.
  - Opening an ad reports the click to the server.
- **Charging:**
  - Server-side only.
  - Once per customer per store per Bangkok day.
  - Never for the store's own team.
  - Only while live (ads on, account active, credit at least one click, store published and not suspended).
  - The balance never goes below zero.

## Security decisions (need Founder approval)

- New tables have RLS on with no direct grants, so stores cannot edit balances. All access goes through role-checked SECURITY DEFINER RPCs.
- Ad slip storage: only the store's owner, admin or manager can upload to its own folder, and the store team can read it. Platform admins already read `food-private`. Nobody can edit or delete slips.
- Admin only: settings, top-up review and stopping ads. Every action is audited, and the store owners and managers are notified.

## Acceptance criteria

1. Ads are off until Admin sets PromptPay and switches them on. Moderators cannot change anything.
2. A top-up is credited once, only after Admin approves.
3. Clicks are charged once per customer per day, never for the store's own team, and never when the ad is not live.
4. The Food directory lists live ads first, with the label.
5. `supabase/tests/wynos_food_ads_test.sh` passes (7 of 7 mutants caught). Web and Admin checks pass.

## Release (needs Founder approval)

1. Merge. Web and Admin are safe before the migration: pages show "not available" and Food hides the directory.
2. Dispatch `food-apply-wyn207.yml` with `APPLY-WYN-207`, then run the manual Admin deploy.
3. In Admin `/food/ads`: set WYNOS PromptPay, price per click and minimum top-up, then switch ads on.

Note: WYNOS Food is still a developer preview, so real customers see ads once Food opens to the public.

Rollback: see the workflow header (switch ads off first).
