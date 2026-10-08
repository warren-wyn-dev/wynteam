# WYNOS Food GP Engine — Sandbox/QA v1

**Scope:** only GitHub branch `sandbox/stripe-testmode-20261008` and Supabase QA project `pcatuxtenluqzjzzwsvl`. Never deploy this GP migration, its RPCs or test fixtures to Production without a separate decision and migration review. No Vercel deployment required.

## Behavior

- Rates stay **unconfigured** by default. Missing rate is **not** silently interpreted as 0%. An explicit 0% draft can be set later.
- `public.food_gp_calculate_qa(food_subtotal_satang, rate_bps)` is a pure calculation in **integer satang**, rounding **half up**.
- Calculation basis for this simulation is **pre-discount food subtotal** (`food_orders.subtotal`). **Delivery fee is excluded**. The order's discount (`subtotal + delivery - total`) is recorded for transparency but not deducted from the present preview basis. Treatment of merchant/platform discounts, taxes, tips, payment-provider fees, and partial refunds must be approved before real GP.
- `public.food_gp_capture_order_qa(order_id)`: explicitly invoked by a trusted QA backend using **service_role**. No triggers on payment paths and no Stripe API calls. No rate: returns `rate_not_configured` and creates nothing. With a rate: only captures an existing **paid, non-refunded, non-cancelled, Stripe test-mode** order with matching Stripe paid ledger, THB amount, store and PaymentIntent.
- Each order receives **at most one immutable snapshot**. Captured GP rate, food subtotal, delivery, discount, simulated GP/store share, rate configuration date and Stripe PaymentIntent remain frozen even if draft rate later changes. Repeat capture returns `already_snapshotted`.
- `actually_collected_gp_satang = 0` enforced by DB constraint, `mode = simulation_only` enforced by DB constraint. The capture function does **not** change food_orders, Stripe ledger, webhook, payouts or refunds.
- Snapshot table uses RLS and revoked access from `anon` and `authenticated`. Only a trusted `service_role` can read/insert. `admin_food_gp_order_snapshot(order_id)` is a role-checked, read-only RPC requiring the separately authorized QA GP Admin allowlist.
- DB trigger rejects **UPDATE and DELETE** on snapshots so revisions and refunds require separate append-only adjustment records in a future phase.

## Test

In the **QA Supabase SQL editor only**, run `supabase/sandbox/gp/engine_smoke.sql`. It verifies no-rate behavior, half-up rounding, frozen snapshots, idempotence, immutability, no GP collection, permissions and unchanged paid order. All temporary GP rates and snapshots are **rolled back**, leaving the real QA sample payment untouched.

A real Admin account still needs to complete QA email verification and be explicitly authorized. Do not grant permission from an email address supplied in chat alone.

## Future decisions

1. Whether to use pre-discount subtotal or merchant-funded post-discount food revenue as the chargeable base.
2. Return/refund and chargeback adjustment ledger, including full and partial refunds.
3. Stripe Connect commercial/technical feasibility for commission collection on Thai PromptPay direct charges, including Stripe fees, payout timing and tax treatment.
4. Only after review: separate production rollout, explicit GP rate and safe payment integration.
