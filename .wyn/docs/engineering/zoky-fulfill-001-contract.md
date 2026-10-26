# ZOKY-FULFILL-001: Cross-session contract (Food/DB ↔ Merchant)

Integration branch: `feat/zoky-fulfill-001`. It is cut from the live production line, `release/zoky-web-thai-mobile-20261026` @ 71f7fb0f.
Every session opens PRs **into this branch**, never into `main` or the release branch.
PRD: `.wyn/docs/product/zoky-fulfill-001-pickup-and-store-delivery.md`. Design: `zoky-fulfill-001-technical-design.md`. Approvals: `.wyn/company/APPROVALS.md` (2026-10-26 entries).

Status: **v2** (2026-10-26, after the production definitions dump; see §0). Earlier: v1 draft. Names and shapes may still change after the production definitions dump. Any change is made **in this file first**, in its own commit, and the other session is told about it.

## 0. v2 changes (Merchant session: please update)

1. **No new order statuses.** 15 live functions (sales report, finance, GP owed, reviews, admin) treat `delivered` as the completed state. Pickup orders therefore reuse the existing statuses:

   | Pickup step | Stored `status` | UI label |
   |---|---|---|
   | ready for the customer to collect | `ready_for_delivery` | "พร้อมให้รับ" |
   | customer collected the order | `delivered` (+ `picked_up_at`) | "ลูกค้ารับแล้ว" |

   Show pickup labels when `fulfillment_type === 'pickup'`. `ready_for_pickup` and `picked_up` **do not exist** in the DB, so drop them from the status sets.
2. Store transitions for pickup orders:
   - `food_transition_order(order, 'ready_for_delivery')` from `preparing`.
   - **New** `food_complete_pickup(p_order_id uuid, p_note text default null)` from `ready_for_delivery`. Sets `delivered` and `picked_up_at`. Roles: owner, admin, manager, orders. No photo.
   - `food_transition_order(order, 'out_for_delivery')` is refused for pickup orders, and `food_complete_pickup` is refused for delivery orders.
3. `payment_method` values are `'transfer'` and `'cod'`, as in v1.
5. **Refund slip path changes** to `refunds/<order_id>/<file>` in the `food-private` bucket, the same layout as `delivery/<order_id>/`. The v1 path `food-refund-slips/<store_id>/<order_id>/...` is not used. New storage policies allow upload by owner/admin/manager of the order's store while a refund is pending, and allow reads by the store and by the order's customer. `food_store_mark_refunded` checks the path and that the object exists.
6. New read RPC for the customer app: `food_pickup_slots(p_store_id)` returns `timestamptz[]`. Merchant does not need it.
4. Store prep time: `food_store_set_fulfillment(... p_prep_minutes)` is unchanged and writes the new column `food_stores.pickup_prep_minutes`. (The existing `prep_time_min_minutes` / `prep_time_max_minutes` columns are the ETA range and stay as they are.)
7. **v2.1 rules (DB QA, 2026-10-26).** Both apps must follow these server rules:
   - `pickup_enabled`, `delivery_enabled`, `cod_enabled` and `pickup_prep_minutes` change **only** through `food_store_set_fulfillment`. A direct table update that changes them raises `use food_store_set_fulfillment`. Sending the same values back unchanged is fine.
   - When a store turns delivery off, every client gets `delivery_not_available` when creating an app delivery order, including old v1/v2 clients. The store's own manual and social orders are not affected.
   - `food_request_cancel` needs `payment_status='paid'`. A slip still under review cannot be the subject of a cancel request. **One request per order:** after the store rejects it, another request raises `cancel request not available`.
   - `food_complete_pickup` clears an open cancel request; collecting the order counts as the store's answer.
   - `food_pickup_slots` is empty while the store is closed now or unpublished.
   - Pickup codes are unique per store per Bangkok day (unique index `food_orders_pickup_code_day_key`).
8. Zoky Admin reads orders through the new `admin_food_orders_v2`. It has the v1 columns plus the fulfilment, payment-method, pickup and cancel-request fields, and the filters `pickup`, `cod` and `cancel_request`. It ships in migration `20261026130000_zoky_fulfill_001_admin.sql`; v1 is unchanged.

## 1. Ownership (do not edit the other side's files)

| Session | Owns |
|---|---|
| **Food/DB** (lead) | `supabase/**` (migration, rollback, SQL tests), `web/lib/food-customer.ts`, `web/components/food/**`, `web/app/food/**`, Zoky Admin (`admin/**`), this contract |
| **Merchant** | `web/merchant_flutter/**`, `web/lib/merchant-flutter-bridge.ts`, `web/components/merchant/**`, **new** file `web/lib/food-fulfillment-merchant.ts` (merchant-side RPC wrappers), `web/tests/merchant-*` |
| Shared, coordinate first | `web/lib/food-merchant.ts` (types only: add the new fields, no other change), `web/lib/i18n/en.ts` (add keys at the end of the Zoky section in your own PR; the duplicate-key test must stay green) |

## 2. Payment policy (Founder, 2026-10-26)

- **Transfer to the store + slip only.** The customer pays by PromptPay or bank transfer to the store, then attaches a slip.
- The **store verifies the slip manually** against its own bank app and taps "ยืนยันรับเงิน" or "เงินไม่เข้า / สลิปมีปัญหา". The Merchant Flutter app already has manual slip review (`payment` bridge method); reuse it.
- **Stripe is paused, not deleted.** It is no longer offered for new orders and no store needs it. Do not remove Stripe code or UI that serves existing orders, such as refund status display. Only hide Stripe *setup* prompts.
- **COD**: each store can turn it on, for delivery orders only. The store confirms the cash when it completes the delivery.
- **Refunds**: the store transfers the money back itself and attaches a refund slip. There is no automatic refund for transfer orders.
- **No GP** on COD. The monthly-fee billing work (ZOKY-BILLING-001) is out of scope.

