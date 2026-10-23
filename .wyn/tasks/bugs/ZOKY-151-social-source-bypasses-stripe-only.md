# Bug Report — ZOKY-151

Status: bugs
Owner: AI Debug Engineer
Severity: LOW (not reachable by clients today)

Bug: The Stripe-only gates key on `new.source = 'app'`, but the check constraint allows `('app','manual','social')`. A `source='social'` order is not covered by any gate while the policy is on:
- the order gate (an unready store accepts it);
- the slip block (`food_submit_payment` succeeds);
- the manual paid/issue block (`food_set_payment_status('paid')` succeeds).

Today no RPC creates 'social' orders, and INSERT on food_orders is revoked from clients, so this is latent.
Reproduction: `DB=qa3 bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t3_policy_on.sh`. See the "BYPASS?" lines; all three succeed.
Expected: deny by default. Only the D7 exclusion (`source='manual'`) should be exempt.
Fix: use `new.source is distinct from 'manual'` in `food_orders_payment_guard` and `food_orders_require_stripe_ready`, and mirror it in merchant `manualPaymentAllowed` (`order.source === "manual"`).
