# ZOKY Stripe-only payments: Step 1 (close gaps + auto-refund) and cut-over — Architect design

Status: DRAFT for CTO review and Founder approval (2026-10-22). This is a read-only review of `release/zoky-web-20261018` @ `e6f577dc` and `origin/main` @ `1166a59d`. Nothing has been applied.
PRD: `.wyn/docs/product/zoky-promptpay-auto-refund-prd.md`. Decisions: `.wyn/company/DECISIONS.md` (2026-10-22).

## 0. Current state (confirmed in code)
- **G1** When a customer cancels an unpaid order, the Stripe Checkout session is not expired. `food_cancel_order` (`supabase/migrations_wynos_food_customer_access_gate_v2.sql:234-280`) only sets the status. The UI `cancel()` (`wynos-food-developer-app.tsx:2942`) only calls `cancelFoodCustomerOrder`.
- **G2** When a merchant cancels an unpaid order, the session is not expired either: `food_transition_order` (`migrations_wynos_merchant_core_completion_v1.sql:537-606`) makes no Stripe call.
- **G3** A Checkout session stays payable for 24h, because `food-stripe-checkout` never sets `expires_at`. Stripe's minimum is 30 min.
- **G4** A payment that arrives after a cancel marks the order paid and the money gets stuck. In `food_apply_stripe_event` (`migrations_wynos_stripe_payment_core_v1.sql:114-235`) the paid branch ignores `status`, and nothing refunds the payment.
- **G5** Refunds are merchant-initiated only: `food_transition_order` sets `refund_status='pending'` and the merchant clicks `merchant-stripe-refund`.
- **G6** `refund.failed` is a noop in `stripe-webhook` (~466), so a failed refund is never recorded on the order.
- **G7** The 10-min timeout path is already safe (`food-unpaid-timeout` expires the session, then calls `food_timeout_cancel`). This design reuses that pattern.
- **G8** The recorded payment method is `payment_method_types[0]`, not the method actually used.
- **R** The live versions of several RPCs are uncertain because root-level `migrations_*.sql` files redefine them many times. The design therefore does not redefine those RPCs; it uses additive triggers. Preflight dumps `pg_get_functiondef` for each one.

## 1. Step 1 — close the gap
In the same transaction as each cancel or payment, the database writes a durable job. A cron worker then executes the job at Stripe. Because the jobs come from table triggers, every cancel path is covered and no client is trusted.

### 1a. Expire the Checkout session on any cancel
- **Trigger:** an AFTER UPDATE trigger on `food_orders` adds an `expire_checkout` job when the status becomes `cancelled`, `payment_status` is `pending` or `issue`, and `stripe_checkout_session_id` is set.
- **Worker:** if the session is `open`, expire it. If it is `complete`/paid, do nothing (1b handles it). If it is `expired`, mark the job done. The worker never downgrades a `paid` status.
- **Customer UI:** `cancel()` first calls the existing `food-stripe-cancel` when a session exists, then `food_cancel_order`. If that returns 409 `stripe_payment_already_completed`, show "ชำระเงินแล้ว ยกเลิกไม่ได้ ติดต่อร้าน" (D3).
- **Backstop:** `food-stripe-checkout` sets `expires_at = now + 30 min`.

### 1b. A payment that lands on a cancelled order is refunded automatically (no webhook change)
- **Trigger:** a BEFORE UPDATE trigger on `food_orders` fires when the new row is `cancelled` + `paid` + provider `stripe` and the old row was not both. It sets `refund_status='pending'` and `refund_requested_at`. The AFTER trigger then adds a `refund` job, with reason `paid_after_cancel` or `store_cancelled`.
- **Duplicate payment** (a different payment intent on an order that is already paid): the trigger adds a job with status `needs_attention`. It does not auto-refund; that is P1 and needs a `food_apply_stripe_event` change.

