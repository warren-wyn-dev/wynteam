# Bug Report — ZOKY-149

Status: approved (fixed and verified in Re-test 2, 2026-10-23: one owner of the refund — the automatic box whenever a job exists, and merchant-stripe-refund adopts an existing refund)
Owner: AI Debug Engineer
Severity: MEDIUM (false "refund failed" state shown to the customer and merchant; no double refund)

Bug:
From rollout step 3 (cron on) until step 7 (Stripe-only activation), automatic refunds already run because they do not depend on the policy. During that window the merchant UI is the legacy one (`RefundControls` with `stripeOnly=false`), which still shows "คืนเงินผ่าน Stripe" for a cancelled Stripe-paid order with refund_status pending. Merchants are used to pressing it right after cancelling.

If the worker's refund already exists:
- `merchant-stripe-refund` (no list-before-create) gets a Stripe error (`charge_already_refunded`);
- its catch block writes `refund_status='failed'`, `refund_note='การคืนเงินไม่สำเร็จ'`;
- the merchant sees an error, and the customer sees "คืนเงินมีปัญหา ติดต่อร้าน" until the worker's next poll fixes it. With a PromptPay refund waiting for bank details, that can take days (see ZOKY-147).

`merchant-stripe-refund` also stays callable directly under the policy.

Reproduction (code path; real Stripe not available):
1. Store cancels a Stripe-paid order → `food_stripe_jobs` refund queued.
2. The worker creates a pending refund → `refund_requested`.
3. The merchant presses "คืนเงินผ่าน Stripe" → Stripe returns 400 `charge_already_refunded` → the catch in `supabase/functions/merchant-stripe-refund/index.ts` sets refund_status='failed'.

No double refund: Stripe caps a full refund, and the worker adopts existing refunds. Verified in the deno tests and by code review.

Expected: once auto-refund is live, one owner of Stripe refunds.
Fix (suggested):
- Show the automatic-refund panel for `payment_provider='stripe'` orders whenever the jobs migration is installed, not only when the policy is on (for example, gate it on `food_payment_policy_public` existing, or on a jobs-installed flag).
- And/or make `merchant-stripe-refund` list refunds first, and treat `charge_already_refunded` as adopt-not-fail.
Files Changed: none (QA). Regression Risk: low.
