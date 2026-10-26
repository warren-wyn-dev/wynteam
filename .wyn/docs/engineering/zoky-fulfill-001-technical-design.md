# ZOKY-FULFILL-001: Technical design (Architect + Database)

PRD: `.wyn/docs/product/zoky-fulfill-001-pickup-and-store-delivery.md` (approved 2026-10-26)
Status: design draft for CTO review. No migration has been applied and nothing is deployed.

## 1. What exists today (repo, 2026-10-26)

| Area | Current behaviour | Source |
|---|---|---|
| Order statuses | `pending_acceptance → preparing → ready_for_delivery → out_for_delivery → delivered`, plus `cancelled`. A check constraint enumerates them, and about 10 SQL files reference `out_for_delivery`. | `migrations_wynos_food_merchant_v1.sql` and others |
| Merchant transitions | `food_transition_order(order, status, eta, note)`, gated by role. Accepting an order requires `payment_status='paid'`. Cancelling a paid order always sets `refund_status='pending'`, and the Stripe refund jobs then refund it automatically. | `migrations_wynos_merchant_core_completion_v1.sql:537` |
| Delivery completion | `food_complete_delivery(...)` requires a photo. | `migrations_wynos_food_delivery_photo_required_v1.sql` |
| Create / quote | `food_create_order_v2` / `food_quote_order_v2` (coupon layer). These call the core `food_create_order` / `food_quote_order`, which check the service area and compute the delivery fee. The coupon layer passes context through `set_config('wyn.food_coupon_code', …, true)`. | `migrations/20261008161000_food_admin_coupons.sql` + 9 root files |
| Payment | PromptPay via Stripe only (D11, 2026-10-23). The BEFORE INSERT trigger `food_orders_require_stripe_ready` rejects non-manual orders unless the store's Stripe account is ready and PromptPay is active. Money goes to the store's Stripe account. | `migrations/20261023100000_food_stripe_jobs_auto_refund.sql` |
| Unpaid timeout | `food_timeout_cancel` cancels `source='app'` orders that are `pending_acceptance` and unpaid with `payment_due_at` set. | `migrations/20261008113000_food_unpaid_payment_timeout.sql` |
| Customer cancel | `food_cancel_order`. | `migrations_wynos_food_customer_access_gate_v2.sql` |
| Opening hours | Structured weekly schedule, special closed dates and temporary closure, evaluated by `internal.food_store_effectively_open(store, at)` in Asia/Bangkok. Stores without a schedule fall back to the manual `is_open` flag. | `migrations_wynos_merchant_production_readiness_v1.sql:101` |
| Scheduled orders | `scheduled_for` + `internal.food_set_scheduled_order`. Hidden in the UI since 2026-10-10. | coupons migration |

## 2. Findings that shape the design

1. **COD conflicts with the Stripe-only gate and the "paid before accept" rule.** COD orders need two exceptions, both in DB code:
   - the insert trigger must accept `payment_method='cod'` from stores with COD enabled;
   - `food_transition_order` must allow accepting an unpaid COD order.
   - Open question for the Founder: should a COD-only store with no Stripe account be allowed? The design default is **no**: COD is an extra option on a store that already passes the Stripe gate.
2. **"The store decides the refund" conflicts with the automatic refund on cancel.** The design adds a cancellation path that cancels with `refund_status='none'` when the store chooses not to refund. The existing path, which always refunds, stays the default.
3. **Pickup time needs a closing time.** A closing time is only known for stores with a structured weekly schedule. Pickup can therefore be enabled only on stores with a schedule; the server rejects it otherwise.
4. **Unpaid timeout and COD.** COD orders are created with `payment_due_at = NULL`, so `food_timeout_cancel` already skips them. A test will cover this.
5. **The repo may not equal production.** The core `food_create_order` / `food_quote_order` are defined in many root migration files, and production is the truth. Before writing `create or replace` for any existing function, we need the production definitions (`pg_get_functiondef`).
   - Proposal: a read-only CI job, using the production environment and Founder approval, dumps the definitions of the functions listed in §4. It dumps definitions only, never table data.
   - We diff those definitions against the repo and write the migration against production.

## 3. Data model (additive migration)

```sql
-- food_stores
pickup_enabled   boolean not null default false
delivery_enabled boolean not null default true
cod_enabled      boolean not null default false
prep_minutes     integer not null default 15 check (prep_minutes between 5 and 120)
check (pickup_enabled or delivery_enabled)

-- food_orders
fulfillment_type text not null default 'delivery' check (fulfillment_type in ('delivery','pickup'))
payment_method   text not null default 'online'   check (payment_method in ('online','cod'))
pickup_at        timestamptz
pickup_code      text            -- e.g. 'A23', unique per store per Bangkok day
picked_up_at     timestamptz
cancel_requested_at timestamptz
cancel_request_note text
check (fulfillment_type = 'delivery' or (pickup_at is not null and pickup_code is not null and payment_method = 'online'))
check (payment_method = 'online' or fulfillment_type = 'delivery')
-- status check gains 'ready_for_pickup' and 'picked_up'
```

