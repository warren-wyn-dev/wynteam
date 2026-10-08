# WYNOS Finance Refund Adjustments — Sandbox v1

**QA-only:** Supabase project `pcatuxtenluqzjzzwsvl`, GitHub branch `sandbox/stripe-testmode-20261008`. Do not apply to production, invoke Stripe refunds, change checkout/webhook/payment statuses, run Vercel Deploy, or enable actual GP. **Everything here is SIMULATION ONLY.**

## What is implemented

- `public.food_finance_refund_adjustments_qa`: append-only simulated refund events linked to immutable `food_finance_order_projections_qa` per order.
- `public.food_finance_refund_lines_qa`: six balanced signed reconciliation lines per adjustment, split into two separate books: customer refund (`+customer_refund -food_refund -delivery_refund = 0`) and hypothetical food/GP reversal (`-GP_reversal -store_food_reversal +food_refund = 0`). **Not** Stripe ledger entries, legal general-ledger transactions, or real payout credits.
- `public.food_finance_append_refund_qa(order_id, simulation_key, food_refund_satang, delivery_refund_satang, reason)`: explicitly called by service role in QA. Atomic, locks per-order finance projection to serialize concurrent simulated refunds, rejects over-refunds by food and delivery separately and by customer paid, and rejects conflicting idempotency replays.
- Same `simulation_key` and identical inputs return `already_adjusted`, without duplication. Reusing the key with changed amount or reason raises an error. **Never use an actual Stripe refund ID as an idempotency key here.**
- `public.food_finance_refund_math_qa(original_food, original_delivery, test_rate_bps, cumulative_prior_food_refunded, cumulative_prior_delivery_refunded, new_food_refund, new_delivery_refund)`: **pure**, no DB/Stripe write, with cumulative **half-up** rounding.
- `public.admin_food_finance_refunds_qa(order_id)`: read-only event history, requiring an independently allowlisted, authenticated QA GP admin. A submitted email address alone does not grant permission.
- RLS + grants deny clients read/insert; `UPDATE` and `DELETE` triggers reject alteration of historical adjustments and their reconciliation lines.

## Financial semantics

For a projection with frozen GP rate `r` basis points:

```text
total_illustrative_GP_reverse_after_refunding_food_X
  = floor(X * r / 10000 + 0.5)
new_illustrative_GP_reverse
  = GP_reverse_after - GP_reverse_before
new_illustrative_merchant_food_reverse
  = new_food_refund - new_illustrative_GP_reverse
```

This cumulative method makes tiny successive refunds sum to the same exact total as a single refund. Example: two 1-satang refunds at a hypothetical 50% rate reverse 1 satang of GP on the first event and 0 on the second, **not** 2 satang.

**Full refund** is the event which exhausts the original customer paid amount. Earlier events are **partial refunds**; both are simulations only.

**Unknown and deliberately NOT filled with 0:** actual Stripe refund processing fees and actual merchant net proceeds. The columns `stripe_fee_refund_satang` and `stripe_refund_id` are always `NULL`; `actual_customer_refunded_satang`, `actual_platform_gp_reversed_satang` are constrained to **0**. These indicate no actions were taken by this simulation, not that a Stripe fee was waived.

## Safety policies

- Never create a simulated refund without an existing immutable GP snapshot **and** Finance projection captured earlier against confirmed test-mode PromptPay and the same connected merchant.
- Re-check that the original QA order and payment ledger are still in **paid, non-refunded, non-cancelled** state when creating a new simulated adjustment. If an actual refund was processed or the Stripe payment is not an eligible test-mode PromptPay payment, return `payment_state_not_eligible`.
- **Do not try to allocate promotional discounts automatically.** If `unallocated_discount_satang > 0`, return `discount_allocation_unresolved`. A refund with a discount needs an approved platform/merchant-funded promotion allocation policy first.
- Delivery fee is kept separate, with no unapproved assumptions about who receives it.
- The hypothetical GP percentage comes from the *frozen existing finance projection*; it is not a rate default and can only be created from a previously, explicitly configured QA GP draft (which is currently unconfigured).
- Existing `food_orders`, `food_stripe_payments`, Stripe Checkout, webhooks, transfer and payout logic are **untouched**.

## Tests

Run **only in Supabase QA**: `supabase/sandbox/gp/refunds_smoke.sql`.

This uses the previously paid test-mode PromptPay `WF000005` inside `BEGIN ... ROLLBACK` and verifies:

1. No Finance projection → no refund adjustment.
2. Hypothetical 7.5% GP, partial ฿33.33 food refund followed by remaining ฿16.67 full refund, producing exactly ฿3.75 cumulative hypothetical GP reversal; original GP and Finance snapshots are never altered.
3. Six lines per event, both books balance to zero.
4. Idempotent retries, conflicting replay rejected, refund above original balance rejected, and further adjustment after full refund rejected.
5. Immutable events and lines, RLS and unauthenticated access rejected, allowlisted admin read-only history works.
6. A hypothetical food/delivery split (฿100 food, ฿20 delivery, first refund ฿30 food + ฿10 delivery; second refund ฿70 food + ฿10 delivery) computes correctly.
7. Cumulative half-up rounding for 1-satang partial refunds.
8. Original order remains `paid` with refund status `none` and Stripe ledger remains `paid`, and no actual refund or real GP is recorded.

All test fixtures, mock rates, snapshots, Finance projections and adjustments are rolled back; there is **no permanent GP configuration**.

## Not yet implemented

This system **does not automatically run when Stripe issues a refund** and does not trigger refunds itself. Before integrating genuine Stripe refunds, separately approve: discount sponsor and refund allocation policy, platform/merchant GP basis and rates, real Stripe balance-transaction fee handling (unknown here), whether Stripe Connect application fees are supported for Thai PromptPay direct charges for this account, reversal mechanics, customer notifications, taxes, dispute/chargeback rules and audit retention. A separate user authorization is required for any actual-money work and Production deployment.
