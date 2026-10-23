# QA & Security — ZOKY Stripe-only payments + automatic refund

Feature: ZOKY Stripe-only payments (PromptPay/card through Stripe), automatic expire-on-cancel and automatic full refund (design `.wyn/docs/architecture/zoky-stripe-only-auto-refund-design.md`, Founder decisions 2026-10-22)

Environment:
- Backend: `/home/user/wynteam-payjobs` feat/zoky-stripe-jobs-db @ e9ed4f68 (`origin/main..HEAD`: migrations 20261023100000/100100/100200 + rollbacks, food-stripe-refund-worker, food-apply-zoky-stripe-jobs.yml, deploy-edge-functions.yml option + ZOKY block, config.toml)
- Web + edge: `/home/user/wynteam-payweb` feat/zoky-stripe-only-web @ 5ab75457 (`origin/release/zoky-web-20261018..HEAD`)
- My own throwaway PostgreSQL 16 cluster (`/var/lib/postgresql/qa_zoky_tmp`, since the scratchpad's parent directory is reset to mode 700 and the postgres user cannot read it). It has been removed.
- Deno 2.9.6; Node 22; Chromium 1194 (Pixel 5 profile); Next dev server with Supabase fully mocked (`https://sb-mock.test`)
- Synthetic data only. No real Stripe, no real Supabase, no env/secret files read, nothing committed or pushed.

## Test Cases and results

### 1. Re-running the developers' tests (all re-run by me)
| Suite | Result |
|---|---|
| `supabase/tests/food_stripe_auto_refund_test.sh` (stub schema) | 88/88 PASS |
| deno `supabase/functions/` on payjobs (`--allow-read`) | 134/134 PASS; `deno check` of the worker passes |
| deno food-stripe-checkout/-cancel on payweb | 14/14 PASS; `deno check` passes |
| web eslint (changed files) + `tsc --noEmit` | exit 0 / exit 0 |
| web `node --test tests/*.test.mjs` | 363/363 PASS |
| Playwright `wynos-food-developer-preview` + `wynos-merchant` (chromium-android, temporary config) | 68/68 PASS |
| Developer UI probe `payprobe/probe.mjs` (mocked Supabase) | 22/22 PASS |

### 2. My own harness: the existing RPC bodies + the migration
The developers' SQL test uses stubs. I loaded the actual function bodies from the repo into a scratch DB:
- `food_apply_stripe_event`, `food_submit_payment`, `merchant_set_refund_status`;
- both versions of `food_set_payment_status` (stripe_payment_core and merchant_core_completion);
- `food_transition_order`, `food_create_manual_order`, `food_cancel_order` (access_gate_v2);
- `food_timeout_cancel` + `food_guard_late_slip`;
- the existing notify triggers.

Then I applied 20261023100000. Scripts are in `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/qa/sql/`.

| Script | Scope | Result |
|---|---|---|
| t1_authz.sh | RLS/grants, SECURITY DEFINER search_path, public RPCs, merchant retry authz | 31/31 PASS |
| t2_flows.sh | Policy OFF flows on the existing RPCs and the worker RPC lifecycle | 37/37 PASS |
| t3_policy_on.sh (stripe_payment_core variant) | Order gate, slip/manual block, in-flight legacy slips, bypass attempts | 25/25 as expected; 3 "BYPASS?" lines confirmed → ZOKY-151 |
| t3_policy_on.sh (core_completion variant) | Same | Stripe order can be set to refunded → ZOKY-150 |
| t4_parity.sh | Same policy-OFF legacy scenario run with and without the migration, then diffed | Orders, notifications and payments identical; the only extra row is an audit `refund_auto_queued` event (intended Step 1) |
| t5_promptpay.sh | PromptPay refund timeline, needs_attention, concurrent SKIP LOCKED claim | Bugs confirmed → ZOKY-147, ZOKY-148; SKIP LOCKED OK |
| `deno/promptpay_refund_test.ts` (mocked fetch) | Worker closes an awaiting PromptPay refund as "refunded" without calling Stripe | Bug confirmed → ZOKY-147 |

### What I checked and found working
**Authorization and grants**
- anon and authenticated have no SELECT/INSERT/UPDATE on `food_stripe_jobs` or `food_payment_policy`, even with Supabase-like default privileges.
- RLS is on for both tables.
- claim, complete and cron-key probe are refused for clients.
- internal functions are not executable by clients.
- Every new SECURITY DEFINER function uses `search_path=''`.

**Merchant retry**
- anon is refused, another merchant and the buyer get `order management role required`, and a queued job cannot be double-run (`no_failed_refund`).
- A retry resets attempts and bumps `requeue_count`, so it gets a new idempotency key.

**Triggers against the existing RPCs**
- Customer cancel, merchant cancel of an unpaid order (G2) and the timeout cancel each queue an `expire_checkout` job.
- A webhook payment on a cancelled order stays cancelled, is marked refund pending and is refunded automatically, and the customer is notified. A replayed or duplicate event still gives one job.
- Store cancel of a Stripe-paid order at any stage gives one refund job.
- Manual orders (D7) and slip-paid orders get no Stripe jobs.

**Policy ON**
- The order gate refuses unready stores and stores whose Stripe was switched off. Card-only stores are accepted (D9). Manual orders are allowed.
- Slip submission is refused on all `app` orders.
- Merchant manual paid/issue is refused, but legacy slips submitted before the cut-over can still be confirmed or rejected.
- The webhook still marks orders paid, and store cancel still queues an auto refund.

**Policy OFF parity**
- The DB side is identical; see t4.
- Customer UI: legacy slip, bank rows and the card button appear, and store options are never requested (probe).
- Merchant UI: the legacy branches are unchanged (`manualPaymentAllowed` is true when the policy is off).
- If the RPCs are missing, the UI falls back to legacy.

**Worker**
- List-before-create, an idempotency key per job and requeue, no `amount` (always a full refund), the paying account through `Stripe-Account`, and a livemode guard.
- A double refund is not possible even when the legacy button races the worker, because Stripe caps a payment at its full amount.

**Checkout edge function**
- `method` is strictly validated: only `promptpay`/`card`; anything else gets 400 `invalid_payment_method`.
- The amount comes from the DB.
- The live-mode origin allowlist is unchanged.
- `expires_at` is 31–32 minutes away.
- When the customer switches method, the old session is expired before a new one is created; a 409 is returned if it was paid meanwhile.
- PromptPay is refused when the account does not have it.

**Cancel UX**
- A 409 `stripe_payment_already_completed` shows "ชำระเงินแล้ว ยกเลิกไม่ได้ ติดต่อร้าน", and `food_cancel_order` is not called (probe).

**Customer UI and accessibility**
- PromptPay is hidden when it is unavailable (probe).
- Payment options are 61.9px tall (≥44px), the option group has `role=group` with a label, loading and refund notices use `role=status`, and store rows have Thai aria-labels.

**CI**
- e9ed4f68: `deploy-edge-functions.yml` now fails closed before deploy for `food-stripe-checkout`/`food-stripe-cancel`. The YAML parses.
- The apply workflow is main-only, needs a typed confirm and the `production` environment, has preconditions and verify queries, and `jobs` keeps the policy OFF.

## Failed / Findings

| ID | Severity | Summary |
|---|---|---|
| ZOKY-147 | **HIGH** | A PromptPay refund (Stripe emails the customer for a bank account number) can stay `requires_action` and then fail. Meanwhile: (1) the worker stops polling as soon as the order is flagged refunded; (2) `charge.refunded` from the webhook can flag the order refunded before the money moves (needs Stripe test-mode confirmation); (3) `food_stripe_job_fail` ignores orders that are not `paid`, so there is no failure state and no notification; (4) the UI never tells the customer to check Stripe's email, and the merchant failure copy only mentions the Stripe balance; (5) the GP fee is booked as returned at request time. Result: the order can show "คืนเงินแล้ว" while the refund failed. |
| ZOKY-148 | MEDIUM | `needs_attention` refund jobs are silent: no notification, no admin list, no retry. The UI says "กำลังคืนเงิน" and the merchant is told "ไม่ต้องกดคืนเงินเอง". |
| ZOKY-149 | MEDIUM | While cron is on but the policy is OFF, the legacy "คืนเงินผ่าน Stripe" button races the worker. `merchant-stripe-refund` writes `refund_status='failed'` when Stripe answers `charge_already_refunded`, so customer and merchant see a false failure. There is no double refund. |
| ZOKY-150 | MEDIUM (conditional) | If the live `food_set_payment_status` is the core_completion version, a merchant can set a Stripe-paid order to `refunded` without any Stripe refund; the guard does not cover this. Preflight `pg_get_functiondef` is not in the apply workflow. |
| ZOKY-151 | LOW | `source='social'` is not gated: order gate, slip block and manual paid all pass. Not reachable by clients today. |
| ZOKY-152 | LOW | Thai copy: the existing store-cancel notification says "ร้านจะคืนเงินให้คุณ", but the refund is automatic, and PromptPay also needs the email reply. |

Bug reports: `/home/user/wynteam-payweb/.wyn/tasks/bugs/ZOKY-147-…` to `ZOKY-152-…`.

Other LOW observations (no separate bug):
- A duplicate payment on an already cancelled order is parked with the old PI. The second PI is never refunded, and the order is set to refunded once the first refund completes.
- Two checkout requests from two tabs straddling a minute boundary or choosing different methods can open two sessions. Only one is tracked. If the untracked one is paid on a cancelled order it is still auto-refunded; on a live order it becomes a parked duplicate.
- The GET-failure path in checkout opens a new session without expiring the old one (existing behaviour).
- Merchant requeue has no cap (only `requeue_count` is recorded).
- The timeout path queues a redundant expire job (harmless).
- The customer refund notice also appears with the policy OFF. This is intended, but it is a UI change before activation.
- Stripe docs: re-scanning a used PromptPay QR can move excess funds to the store balance, and those must be refunded outside Stripe. This is not handled; it is an operations topic.

## Security Findings
- No CRITICAL.
- No secret exposure in the diff: the worker logs only ids and codes, and the cron key is in Vault.
- The grant/RLS/authz checks above all hold.
- ZOKY-150 is an integrity gap that a malicious merchant can trigger, depending on the live function version.
- ZOKY-151 is a deny-by-default gap.

## Not testable here
- Real Stripe test mode:
  - refund statuses (`requires_action`/`pending`/`failed`) for PromptPay, and the email flow;
  - whether `charge.amount_refunded` includes pending refunds (deciding for ZOKY-147 point 2);
  - expiring a session that has completed but is unpaid (PromptPay);
  - Stripe's exact error code when a pending full refund exists;
  - idempotency-key behaviour;
  - `refund_application_fee`.
- pg_cron, pg_net and Supabase Vault (stubbed); `internal.food_refund_worker_tick` only against the stubs.
- Which version of the duplicated legacy RPCs is live in production (ZOKY-150 depends on it).
- HTTP behaviour of the edge function `index.ts` files: I reviewed the code and ran the lib unit tests only.
- Merchant UI under policy ON in a browser: covered by the source-level spec and code review only.
- WebKit/iPhone and desktop Playwright projects: only chromium-android was run.

## Recommendation
- Fix ZOKY-147 before the cron step (step 3). Automatic refunds are live from that point regardless of the policy, and PromptPay is the main method.
- Fix ZOKY-148, ZOKY-149 and ZOKY-150 (plus the preflight) before activation (step 7).
- ZOKY-151 and ZOKY-152 can be fixed in the same pass.
- A Stripe test-mode E2E for PromptPay and card refunds (succeeded / requires_action → failed) is required before Founder Gate.

Final Status: FAIL
→ AI Debug Engineer, with ZOKY-147 to ZOKY-152.