## 2. Automatic refund when a store cancels a paid order
- **Flow:** DB trigger → `food_stripe_jobs` table → new cron edge worker `food-stripe-refund-worker`. It copies `food-unpaid-timeout`: pg_cron + pg_net, the key in Vault, the service role.
- **Rejected:** calling the refund from the cancel path, because it is a browser RPC and the refund could be lost.
- **Rejected:** webhook-only, because it does not cover store cancellations.
- **Worker:** runs every minute and is authorised by `x-wynos-cron-key` through `food_refund_worker_cron_authorized`. It claims jobs with `food_claim_stripe_jobs(limit)` (FOR UPDATE SKIP LOCKED + `locked_until`). For each refund job:
  1. Livemode guard.
  2. `GET /v1/refunds?payment_intent=…` on the paying account (`Stripe-Account`). If a non-failed refund already exists, adopt it.
  3. `POST /v1/refunds` with `payment_intent`, `reason=requested_by_customer`, `refund_application_fee=true` when GP > 0, and metadata. No `amount` is sent, so it is always a full refund (D4, D6). The request uses `Idempotency-Key: wynos-refund-job-<job_id>`.
  4. `food_complete_stripe_job(...)`.
  5. Poll `GET /v1/refunds/{id}` until it is `succeeded` or `failed`. This fixes G6 without touching the webhook.
- **No double refund**, because of:
  - the unique job key;
  - list-before-create;
  - the idempotency key;
  - Stripe's full-refund cap (`charge_already_refunded` is treated as success after re-listing).
- **Retries:**
  - Transient errors back off 1m, 5m, 15m, 1h, 6h, then 24h, for up to 8 attempts.
  - Permanent errors (invalid account, insufficient balance — D5 is still open) go to `failed`.
  - On failure the order gets `refund_status='failed'`, and the merchant, the customer ("คืนเงินมีปัญหา ติดต่อร้าน") and the admin list are notified.
  - Merchant retry is `merchant_retry_stripe_refund`, which only requeues the job.
- **Existing pieces:**
  - `merchant-stripe-refund` stays deployed as a legacy fallback.
  - The webhook already maps refund success to `refunded`.

## 3. Cut-over (Stripe-only, D7–D11)
- **Policy switch:** `public.food_payment_policy(stripe_only_from timestamptz)`. NULL means legacy behaviour. Activating it is one Founder-gated update; rollback sets it back to NULL. The web reads `food_payment_policy_public()` and falls back to legacy if the RPC is missing.
- **Order creation gate:** a BEFORE INSERT trigger on `food_orders` for `source='app'` while the policy is on. It requires the `food_stripe_accounts` status to be `ready`, `details_submitted` and `charges_enabled`, and the store's `stripe_payments_enabled`; otherwise it raises `store_not_accepting_orders`. PromptPay is optional (D9).
- **Slip/manual block:** a BEFORE UPDATE OF payment_status/provider trigger on `source='app'` orders while the policy is on. It rejects `submitted`, and any non-Stripe change to `paid` or `issue`. Exception: in-flight legacy orders where the old status was `submitted` and `created_at < stripe_only_from`.
- **Exclusions and leftovers:**
  - `source='manual'` (merchant-entered) orders are excluded (D7).
  - `food-payment-qr`: the UI stops calling it. A 410 response and column privileges on `food_stores` are P1, because they are outside the allowlist.
  - Readiness functions are not redefined in this step.
- **Customer UI:**
  - Remove the QR, bank rows and slip UI.
  - Add two first-class options: "พร้อมเพย์ · ยืนยันอัตโนมัติ" (only when the store has PromptPay) and "บัตรเครดิต/เดบิต".
  - Show "ยังไม่เปิดรับ" on stores that are not ready, using the batch RPC `food_store_payment_options(uuid[])`.
  - Add refund states to orders.
- **`food-stripe-checkout`:** accepts an optional `method` (`promptpay` | `card`), validated server-side, and sets a single `payment_method_types` value (fixes G8). If a reused open session has a different method, it is expired and replaced.
- **Merchant UI:**
  - Hide manual confirm/paid/issue except on legacy orders.
  - Hide the PromptPay/bank/QR receiving form.
  - Add a not-ready banner and CTA.
  - Cancel text says the refund is automatic.
  - Add refund job state and a retry button.

