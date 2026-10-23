# Bug Report — ZOKY-154

Status: approved (fixed and verified in Re-test 5/6, 2026-10-23, payjobs fa2dafbb: the ledger keeps the first PaymentIntent, the webhook marks refunded only for the order's own PaymentIntent, and the t7 loss path passes)
Owner: AI Debug Engineer
Severity: HIGH (money: after a duplicate payment, the customer's real payment can end up never refunded while the order says "คืนเงินแล้ว")
Found in: Re-test 4 (payjobs fa1e9e49)

Bug:
The PR #1231 fix keeps the FIRST PaymentIntent and session on `food_orders` and binds the `duplicate_payment` job to the NEW PI. But `food_apply_stripe_event` (not redefined) upserts `food_stripe_payments` with `payment_intent_id = coalesce(excluded.payment_intent_id, …)` and the same for `checkout_session_id`. So the ledger row now points at the DUPLICATE PI and session, not the first.

`stripe-webhook` resolves a Refund event's order through `food_stripe_payments.payment_intent_id`. It then marks the order refunded when the amount equals the order total, and it never checks that the refund's PI is the order's PI.

When the operator follows the runbook and refunds the duplicate (Dashboard or API):
1. `refund.updated succeeded` for the duplicate PI → the order is marked `payment_status='refunded'`, `refund_status='refunded'`, even though the first payment is still held. On a live order the order then shows "คืนเงินแล้ว" while it is being prepared.
2. If the store later cancels, no refund job is queued, because the triggers need `payment_status='paid'`. The first payment is **never refunded** and there is no alert.

The same mismatch also means that a Dashboard refund of the FIRST PI (no wynos metadata) cannot be matched to the order any more (orderId null → noop).

Reproduction (real food_apply_stripe_event + food_transition_order bodies, synthetic data):
`/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/run.sh r4c corecompletion && DB=r4c bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t7_round4.sh`
- "duplicate payment BEFORE cancel": order `pi_1/cs_1`, ledger `pi_2/cs_2`.
- "operator refunds the duplicate … on a LIVE order": `preparing/refunded/refunded/pi_g1`.
- "loss path": after the store cancels, `cancelled/refunded/refunded/pi_h1` with jobs `[duplicate_payment:needs_attention:pi_h2]` only. FAIL: no refund job for pi_h1.

Expected: refunding the duplicate never changes the order's refund state; the first payment is still refunded automatically on cancel.

Fix (suggested):
- (a) Keep the ledger consistent with the order. Add an additive BEFORE UPDATE trigger on `food_stripe_payments`: when the row is already `paid` with a different `payment_intent_id`, keep the old PI, session and status. The duplicate stays only on the job.
- (b) In `stripe-webhook`: for refund events, mark refunded only when the refund's `payment_intent` equals `food_orders.stripe_payment_intent_id` (select it together with `total`). Otherwise use noop and record the event.
- Doing both is preferred.
Tests: a t7 "loss path" FAIL → PASS; a Dashboard refund of the first PI still resolves the order; a refund of the duplicate leaves the order state unchanged.
Regression Risk: medium (payment ledger); card and PromptPay single-payment flows must be unchanged (t2, t4, t6, t153).
