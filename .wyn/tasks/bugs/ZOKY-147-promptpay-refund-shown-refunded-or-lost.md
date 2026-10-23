# Bug Report — ZOKY-147

Status: bugs
Owner: AI Debug Engineer
Severity: HIGH (money: a refund can fail while the order says "คืนเงินแล้ว", and nobody is told)
Branches: wynteam-payjobs feat/zoky-stripe-jobs-db (worker + migration 20261023100000), wynteam-payweb feat/zoky-stripe-only-web (customer/merchant UI), stripe-webhook (unchanged, on both)

Bug:
Stripe's PromptPay refunds are not instant. Stripe emails the customer and asks for the bank account the payment came from. Until the customer replies, the refund stays `requires_action`/`pending`. If the customer never replies, the refund may fail. Source: docs.stripe.com/payments/promptpay#refunds. Under Stripe-only, PromptPay is the main payment method, so this is the main refund path, and today it is not handled safely:
1. **Worker stops polling once the DB says "refunded".** In `_lib.ts` `refund()`, the first check returns `{outcome:"refunded"}` whenever `order_payment_status` or `order_refund_status` is `refunded`. That check runs before the "poll a refund we already asked for" branch. So when anything else marks the order refunded, the job is closed as success and the worker never sees its own refund fail.
2. **The webhook can mark the order refunded before the money moves.** `stripe-webhook` maps `charge.refunded` with `amount_refunded >= amount` to state `refunded`. Stripe counts pending refunds in `amount_refunded` (must be confirmed in Stripe test mode). So a PromptPay refund that is still waiting for bank details turns the order into `refunded/refunded`. Point 1 then closes the job.
3. **A refund that fails after that is silent.** `internal.food_stripe_job_fail` only updates orders `where payment_status='paid'`. When the order is already `refunded`, it returns early: no `refund_status='failed'`, no customer or merchant notification. `merchant_retry_stripe_refund` then says `stripe_refund_not_eligible`.
4. **Nobody tells the customer what to do.** The customer pending copy (`foodRefundNotice`) says "ระบบกำลังคืนเงินเต็มจำนวนเข้าช่องทางที่คุณชำระโดยอัตโนมัติ". The "refunded" copy says the money is already back. Nothing says "ตรวจอีเมลจาก Stripe แล้วตอบกลับด้วยเลขบัญชีที่ใช้จ่าย". The worker ignores `refund.next_action.display_details.email_sent`. The merchant failure copy only mentions the Stripe balance ("ยอดเงินในบัญชี Stripe ของร้านไม่พอ"), and a merchant retry just creates a new refund that needs the same email reply.
5. **GP is booked as returned too early** (LOW while GP is 0%). `food_complete_stripe_job('refund_requested', …, p_fee_refunded=true)` sets `application_fee_refunded_satang` when the refund is requested. Nothing undoes it if the refund then fails or is canceled.

Reproduction (synthetic, throwaway Postgres 16 running the REAL food_apply_stripe_event / food_transition_order bodies plus the migration):
- `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/run.sh qa7 stripecore && DB=qa7 bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t5_promptpay.sh`
  1. PromptPay-paid order, store cancels, refund job queued.
  2. The worker reports `refund_requested re_pp` (refund is requires_action). Job → awaiting_refund, and the fee is already marked returned (600).
  3. The webhook's `charge.refunded` → `food_apply_stripe_event(...,'refunded')` → order `cancelled/refunded/refunded`.
  4. `food_complete_stripe_job(job,'failed',null,'refund_failed_…')` → job failed, but the order still says `refunded`, there are 0 customer/merchant failure notifications, and the merchant retry is rejected.
- Worker short-circuit (mocked fetch): `deno test --allow-read /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/deno/promptpay_refund_test.ts`. A job that is `awaiting_refund` with `order_payment_status='refunded'` returns `refunded` with **0 Stripe calls**, even though Stripe would answer `status: failed`.

Expected:
- A refund is only final when Stripe reports `succeeded`.
- A failed or canceled refund always ends with `refund_status='failed'` plus customer and merchant notifications, even if the order was marked refunded early.
- For PromptPay, the customer is told to check the Stripe email and reply with the bank account number.

Actual: the order shows "คืนเงินแล้ว"; the refund can fail silently; the money stays in the store's Stripe balance.

Root Cause: The refund is treated as final when it is requested or when the order flag says so, not when Stripe confirms it. The UI and notification copy assume refunds go back automatically, which is true for cards but not for PromptPay.

Fix (suggested, smallest):
- Worker: when `status='awaiting_refund'` and `stripe_refund_id` is set, always GET the refund, even if the order says refunded. Only short-circuit queued jobs, and only after listing refunds at Stripe.
- `food_stripe_job_fail`: for refund jobs, also handle `payment_status='refunded'` orders. Set `refund_status='failed'`, consider restoring `payment_status='paid'` (needs a design decision), log an event and notify.
- Webhook (on the ZOKY release and on main): do not treat `charge.refunded` as `refunded` unless the refund itself has `status='succeeded'`, or let the worker own the final state. This needs a CTO decision because the webhook is outside the current allowlist.
- Mark GP fee refunded only on the `refunded` outcome.
- Copy (Thai):
  - For Stripe refunds on PromptPay orders, add "ตรวจอีเมลจาก Stripe และตอบกลับด้วยเลขบัญชีธนาคารที่ใช้ชำระ ภายในเวลาที่กำหนด มิฉะนั้นการคืนเงินอาจไม่สำเร็จ". This needs the payment method exposed to the customer, for example through a boolean or a field in the customer order view.
  - Merchant failure copy: mention that the customer has not provided bank details.
- Optional: store `next_action.display_details.email_sent.email_sent_at` / `expires_at` on the job and show it to the merchant.

Files Changed: (none — QA)
Tests: add regression tests for the 4 steps above (SQL + deno), plus a Stripe test-mode E2E for a PromptPay refund (requires_action → succeeded, and → failed).
Regression Risk: medium (refund state machine); card refunds must keep working.
Handoff to QA: re-run t5_promptpay.sh (BUG lines must flip) plus the full suites.
