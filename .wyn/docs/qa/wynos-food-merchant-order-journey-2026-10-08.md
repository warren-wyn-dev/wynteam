# WYNOS Food → Merchant — Order Journey QA

**Date:** 2026-10-08  
**Change scope:** QA test-only, no customer/order/Stripe data writes  
**PR:** #1041  
**Other active PRs:** #1039 promotional coupons and notifications; #1040 Stripe webhook terminal-state hardening (do not merge/modify as part of this QA PR).

## Executable regression matrix

| Stage / negative case | Automated check |
| --- | --- |
| Server-side menu pricing, add-ons, required options, order flood limits | `supabase/tests/wynos_food_order_options_test.sh` |
| New Food order protected from unauthorized merchant activity | `supabase/tests/wynos_food_merchant_order_journey_test.sh` |
| Open Stripe Checkout cannot be bypassed with a payment slip | `wynos_food_merchant_order_journey_test.sh`; `wynos_stripe_payment_core_test.sh` |
| Payment slip submitted; no accidental resubmit | `wynos_food_merchant_order_journey_test.sh` |
| Only store owner/order team verifies manual payment | `wynos_food_merchant_order_journey_test.sh` |
| Restaurant cannot prepare unpaid or cancelled orders | `wynos_food_merchant_order_journey_test.sh` |
| Status `preparing → ready_for_delivery → out_for_delivery → delivered` and event audit | `wynos_food_merchant_order_journey_test.sh` |
| Delivery requires uploaded image and matching order path | `wynos_food_merchant_order_journey_test.sh`; `wynos_food_delivery_storage_test.sh` |
| Customer receives one delivery notification; no duplicate completion | `wynos_food_merchant_order_journey_test.sh` |
| Private slip / delivery proof storage is isolated by merchant | `wynos_food_delivery_storage_test.sh` |
| Paid cancellation opens refund request without falsely recording refund as completed | `wynos_food_merchant_order_journey_test.sh` |
| Stripe signed webhooks, amount/account validation, deduplication, refunds | `wynos_stripe_payment_core_test.sh`; PR #1040 |
| App-specific Social/Food/Merchant push-token routing | `wynos_push_app_routing_test.sh`; `wynos_food_order_push_share_stats_test.sh` |
| Food and Merchant Web browser UX and UI source contracts | Existing `web/tests/browser/wynos-food-developer-preview.spec.ts` and `wynos-merchant.spec.ts` |

The newly added lifecycle test loads *actual committed SQL RPC definitions* into a disposable PostgreSQL database. It does not implement a substitute business-logic copy; its fixture begins from an existing Food order, while order creation/pricing is covered by the separately maintained options test.

## Production read-only audit (2026-10-08)

- Food orders: 16; delivered: 3. Delivered timestamps and cancellation timestamps not missing.
- All 3 delivered orders have proof rows and nonempty image paths.
- No delivered orders without `paid/refunded` payment status, no preparing orders without a paid status, no negative order totals, and no inconsistent component totals in the queried snapshot.
- Stripe payment rows: 0. Therefore live Stripe end-to-end payment and refund *have not* been verified.
- These are point-in-time, aggregate SQL checks, **not** proof of mobile Push delivery or charge settlement.

## Non-production manual QA still required before calling release 100% ready

1. On Food iPhone/Android/Web, select real menu options, delivery location and schedule, confirm server quote matches checkout.
2. Using test customer and merchant accounts, submit an order and check merchant receipt/sound (with correct store isolation).
3. Run both manual slip verification and **Stripe TEST mode** flows (success, async pending/failure, reattempt, duplicate webhook).
4. Verify cancellation before and after paid, refund initiated by authorized manager, Stripe refund webhook, and merchant payout/settlement.
5. Complete a delivery with photo and confirm Food push and Merchant push land in their own installed PWAs.
6. After PR #1039 is released separately, validate coupon-assisted checkout (valid, expired, over quota, concurrent) and marketing consent routing.
7. Monitor real-time errors, Stripe dashboard/webhook delivery logs and post-deployment read-only financial audits. Stop rollout if order/payment discrepancies appear.

## Safety and release gate

- Run the required repository CI and browser QA at the final commit.
- Do not create test transactions in Production; do not send unsolicited promotional Push.
- Do not assert real charge/refund/Push success until actual controlled device and Stripe test-mode sessions have completed.
- PR #1041 contains test-only files; it should not alter deployed business logic, database schema, or notification routing.
