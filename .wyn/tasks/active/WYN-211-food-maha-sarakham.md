# Product Task — WYN-211 — Open WYNOS Food to everyone, ordering only in Maha Sarakham

Status: in review — awaiting Founder "อนุมัติ" for merge and production migration
Owner: AI Product Manager / AI Coding
Date: 2026-10-04

## Founder direction

- "Wynos Food เปิดให้ทุกคนเห็น แต่สามารถใช้ได้แค่คนที่อยู่ จ มหาสารคาม".
- Founder's answers (2026-10-04):
  - "In Maha Sarakham" means the delivery pin is inside the province boundary, checked on the server.
  - A store must be inside Maha Sarakham to open.
  - People outside the province see only an introduction page.
- This is the Founder's explicit go-ahead to open WYNOS Food publicly (WYN-125 staged rollout ends for Food customers).

## Scope

- **Home:** the WYNOS Food shortcut and drawer entry show for every signed-in user (`showFood = Boolean(userId)`).
- **Food access:** the client follows the server rule `food_customer_access_enabled()` (permanent account and public rollout, or developer) instead of developer-only. The migration sets `public_enabled = true`.
- **Introduction gate (web):**
  - When Food opens, the area is checked with the saved delivery pin, otherwise GPS.
  - Customers outside Maha Sarakham, or with no location, see "WYNOS Food เปิดให้บริการเฉพาะจังหวัดมหาสารคาม" with: use current location, pick on the map, back to home.
  - Developer accounts skip the gate.
- **Server (source of truth):** `internal.food_delivery_fee`, used by `food_quote_order` and `food_create_order`, now refuses:
  - a store whose pin is missing or outside the area: "store is outside the service area";
  - a delivery pin outside the area: "outside service area".
  - Developer accounts are exempt so they can test anywhere.
- **Stores:** readiness gains `service_area` ("ปักหมุดร้านในจังหวัดมหาสารคาม"), so publishing needs a store pin inside the province.
  - Already-published stores without such a pin stop taking orders until they pin it. The apply workflow prints how many.

## Technical design

- `public.food_service_areas`: RLS on, no grants. One row, `maha_sarakham`, holding the province boundary.
  - Source: OpenStreetMap relation 1908786, © OpenStreetMap contributors, ODbL.
  - Simplified with Douglas-Peucker at 0.0005°: about 50 m, 1,584 points. 1 mismatch in 4,000 random points against the full boundary.
- `internal.food_point_in_polygon` (ray casting) and `internal.food_in_service_area` (bounding box, then polygon).
- `public.food_service_area_check(lat, lng)`: signed-in users only, returns a boolean only.
- No PostGIS needed.

## Verification

- `supabase/tests/wynos_food_service_area_test.sh` passes. It covers:
  - Mueang Maha Sarakham, Kosum Phisai and Borabue are inside; Khon Kaen, Roi Et, a point inside the bounding box but in Kalasin, and Bangkok are outside. These points were also checked against the full boundary.
  - Quote/order refused for a pin outside the area, a store outside the area, and a store with no pin; developer exempt.
  - Readiness `service_area`; RPC privileges; `public_enabled` switched on; re-running the migration is safe.
- The workflow verification query was tested locally.
- `tsc`, `eslint`, `test:i18n` pass. Merchant and Food specs pass, except 2 assertions already failing on `main` from other commits (food SEO `index: false`, OpenFreeMap tiles URL).

## Release

1. Merge the PR. Web auto-deploys: the Food shortcut appears for everyone and the introduction gate is live.
2. Dispatch `food-apply-wyn211.yml` with `APPLY-WYN-211`.
   - Until step 2, non-developers who open Food are sent back to home, because `public_enabled` is still false.

## Rollback

- Hide Food again: `update public.food_rollout_settings set public_enabled = false`, and revert the PR.
- Remove the area limit only: re-apply the `internal.food_delivery_fee` definition from `migrations_wynos_food_delivery_zone_v1.sql` and `internal.food_store_readiness_missing` from `migrations_wynos_merchant_core_completion_v1.sql`.