## 3. Data (v1 draft)

```text
food_stores  + pickup_enabled bool (default false)
             + delivery_enabled bool (default true)
             + cod_enabled bool (default false)
             + pickup_prep_minutes int 5..120 (default 15)
food_orders  + fulfillment_type 'delivery'|'pickup' (default 'delivery')
             + payment_method  'transfer'|'cod'   (default 'transfer'; legacy Stripe rows keep payment_provider='stripe')
             + pickup_at timestamptz, pickup_code text, picked_up_at timestamptz
             + cancel_requested_at timestamptz, cancel_request_note text
             + refund_slip_path text, refunded_by_store_at timestamptz
status         unchanged (pickup reuses ready_for_delivery / delivered, §0)
refund_status  values unchanged ('none','pending','refunded','failed')
               transfer orders: 'pending' means the store owes a refund;
               'refunded' is set by the store with a refund slip
```

## 4. RPCs the Merchant side calls (v1 draft signatures)

| RPC | Purpose | Roles |
|---|---|---|
| `food_store_set_fulfillment(p_store_id uuid, p_pickup boolean, p_delivery boolean, p_cod boolean, p_prep_minutes int)` | Store settings. Raises `pickup_requires_schedule` if the store has no weekly schedule, and `at_least_one_mode` if both modes are off. | owner, admin |
| `food_transition_order(p_order_id, p_status, p_eta_minutes, p_note)` (existing, extended) | Pickup path: `preparing → ready_for_delivery`, then `food_complete_pickup`. Accepting a COD order while unpaid is allowed. | existing roles |
| `food_complete_pickup(p_order_id uuid, p_note text)` (new) | Customer collected a pickup order: sets `delivered` and `picked_up_at`. | owner, admin, manager, orders |
| `food_complete_delivery(...)` (existing, extended) | For COD it also records the cash as received. Signature unchanged. | existing |
| `food_set_payment_status(...)` (existing) | Store confirms or flags a slip. Unchanged. | existing |
| `food_resolve_cancel_request(p_order_id uuid, p_approve boolean, p_refund boolean, p_note text)` | Answer a customer cancel request. | owner, admin, manager, orders |
| `food_store_mark_refunded(p_order_id uuid, p_refund_slip_path text, p_note text)` | Store refunded the customer by transfer. The slip goes in the private bucket path `food-refund-slips/<store_id>/<order_id>/...`. | owner, admin, manager |

Order rows returned to the Merchant side gain the §3 fields. `pickup_code` is shown to the store.

## 5. Merchant UI scope (Merchant session)

1. **Store settings**:
   - Toggles for "ร้านจัดส่งเอง", "รับเองที่ร้าน" and "เก็บเงินปลายทาง", plus prep minutes.
   - Show the server error text: pickup needs a weekly schedule, and at least one mode must stay on.
   - Hide or soften Stripe setup prompts, because Stripe is paused.
2. **Order list and detail**:
   - Mode tag (`ส่งเอง` / `รับเอง`) and a COD tag.
   - For pickup: time and code, with "พร้อมให้รับ" then "ลูกค้ารับแล้ว".
   - Delivery flow unchanged.
3. **Slip review**: keep the existing manual review. Add the hint "เช็กยอดเงินเข้าในแอปธนาคารก่อนกดยืนยัน".
4. **COD**: inside complete delivery, a "ได้รับเงินสดแล้ว" confirmation.
5. **Cancel request banner**: approve or reject, then refund or no refund (Founder: the store decides).
6. **Refund owed** (`refund_status='pending'` on transfer orders): "โอนคืนแล้ว + แนบสลิป" via `food_store_mark_refunded`.
7. Realtime and push: the new statuses and cancel requests must refresh the list.
8. Legacy `/merchant` (Next.js) pages under `web/components/merchant/**`: show the same tags and actions at minimum, so a store on either UI can operate.

## 6. Rules for both sessions

- Follow `AGENTS.md`:
  - Thai with the Founder, English in code.
  - No secrets, no production DB, synthetic fixtures only.
  - No deploy, no production migration.
  - Small conventional commits.
- Build against **mocks / fixtures** until the DB PR lands in the integration branch.
- Before every PR, run the repo checks:
  - `cd web && node --test tests/*.test.mjs`, lint, `npm run build` where feasible;
  - `flutter analyze` and `flutter test` for the Flutter app.
  - Revert `web/next-env.d.ts` and `web/AGENTS.md` if `next dev` dirtied them.
- Every user-visible Thai string needs an English entry in `en.ts`. No duplicate keys.
- Status words must not collide in i18n. Use distinct Thai labels, for example "พร้อมให้รับ" vs the existing "พร้อมส่ง".

### Merchant direct cancellation supplement

`food_store_cancel_order(p_order_id uuid, p_refund boolean, p_note text default null)` lets an authorized order manager cancel an open order with an explicit refund/no-refund choice and a 3–1000 character reason. Refund requires a paid order. Both decisions are audited; terminal orders are refused. Apply `20261026172233_zoky_merchant_cancel_choice.sql` after the two v2 migrations. Roll back this supplement first; the decision history is retained. The accepted temporary legacy refund risk remains unchanged.
