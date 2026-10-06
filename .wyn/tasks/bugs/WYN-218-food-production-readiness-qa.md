# Bug Report — WYN-218 — WYNOS Food production-readiness QA (food.wynos.online)

Status: bugs
Owner: AI Debug Engineer
Reported by: AI QA & Security, 2026-10-06
Founder: "QA ทั้งระบบ หาบั๊คให้หน่อย พร้อมเปิดใช้งานจริงได้ยัง"
QA Final Status: FAIL

## Bug 1 — HIGH — Menu option surcharges are never charged; option data comes from the client

Bug:
- The customer app prices each line as `menu price + option choice price` (`foodCartLineUnitPrice`, `web/lib/food-customer.ts`). `food_quote_order` and `food_create_order` (latest definition: `supabase/migrations_wynos_food_delivery_zone_v1.sql`) only use `food_menu_items.price × quantity` and ignore options.
- `selected_options` from the request is saved as-is into `food_order_items`. The server never checks `group_id`/`choice_id` against `food_menu_items.options`, so a customer can save any `group_name`/`choice_name`/`price` text, skip required groups, or go over `max_select`. The comment in `web/lib/food-customer.ts` ("Server accepts group_id + choice_id and re-resolves names/prices itself") is wrong.
- The Merchant app (`web/components/merchant/wynos-merchant-app.tsx`, order detail and print) never shows `selected_options`, so the store does not see what the customer picked (size, spice level, add-ons).
Reproduction (local PostgreSQL 16, real RPC body from the migration):
1. Menu "ข้าวกะเพรา" costs 50 with options ไข่ดาว +10 and พิเศษ +20.
2. `food_quote_order` with both options returns `subtotal 50, total 70`. The customer cart shows 80 per line.
3. `food_create_order` with a fake option `{"group_id":"FAKE","choice_name":"กุ้งมังกร x10 (ร้านแถม)","price":0}` succeeds, saving `unit_price 50` and the fake option.
Expected: the server resolves each option from the menu, checks required/max/duplicates, adds the choice price to the unit price and total, and saves only server-resolved names and prices. The Merchant sees options on the order and the printed slip.
Actual: add-ons are free, the cart line amount and the order total don't match, option text can be forged, and the store never sees options.
Root Cause: option pricing and validation exist only in the client, never in the order RPCs.
Fix: resolve and validate options in `food_quote_order`/`food_create_order`, store `unit_price` with the surcharge, and render `selected_options` in the Merchant order detail and print. Add a DB test.

## Bug 2 — MEDIUM — The customer can reset payment after the store confirms it

Bug: `food_submit_payment` (`migrations_wynos_merchant_payment_core_v1.sql`) only blocks `delivered`/`cancelled` orders. After the store sets `payment_status = 'paid'` (or `refunded`), the buyer can call the RPC directly to set `payment_status` back to `submitted` and clear `payment_verified_at` and the verification fields. The UI hides the button (`canPay`), but the server does not enforce it.
Expected: accept a slip only while `payment_status in ('pending','issue')`.

## Bug 3 — MEDIUM — No rate limit on placing orders

Bug: `food_create_order` has no per-user limit. One account can flood a store with `pending_acceptance` orders, and each one raises the Merchant alert and sound. There is also no limit on the number of open unpaid orders.
Expected: a server-side limit, e.g. N orders per minute per buyer and a cap on open unpaid orders per buyer per store.

## Bug 4 — LOW — Public store media can be listed anonymously, including PromptPay QR images

Bug: `storage/v1/object/list/food-public` works with only the publishable key. It lists every store id and file, including `stores/<id>/payment/*` (the PromptPay QR, which holds a phone or ID number). Each file can be downloaded without signing in.
Expected: no anonymous listing, and the payment QR served only to signed-in buyers of that store. Alternatively, the Founder explicitly accepts this risk.

## Bug 5 — LOW — Unlimited anonymous share-open counter

Bug: `food_record_share_open` is granted to `anon` and has no limit. Anyone can inflate `food_share_link_opens` (store share statistics) by calling it repeatedly.

## Bug 6 — LOW — The Social app is served on the Food origin

Bug: `proxy.ts` only rewrites `/` on `food.wynos.online`. Every Social route (`/login`, `/chat`, `/club`, …) also renders on the Food origin with WYNOS branding. For example, `https://food.wynos.online/login` shows the Social login. This creates duplicate indexable content and a confusing entry point.

## Verified OK (no action)

- 23/23 Food/Merchant/Maps DB tests pass (`supabase/tests/wynos_*`). `tsc` passes, food eslint has 0 errors, and the food/merchant/i18n unit tests pass 43/43.
- Production anonymous access: every food/merchant table returns 42501, and the order/quote/admin/merchant RPCs are denied to anon. `food-private` lists nothing. Only the `sb_publishable_` key is in the JS bundle, with no service key.
- Live pages (mobile and desktop): `/` redirects to `/food/login` and `/merchant` to `/merchant/login`, with no JS console errors and no horizontal overflow. Share link `/s/4qdyvv` returns correct OG tags. HSTS, X-Frame-Options DENY and nosniff are set.
- Not tested on production: signed-in flows (order, payment, delivery), because that needs a test account and real orders on a live store. They need a Founder-approved test account or staging.

Files Changed: none (QA only)
Regression Risk (fixes): Bug 1 touches the pricing RPCs, so re-run the campaign, delivery-zone and service-area tests.
Handoff to QA: yes, after the fixes
