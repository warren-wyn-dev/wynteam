# Product Task — WYN-197 — WYNOS Food: free place search from the store's own place list

Status: approved — releasing PR #825
Owner: AI Product Manager / AI Coding
Date: 2026-10-03

## Founder direction

- Founder asked whether place search could be free without a paid map service ("ค้นหาโดยการทำแผนที่เองฟรีได้ไหม").
- AI recommended option 1: each store keeps its own list of places near the store. Founder: **"อนุมัติ"** (2026-10-03).

## Scope

- New table `food_store_places` (name, optional detail, pin, active flag), one list per store.
- Merchant → ตั้งค่าร้าน: "สถานที่ที่ร้านส่งบ่อย" section. Add, edit, hide or delete a place. The pin comes from "ใช้ตำแหน่งปัจจุบัน" or from coordinates pasted from Google Maps. Shows the distance from the store and warns when a place is outside the delivery radius.
- Food → address form: the place search looks in the store's list first. If nothing is found, it tries the `location-search` Edge Function (LocationIQ), which only works when a key is set. "ใช้ตำแหน่งปัจจุบัน" is unchanged.
- An empty search lists all of the store's active places.

## Security

- RLS: the store's merchants read their own list. Only owner/admin/manager can write. Other stores see nothing.
- Customers read only through `food_search_store_places(store, query)`. It uses the same store-visibility rule as `food_quote_order` and returns only active places of that store. anon has no access.
- Places are landmarks the store publishes, not customer data. LIKE wildcards in the search text are matched literally.
- The radius and fee are still enforced by `food_quote_order` / `food_create_order`. A place outside the radius cannot be ordered to.

## Acceptance criteria

1. A manager adds a place, and a customer finds it by name or detail.
2. Delivery staff and other stores cannot add, change or delete a store's places.
3. Hidden places are not offered to customers. An unpublished store cannot be searched except by developers.
4. Before the migration is applied, Merchant hides the section and Food search falls back to `location-search`.
5. `supabase/tests/wynos_food_store_places_test.sh`, Food/Merchant specs, typecheck, lint and i18n pass.

## Also in this PR

- `wynos-food-developer-preview.spec.ts:7` now expects the red Food `theme_color` (`#e32636`) that main set in 5725e53. The test was failing on main.

## Release (needs Founder approval)

1. Merge. The web auto-deploys and is safe before the migration.
2. Dispatch `food-apply-wyn197.yml` with `APPLY-WYN-197`.
3. In Merchant → ตั้งค่าร้าน, add the places the store delivers to.

Rollback: revert the merge commit; SQL rollback is in the workflow header.