## 4. Changes
**DB** (additive, on `main`):
- `supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql`:
  - Tables `food_stripe_jobs` and `food_payment_policy`, both with RLS and all grants revoked.
  - Internal trigger functions and triggers: `food_orders_payment_guard`, `food_orders_payment_jobs`, `food_orders_require_stripe_ready`.
  - Service-role RPCs: `food_claim_stripe_jobs`, `food_complete_stripe_job`, `food_refund_worker_cron_authorized`; a Vault secret; `internal.food_refund_worker_tick`.
  - `merchant_retry_stripe_refund` (checks `merchant_has_store_role`).
  - Boolean public RPCs: `food_payment_policy_public`, `food_store_payment_options`.
  - P1: `admin_food_refund_jobs`.
- `…100100_food_stripe_jobs_enable_cron.sql`
- `…100200_food_stripe_only_activate.sql`
- Rollbacks in `supabase/rollbacks/`.

**Edge functions:**
- New: `food-stripe-refund-worker`.
- Changed: `food-stripe-checkout`, `food-stripe-cancel` (both in the ZOKY allowlist).
- Unchanged: `stripe-webhook`, `merchant-stripe-refund`, `food-unpaid-timeout`.

**Web:**
- `web/lib/food-customer.ts`
- `wynos-food-developer-app.tsx`
- `web/lib/merchant-core.ts`
- Merchant components

**Tests:**
- `supabase/tests/food_stripe_auto_refund_test.sh` covers:
  - job creation and dedupe;
  - paid-after-cancel;
  - expire job;
  - manual orders untouched;
  - SKIP LOCKED;
  - authorisation;
  - policy on/off;
  - legacy confirm.
- Deno worker/checkout libs.
- Web unit and browser spec updates.
- Manual Stripe test-mode E2E.

**Security:**
- Refunds are created only by the service-role worker, for the full payment intent, on the paying account, behind a livemode guard.
- Merchant retry is authorised server-side and can only requeue.
- Webhook signature checks and dedupe are unchanged.
- The cron key is in Vault.
- New tables have RLS on and all grants revoked; the public RPCs return booleans only.
- Logs contain ids and codes only.

## 5. Release path (Founder change-control approval needed)
`zoky-web-exception-release.yml` allows only `web/*`, `docs/*`, `.wyn/*`, `config.toml` and 3 edge functions, and the freeze checker pins those functions. The exception expires on 2026-11-30. Migrations normally use per-feature `food-apply-*.yml` workflows on `main`, which run in the `production` environment with a typed confirm, `begin;…commit;` and a verify query.

- **B (recommended):**
  - A PR to `main` adds the migrations, `food-apply-zoky-stripe-jobs.yml` and the worker (plus a `deploy-edge-functions.yml` option).
  - The two Stripe functions and the web ship from the release branch via the exception EDGE/PHASE.
  - Never deploy `food-stripe-checkout`/`food-stripe-cancel` from `main`, because that would drop the ZOKY origins.
- **A:** extend the exception workflow and freeze checker. This means re-reviewing a security-reviewed workflow.
- **C:** merge ZOKY to `main` and lift the freeze. This is blocked on acceptance of #1142–#1151; it is the slowest option with the largest blast radius.
- **Rejected:** smuggling SQL or the worker through allowlisted paths.

## 6. Rollout / rollback (each step needs Founder approval)
| # | Step | Rollback |
|---|---|---|
| 0 | Read-only preflight: functiondefs, in-flight counts, pg_cron/pg_net, webhook event list, Stripe questions (D5, PromptPay expiry) | n/a |
| 1 | Deploy the worker without cron | Leave it idle |
| 2 | Apply the jobs migration (policy NULL) | Drop the triggers via the rollback file |
| 3 | Enable cron | `cron.unschedule` |
| 4 | Exception EDGE (checkout and cancel functions) | Revert on the release branch and re-run EDGE |
| 5 | Exception PHASE (web) | Vercel Instant Rollback |
| 6 | Watch for 24–48h; Stripe test → live smoke | — |
| 7 | Activate Stripe-only (D11: immediate) | `stripe_only_from = NULL` |

Effort is about 10–13 engineer-days, or about 2.5–3 calendar weeks with gates.

Open: D2 (refund fee), D5 (store balance too low to refund), duplicate-payment auto-refund, `food-payment-qr` returning 410, column privileges, the admin refund list, and the GP rate (currently 0%).
