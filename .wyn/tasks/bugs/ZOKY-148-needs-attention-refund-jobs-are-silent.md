# Bug Report — ZOKY-148

Status: bugs
Owner: AI Debug Engineer
Severity: MEDIUM (a refund can stall forever, with no alert, while the UI says it is in progress)

Bug:
Several refund-job outcomes park the job as `needs_attention`:
- `partial_refund_exists`
- `charge_already_refunded` without an adoptable refund
- `order_not_refundable`
- `stripe_environment_mismatch`, for example older ledger rows where `food_stripe_payments.livemode` defaulted to false
- `refund_pending_too_long` (after 30 polls, about 3 weeks)

When that happens:
- no customer or merchant notification is sent;
- the order stays `refund_status='pending'`;
- `merchant_retry_stripe_refund` refuses with `no_failed_refund`;
- `admin_food_refund_jobs` (P1) does not exist, so only a DB query can find these jobs.

Meanwhile the customer sees "กำลังคืนเงิน · ระบบกำลังคืนเงิน…อัตโนมัติ". Under the policy, the merchant sees "ระบบกำลังคืนเงินให้ลูกค้า ไม่ต้องกดคืนเงินเอง".

Reproduction: `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/run.sh qa7 stripecore && DB=qa7 bash /tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/t5_promptpay.sh` (section "needs_attention is silent"). Store-cancel a Stripe-paid order, then call `food_complete_stripe_job(job,'needs_attention',null,'partial_refund_exists')`. The order stays `cancelled/paid/pending`, and there are 0 refund notifications and no retry path.

Expected: an operator alert or list before activation. At minimum, a merchant notification plus a merchant/customer state that does not claim the refund is running.
Fix (suggested): ship `admin_food_refund_jobs` (or a merchant notification plus `refund_status='failed'` with a distinct note) before Stripe-only activation. Add a monitoring query or alert on `status='needs_attention'`.
Files Changed: none (QA). Regression Risk: low.