All existing rows get the defaults `delivery` / `online`, so behaviour does not change. The rollback drops the new columns and constraints and restores the old status check. Before rolling back, any pickup or COD orders must be closed.

## 4. Server functions

| Function | Change |
|---|---|
| `food_quote_order_v3(store, items, lat, lon, coupon, fulfillment_type)` | New. For pickup it skips the service-area check and returns `delivery_fee=0` and the allowed `pickup_slots[]`. The slots run from now + `prep_minutes`, rounded up to 15 minutes, to closing − `prep_minutes`, on today's Bangkok date only. |
| `food_create_order_v3(…, fulfillment_type, pickup_at, payment_method)` | New. Checks that the store has the mode enabled, re-validates `pickup_at` (today, on a slot boundary, and inside the slot range), checks that COD is enabled and only used with delivery, and generates `pickup_code`. It passes the context through `set_config('wyn.food_fulfillment', …, true)`, the same pattern as coupons, then calls the core create. v2 stays unchanged for old clients. |
| core `food_create_order` / `food_quote_order` | Redefined against the production definitions (finding 5). When `wyn.food_fulfillment='pickup'` they skip the delivery zone and fee. |
| `internal.food_orders_require_stripe_ready` | Unchanged: COD stores must still pass the Stripe gate (finding 1 default). |
| `food_transition_order` | Pickup path: `pending_acceptance → preparing → ready_for_pickup → picked_up`, or `cancelled`. The delivery path is unchanged. Accepting is allowed when `payment_method='cod'`. Delivery statuses are refused on pickup orders and vice versa. |
| `food_complete_delivery` | COD: it also sets `payment_status='paid'` and `paid_at`, records the cash receipt event, and still requires the photo. |
| `food_request_cancel(order, note)` | New, customer only, on their own order. Allowed in `preparing` or `ready_for_pickup`. Sets `cancel_requested_at` and notifies the store. Before acceptance, the existing `food_cancel_order` still applies. |
| `food_resolve_cancel_request(order, approve, refund)` | New, store roles only. If rejected, the request is cleared. If approved with refund, the order goes through the existing cancel path with the automatic refund. If approved without refund, the order is cancelled with `refund_status='none'`. |
| `food_store_set_fulfillment(store, pickup, delivery, cod, prep_minutes)` | New, owner/admin only. Pickup can only be enabled when the store has a structured schedule. |
| Notifications trigger | New messages for "พร้อมรับ", for cancel requests and their outcome, and for COD received. |
| Reports / GP | COD orders: GP = 0. Sales reports and Zoky Admin finance split by `fulfillment_type` and `payment_method`. |

Every new RPC is `security definer`, uses `set search_path=''` and checks `auth.uid()`. RLS on `food_orders` is unchanged. `pickup_code` is visible only to the order's customer and the store's roles.

## 5. Apps

- **Zoky (customer)**
  - Store list and store page show a mode badge.
  - Basket has a mode toggle and, for pickup, a slot picker with no address. For delivery with COD enabled, it offers a "จ่ายเงินสดตอนรับของ" option.
  - Order page shows the pickup code, the store pin with a navigate button, and a "ขอยกเลิก" button.
- **Merchant**
  - Settings: mode toggles, COD and prep minutes.
  - Order list and detail show the mode tag and pickup time and code, with "พร้อมรับ" and "ลูกค้ารับแล้ว" actions, a cancel-request banner with approve/reject and a refund choice, and a COD "ได้รับเงินแล้ว" step inside complete delivery.
- **Zoky Admin**: mode and payment-method columns and filters, and the finance split.
- **i18n**: every new Thai string gets an `EN_EXACT` entry, guarded by the duplicate-key test.

## 6. Delivery plan (separate PRs, each with QA)

1. Read-only dump of the production function definitions. **Needs Founder approval** to run in the production environment.
2. DB migration, rollback SQL and `supabase/tests/zoky_fulfill_001_test.sh`. The test covers:
   - transitions per mode;
   - COD rules;
   - pickup slot validation, including the clock-skew, closed-day and legacy-store cases;
   - cancel request and refund choice;
   - cross-store and cross-customer access denied;
   - the timeout skipping COD;
   - existing coupon, GP and timeout tests still passing.
3. Merchant app (settings and order handling).
4. Zoky customer app.
5. Zoky Admin.
6. Release: apply the migration first, because v2 clients keep working, then ship the apps through staging and the Founder gate. Pickup and COD stay off for every store until the store turns them on.

## 7. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Redefining core create/quote from stale repo code reverts a production fix | HIGH | Finding 5: dump and diff before writing |
| COD orders bypass payment checks in unexpected places | HIGH | Explicit allow-list in the two functions; tests that unpaid online orders still cannot be accepted |
| Store refuses a refund unfairly | MEDIUM (product) | Founder decision; every cancel request and outcome is logged in `food_order_events` and visible in Zoky Admin |
| Status additions break reports or views that enumerate statuses | MEDIUM | grep all SQL and TS enumerations; add regression tests for the sales report, GP and readiness |
