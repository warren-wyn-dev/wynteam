# Bug Report — ZOKY-150

Status: bugs
Owner: AI Debug Engineer
Severity: MEDIUM (conditional on the live definition of food_set_payment_status; needs a merchant with the orders role)

Bug:
Two definitions of `public.food_set_payment_status(uuid,text,text)` exist in the repo:
- `migrations_wynos_stripe_payment_core_v1.sql:356` refuses Stripe orders;
- `migrations_wynos_merchant_core_completion_v1.sql:495` does not.

If the second one is live, a merchant can call `food_set_payment_status(order,'refunded')` on a Stripe-paid order, then cancel it. Because payment_status is no longer 'paid':
- no refund job is queued;
- a job queued earlier is closed as "refunded" by the worker short-circuit (ZOKY-147 point 1);
- the customer sees "คืนเงินแล้ว" although Stripe never refunded.

`food_orders_payment_guard` blocks non-Stripe paid/issue, but not a non-Stripe change to 'refunded' on a Stripe order.

Reproduction: `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/run.sh qa4 corecompletion && DB=qa4 bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t3_policy_on.sh` (section "provider spoofing"). The output shows "food_set_payment_status(refunded) on Stripe order: ''" (accepted), then "after cancel: cancelled/refunded/stripe/refunded jobs=[]". With the stripe_payment_core variant (qa3), the same call is refused ("managed by webhook").

Expected: a Stripe-paid order becomes refunded only through Stripe (webhook or worker).
Fix (suggested):
- Add the step 0 preflight from the design: dump `pg_get_functiondef` of food_set_payment_status, food_transition_order, food_cancel_order, food_submit_payment and food_apply_stripe_event, and add it to the apply workflow.
- Extend the guard: when old.payment_provider='stripe' and new.payment_status='refunded', require `auth.role()='service_role'` (both the webhook RPC and the worker run as service_role; merchant RPCs run as authenticated).
Files Changed: none (QA). Regression Risk: low.
