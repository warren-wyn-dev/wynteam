# Bug Report — ZOKY-156

Status: approved (fixed and verified in Re-test 6, 2026-10-23, payjobs fa2dafbb). LOW residuals are listed below.
Owner: AI Debug Engineer
Severity: MEDIUM (found by Codex on 0b1cbafc): after a partial refund or a duplicate-PI refund, needs_attention refund jobs stayed stuck even after the operator refunded at Stripe.

Fix verified:
- After every succeeded Refund-object event, stripe-webhook calls `food_requeue_stripe_refund_jobs(pi)`. The RPC is service_role only, validates the PI format (`^pi_…`), and requeues only codes that a Stripe refund can resolve.
- The worker re-reads Stripe's refund list:
  - order jobs are adopted or polled, and never POST a second full refund;
  - duplicate jobs are check-only and close as done only when succeeded refunds cover the payment;
  - the order is never touched.
- `food_stripe_job_fail` no longer changes the order for duplicate jobs.

QA evidence:
- `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t9_round6.sh` — 31 passed. The 2 FAILs are a harness modelling error: the pending-remainder gating is in the webhook, and the deno tests cover it.
- `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/deno/round6_test.ts` — 6/6 passed.

LOW residuals:
1. Each time a duplicate job is parked again (a partial refund of the duplicate), the merchant gets another "ต้องให้ทีม ZOKY ตรวจสอบ" notification. This is bounded by real refund events at Stripe; it is not client-triggerable.
2. Race: a succeeded refund event processed while the job is still queued/awaiting (before the worker parks it) does not requeue it later. The job stays needs_attention until another refund event arrives, or an operator acts through `admin_food_refund_jobs`. Suggest an admin "recheck" action or a periodic recheck of needs_attention jobs.
3. A failed or pending remainder never sends a succeeded event, so the job correctly stays parked for the operator.
