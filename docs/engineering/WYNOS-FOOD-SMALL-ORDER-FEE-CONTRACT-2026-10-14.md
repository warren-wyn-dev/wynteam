# Food small-order fee — implementation contract pending revenue allocation

Date: 2026-10-14. Related acceptance: [#1144](https://github.com/warren-wyn-dev/wynteam/issues/1144), under the coordinated release freeze. This is a source/design handoff, not an enabled charge or deployment approval.

## Agreed rule and missing decision

The controlling specification sets a **THB 15** fee when the food subtotal **before discounts is below THB 60**. Neither this amount nor the threshold needs another decision. Server-resolved menu options contribute to that food subtotal.

The specification and issue do not identify the beneficiary of the fee. The Founder has been asked whether this is merchant revenue or platform revenue. Do not infer this from the existing direct-charge flow, rename it a delivery charge, or silently put it in the GP ledger. Implementation that changes payable totals remains pending this answer.

## Verified current gap

- The latest canonical `food_quote_order` and `food_create_order` in `supabase/migrations_wynos_food_order_options_v1.sql` calculate food subtotal minus campaign discount plus delivery minus delivery discount. Their v2 wrappers delegate to these definitions. No small-order component is present.
- The order total consistency constraint, consumer/merchant order mappings and checkout/receipt breakdowns also omit the component.
- `merchant_finance_summary` and `admin_merchant_finance_overview` infer discounts from `subtotal + delivery_fee - total`. Adding only a surcharge to the total would corrupt that inference.
- Existing Stripe application-fee columns represent GP. A platform-beneficiary fee needs separately classified collection/refund/reconciliation amounts; it cannot be added to those GP amounts without updating their accounting contract.

## Required coordinated implementation

1. Add an explicit immutable fee amount and policy-version snapshot to new orders. Historical orders retain zero and unchanged totals. Quote and create must use the same server rule, with the authoritative menu price/options and discounts; client input cannot choose or waive the fee.
2. Preserve the existing developer rollout rule from [WORKFLOW.md](../../.wyn/company/WORKFLOW.md#staged-rollout-เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่-เพิ่ม-2026-09-06): calculate/show the new charge for developer accounts first, with the same decision enforced on the server. Ordinary users retain the prior totals and UI until an explicit public rollout decision.
3. Keep the fee distinct from delivery pricing, promotion qualification and the GP food-subtotal base. Preserve the approved first-order 100/40 merchant-funded offer and existing single-campaign selection.
4. Extend consumer cart, checkout and persisted order detail; merchant order detail and printable receipt; and Admin order detail/recorded payment monitoring with the explicit component. Amounts displayed before payment and stored on the order must agree.
5. Correct Merchant/Admin finance totals using authoritative discount and fee snapshots. Once the beneficiary is known, define gross customer charge, merchant proceeds, platform proceeds and applicable full/partial refund treatment before wiring the Stripe amount/fee metadata.
6. Preserve existing order/charge snapshots on forward/reapply/rollback. A rollback must coordinate matching code and retain already charged fee history; it must not retroactively remove a fee from a settled order.

## Focused verification

- Food subtotal 59.99 gives fee 15; subtotal 60.00 gives zero. An otherwise valid zero-price basket follows the same rule; an invalid/empty basket remains rejected by existing validation.
- A discount that reduces a subtotal of at least 60 below 60 does not create a fee. Menu options/quantities can move a basket across the threshold and must be resolved on the server.
- Developer and ordinary accounts, missing/foreign sessions and direct RPC calls preserve the rollout and ownership rules.
- Public quote/create agree, including changed menu/discount inputs, repeated/concurrent attempts, immutable historical orders and first-order eligibility at 99.99/100.00.
- Consumer/Admin/merchant breakdowns, provider charge bounds, refund/replay cases, revenue allocation and finance reports reconcile to the same stored components.
- Rehearse migration/reapply/data-preserving rollback and authenticated nonproduction checkout. Do not use the production-backed preview for these writes or enable the new charge in production during the freeze.
