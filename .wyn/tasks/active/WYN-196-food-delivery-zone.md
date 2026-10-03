# Product Task — WYN-196 — WYNOS Food delivery zone and distance fee

Status: approved — releasing PR #824
Owner: AI Product Manager / AI Coding
Date: 2026-10-03

## Founder direction (AskUserQuestion, 2026-10-03)

- Maximum delivery distance: **5 km** by default (each store can change it).
- Delivery fee: **by distance**. Base fee plus baht per km beyond the first km, with the numbers set by the store.
- Customer location: **use current location + place search**.

## Scope

- Store settings (Merchant): pin the store's location with GPS; set the radius (default 5 km), the km included in the base fee (default 2), and the baht per extra km.
- Address (Food): an optional pin, set with "ใช้ตำแหน่งปัจจุบัน" or a place search (the existing `location-search` Edge Function, which now has CORS).
- Checkout: re-quotes using the chosen address's pin and shows the distance and fee. Ordering is blocked when the address has no pin or is outside the area.
- Server: `food_quote_order` / `food_create_order` compute the distance (haversine), fee and radius. The old RPC signatures are dropped so the check cannot be bypassed. The order stores the pin and distance; the Merchant map link opens at the exact pin.
- A store with no pin keeps today's flat fee and no radius, so nothing changes until the owner pins the store.
- Rollout-safe in either order: the client sends coordinates only when the store has a zone, and Merchant sends zone fields only when the columns exist.

## Fee formula

fee = base fee + ceil(max(distance − base km, 0) × baht per km). Example: base 20, base km 2, 8 baht/km, 4 km → 20 + 16 = 36 baht.

## Acceptance criteria

1. A pinned store rejects orders beyond its radius ("outside delivery area") and orders without a pin ("delivery location required").
2. The fee follows the formula and is computed only on the server.
3. An unpinned store behaves exactly as before.
4. Invalid or half pins are rejected for both stores and addresses.
5. Thai/English, typecheck, lint, Food/Merchant specs and `supabase/tests/wynos_food_delivery_zone_test.sh` pass.

## Known limits

- Distance is straight-line, not road distance.
- The customer supplies their own pin (only their own delivery is affected). The store sees the distance and the exact map pin, and can cancel.
- Place search depends on `LOCATIONIQ_API_KEY`. Without it, GPS still works and search shows a fallback message.

## Release

1. Merge (web auto-deploys).
2. Dispatch `food-apply-wyn196.yml` with `APPLY-WYN-196`.
3. Deploy `location-search` (CORS).
4. In Merchant → ตั้งค่าร้าน: pin the store and set the per-km fee.

Steps 2 and 3 need Founder approval for production.
