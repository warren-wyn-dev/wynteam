# Bug Report — ZOKY-153

Status: approved (fixed and verified in Re-test 3, 2026-10-23: payjobs 869e1705 — stripe-webhook no longer marks refunded on charge.refunded; 0 spurious notifications. Condition: the production webhook endpoint must be subscribed to refund.* events, see the QA doc Re-test 3)
Owner: AI Debug Engineer
Severity: MEDIUM (a misleading money notification and push on the main PromptPay refund path; no money is moved wrongly)
Found in: Re-test 2 (payjobs 99c74881)

Bug:
The ZOKY-147 fix puts the order back from `payment_status='refunded'` to `'paid'` in two places:
- `food_complete_stripe_job('refund_requested')`, when the webhook's `charge.refunded` flagged the order before the PromptPay refund finished;
- `internal.food_stripe_job_fail`.

The existing trigger `food_orders_notify_merchant_payment` → `internal.food_order_notify()` notifies on every UPDATE where payment_status becomes `'paid'`. This holds in both repo versions (merchant_payment_core_v1:304 and merchant_accounts_v2:663). Each revert therefore sends:
- to the customer: "ชำระเงินออเดอร์ #X สำเร็จแล้ว" (plus a push, if notifications are pushed);
- to the merchant and staff: "WYNOS Merchant · ชำระเงินแล้ว #X".

The order is already cancelled, and the customer is waiting for a refund. This can happen on most PromptPay refunds (once when charge.refunded arrives early, once more if the refund fails), and again on every later charge.refunded event.

Reproduction: `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/run.sh r2q7 stripecore && DB=r2q7 bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t6_round2.sh` (section "awaiting-customer flips"). After 3 rounds of webhook charge.refunded followed by a worker poll (refund_requested, awaiting=true), the buyer's "ชำระเงิน…สำเร็จแล้ว" notifications go from 1 to 4. The order state is correct each time (`cancelled/paid/pending`), and no second refund job is created.

Expected: putting a refund back must not announce a new payment.
Fix (suggested, smallest, no redefinition of the legacy notify function):
- Option A (not workable): keep `payment_status='refunded'` in the revert. The UI and the merchant retry depend on `'paid'`.
- Option B: set a transaction-local flag before the revert UPDATE, for example `set_config('wynos.food_refund_revert','on',true)` (same pattern as `wynos.food_auto_cancel`). This needs `food_order_notify` to honour it, which means redefining it; that needs a CTO call.
- Option C (preferred, outside the current allowlist): stop the webhook marking `refunded` on `charge.refunded` unless the refund itself is `succeeded`, and let the worker own the final state. The revert then almost never happens.
Tests: assert 0 new "สำเร็จแล้ว" notifications across a revert, in t6_round2.sh and in the developers' SQL suite.
Regression Risk: low.
