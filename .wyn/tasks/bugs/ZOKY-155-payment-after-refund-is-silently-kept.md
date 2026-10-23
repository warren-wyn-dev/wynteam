# Bug Report — ZOKY-155

Status: bugs
Owner: AI Debug Engineer
Severity: LOW (rare: needs an extra payment after the order was refunded)

Bug:
A second payment that arrives after an order was cancelled AND refunded is not detected:
- the `food_apply_stripe_event` paid update only matches `payment_status in ('pending','issue','submitted','paid')`, so no trigger fires;
- no `duplicate_payment` job is created and no one is notified;
- the ledger row is flipped back to `status='paid'` with the new PI.

The money stays in the store's account.
Reproduction: `DB=r4c bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t7_round4.sh`, section "duplicate payment AFTER the refund completed". Result: order `cancelled/refunded/refunded/pi_f1`, jobs `[store_cancelled:done]`, ledger `paid/pi_f2`.
Expected: a needs_attention duplicate job (or an automatic refund) for pi_f2.
Fix: the same ledger trigger as ZOKY-154 (a), which can also queue the needs_attention duplicate job when the order is already refunded.
