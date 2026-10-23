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

Round 1 status: FAIL → AI Debug Engineer, with ZOKY-147 to ZOKY-152. (See Re-test 2 below for the current status.)

---

## Re-test 2 (2026-10-23)

Environment:
- payjobs feat/zoky-stripe-jobs-db @ 99c74881
- payweb feat/zoky-stripe-only-web @ 7d40229e
- New Founder decision 2026-10-23: customers pay only by PromptPay QR through Stripe; stores without PromptPay are not accepting orders.
- Throwaway PG16 (removed afterwards), synthetic data, mocked Supabase/Stripe.

### Developer suites (re-run by me)
| Suite | Result |
|---|---|
| SQL `food_stripe_auto_refund_test.sh` | 140/140 PASS |
| deno backend (`--allow-read`) | 141/141 PASS; `deno check` worker + merchant-stripe-refund pass |
| deno web (checkout/cancel) | 16/16 PASS; `deno check` passes |
| eslint (changed files) / `tsc --noEmit` | 0 / 0 |
| node `tests/*.test.mjs` | 367/367 PASS |
| Playwright (food preview + merchant, chromium-android, temporary config, removed) | 68/68 PASS |
| probe.mjs (customer) | 30/30 PASS |
| probe-merchant.mjs | 15/15 PASS |

### My round-1 attack scripts (expected flips)
- **t1 authz:** 31/31. **t2 flows:** 37/37. **t4 parity:** policy-OFF diff is still only the audit event `refund_auto_queued`.
- **t3 policy ON** (both live variants of `food_set_payment_status`):
  - All 3 "BYPASS?" lines for `source='social'` are now refused (ZOKY-151 fixed).
  - A card-only store is refused, as the new Founder rule requires; that old D9 expectation is now intentionally reversed.
  - `food_set_payment_status('refunded')` on a Stripe-paid order is refused in the core_completion variant too (`stripe_payment_managed_by_stripe`; ZOKY-150 fixed).
- **t5 PromptPay:** all "BUG" lines flipped:
  - After a premature `charge.refunded` and a later failed refund, the order ends `cancelled/paid/failed`.
  - Customer and merchant are notified with the reason (no bank account entered in Stripe's email).
  - The GP fee is no longer booked at request time.
  - The merchant can retry.
  - needs_attention now notifies the merchant, and `admin_food_refund_jobs` exists.
  - SKIP LOCKED is still OK.
- **`promptpay_refund_test.ts`:** the worker now polls its own refund even when the order is flagged refunded, and reports `failed` (ZOKY-147 fixed).

### New attacks (t6_round2.sh, 31 real checks pass; 4 harness-format mismatches "true" vs "t" have correct states)
**Guard on auth.role (ZOKY-150)**
- authenticated or anon, even through a SECURITY DEFINER RPC, cannot mark a Stripe-paid order refunded or swap its provider.
- service_role (webhook/worker) can.
- Merchant accept/cancel and `merchant_retry_stripe_refund` still work.
- role NULL (pg_cron/operator SQL) is allowed by design.
- Stripe orders still `pending`/`issue` are not covered (legacy; live-version dependent).

**refund_awaiting_customer flips**
- `requires_action` sets the flag and notifies the customer once ("ตรวจอีเมลจาก Stripe…"); repeat polls do not resend.
- A failure clears the flag and tells both sides why; a retry clears it.
- Clients have no write path (no UPDATE grant).

**Webhook-sets-refunded → worker-reverts loop**
- The state is always corrected (`cancelled/paid/pending`), and no second refund job is created.
- **But each revert to `paid` fires the existing `food_order_notify` trigger**: the buyer gets "ชำระเงินออเดอร์ #X สำเร็จแล้ว", and the merchant and staff get "ชำระเงินแล้ว #X". → **ZOKY-153 (MEDIUM, new)**

**admin_food_refund_jobs**
- anon gets permission denied; merchant and buyer get `Not authorized`.
- A food:view admin can list.
- The status filter is validated (an injection string is rejected).
- Returns ids, codes and counters plus order number and store name; no customer personal data.

**Backfill (opt-in)**
- A rerun is idempotent (same dedupe key; one event per order).
- Orders with existing jobs are skipped.
- Rollback removes only jobs not picked up yet.

**Activate / deactivate**
- An activate rerun keeps the cut-over time.
- Deactivate brings back legacy behaviour: the unready store accepts orders and slips are accepted.
- Workflow steps preflight/backfill/deactivate/cron-off parse, are main-only, require the typed confirm and the `production` environment, and are verified.
- Preflight is read-only and prints function definitions and counts only.

**Checkout** (unit tests + code review)
- Under the policy, `card` → 422 `promptpay_only`; no method → PromptPay.
- A policy RPC error other than "function missing" → 503 `payment_policy_unavailable` (fail-closed).
- `promptpay` skips the policy read and is still gated by `promptpay_enabled`.
- An open card session from before activation is expired and replaced by a PromptPay session.

**UI** (probes + review)
- A single "จ่ายด้วยพร้อมเพย์ (QR)" option with the payee note "STRIPE PAYMENTS (THAILAND)" (`aria-describedby`).
- Refund states for the customer (pending/awaiting email/failed with reason).
- Merchant: one owner of refunds — the automatic box whenever a job exists, in any policy state; the legacy button only for old orders without a job.
- `manualPaymentAllowed` only when `source==='manual'`.
- Error codes are mapped to Thai.

### Bug status after Re-test 2
| ID | Status |
|---|---|
| ZOKY-147 HIGH | Fixed, verified (side effect → ZOKY-153) |
| ZOKY-148 MEDIUM | Fixed, verified. LOW residual: the customer view of a parked (needs_attention) refund still shows "กำลังคืนเงิน · ตรวจอีเมลจาก Stripe". `FOOD_REFUND_NEEDS_ATTENTION_COPY` exists but is only used on the merchant side |
| ZOKY-149 MEDIUM | Fixed, verified |
| ZOKY-150 MEDIUM | Fixed, verified (both live variants) |
| ZOKY-151 LOW | Fixed, verified |
| ZOKY-152 LOW | Still open. `internal.food_order_status_notify` still says "ร้านจะคืนเงินให้คุณ"; acceptable to defer with a CTO/PM decision |
| **ZOKY-153 MEDIUM (new)** | Open. A refund revert sends "ชำระเงิน…สำเร็จแล้ว" / "ชำระเงินแล้ว" notifications on the main PromptPay refund path |

### Open items judged
- **Team name:**
  - DB uses "ทีม WYNOS": `food_stripe_job_attention` merchant notification and event; `retryStripeRefund` PGRST202 copy.
  - Merchant web uses "ทีม ZOKY".
  - Inconsistent (LOW). Merchant-facing text sits under "WYNOS Merchant", so pick one with PM/Founder; I recommend "ทีม ZOKY" for customer-facing text and one term for merchant-facing text.
- **Customer view for needs_attention:** LOW. Not money-affecting, because the merchant is told and the admin list exists, but the customer copy is misleading. Recommend `foodRefundNotice` uses the order's `refund_needs_attention` event and shows "การคืนเงินต้องตรวจสอบ ติดต่อทีม ZOKY".
- **ZOKY-152:** LOW, defer acceptable.
- **Backfill (LOW recommendation):** for Stripe orders, merchants could never record an off-Stripe refund (`merchant_set_refund_status` refuses Stripe). A merchant who refunded in cash would be refunded again by the backfill. Before running `backfill`, review the candidate list (age, store) with the merchants; the preflight gives only a count.

### Still not testable here
Same as round 1:
- real Stripe test mode, in particular PromptPay refund `requires_action` → succeeded/failed, whether `charge.refunded` arrives before the refund succeeds, Stripe's refund email, and the ฿10 PromptPay refund fee;
- pg_cron/pg_net/Vault;
- production live function versions (the preflight step now covers this);
- HTTP-level edge function `index.ts`;
- WebKit/desktop Playwright projects.

### Recommendation
- Fix ZOKY-153: preferred option C (the webhook does not treat `charge.refunded` as final), or a revert flag honoured by the notify function. This needs a CTO call on the allowlist.
- Fix or accept the LOW items (ZOKY-148 customer copy, team name, ZOKY-152).
- Then a short re-test and a Stripe test-mode E2E for PromptPay refunds before Founder Gate.
- Everything else in the money path (refund correctness, double-refund protection, authz, Stripe-only/PromptPay-only enforcement, policy-OFF parity, rollback paths) passed.

Re-test 2 status: FAIL
→ AI Debug Engineer, with ZOKY-153 (MEDIUM, a regression introduced by the ZOKY-147 fix on the main PromptPay refund path) plus the LOW items above. The Founder/CTO may instead explicitly accept ZOKY-153 as a documented risk; if they do, nothing else blocks the QA gate.

---

## Re-test 3 (2026-10-23, focused on ZOKY-153)

Environment:
- payjobs feat/zoky-stripe-jobs-db @ 869e1705:
  - `stripe-webhook` now maps `charge.refunded` to noop;
  - it marks refunded only on `refund.created`, `refund.updated` or `charge.refund.updated` with status `succeeded` and the full amount (new `_lib.ts` plus tests);
  - the worker revert stays as a safety net;
  - the team name is now "ทีม ZOKY".
- payweb code is unchanged since 7d40229e (docs only).
- Throwaway PG16, removed afterwards.

### Results
| Suite | Result |
|---|---|
| Developer SQL `food_stripe_auto_refund_test.sh` | 140/140 PASS |
| deno backend (`--allow-read`) | 144/144 PASS; `deno check` stripe-webhook + worker pass |
| Developer `dbg/t153.sh` | 7/7 PASS |
| t1 authz / t2 flows | 31/31, 37/37 |
| t3 policy ON (both live variants) | Same intended flips as Re-test 2 (social refused, card-only store refused, Stripe→refunded refused) |
| t4 policy-OFF parity | Unchanged: only the audit event `refund_auto_queued` differs |
| t5 PromptPay (still simulates the old `charge.refunded`→refunded mapping, so it exercises the safety net) | Same flips as Re-test 2: a failed refund ends `paid/failed` with notifications |
| t6 (harness fixed to expect true/false; `charge.refunded` simulated as noop; new no-job/refund.* section) | 43/43 PASS |
| `promptpay_refund_test.ts` | The worker polls and reports `failed` (fixed) |

### What was checked
**ZOKY-153**
- Three `charge.refunded` events while a PromptPay refund waits → the order stays `cancelled/paid/pending/awaiting=true`.
- The buyer's "ชำระเงิน…สำเร็จแล้ว" count stays 1 → 1 (was 1 → 4 in Re-test 2).
- `refund.updated succeeded` arrives before the worker → order refunded; the worker poll then sees succeeded → done.
- The customer gets "คืนเงินออเดอร์…แล้ว" exactly once, with no spurious payment notification.

**Webhook diff review**
- `orderId` for Refund objects is resolved through `metadata.wynos_order_id` (set by both the worker and merchant-stripe-refund) or `payment_intent` → `food_stripe_payments`.
- Amount check: only a full succeeded refund counts. Partial, unknown total, `pending`, `requires_action` and `failed` → noop.
- `refund.failed` is recorded only.
- Non-refund events are unchanged; the code is a pure extraction into `_lib.ts`.
- The release branch's `stripe-webhook` equals main before this change, and the ZOKY exception workflow does not deploy `stripe-webhook`. So it ships only from main through `deploy-edge-functions.yml`, and nothing overwrites it with the old version.

### Regression analysis (the coordinator's questions)
**Slip / manual flows: no change.**
- Refunds of non-Stripe orders go through `merchant_set_refund_status` / `food_set_payment_status`.
- They never depend on the webhook.

**Orders with an automatic refund job: no webhook dependency.**
- The worker polls its own refund to `succeeded` and writes `refunded` itself.
- This covers every Stripe order cancelled after the `jobs` step.

**Orders without a job — the only path that changes:**
- The merchant legacy button on older orders (under the policy it is kept for orders with no job; CTO C3).
- A refund from the Stripe Dashboard.
- Backfilled orders become job orders, so they are covered.

For these orders:
- They reach `refunded` only through `refund.created`, `refund.updated` or `charge.refund.updated` with `succeeded`. Verified in t6: a no-job order + `refund.updated succeeded` → `cancelled/refunded/refunded`, and no job is created.
- `merchant-stripe-refund` itself writes only `refund_status='pending'` + `stripe_refund_id`. The final state always came from the webhook.
- Before this change, `charge.refunded` alone was enough.

**If the production endpoint is NOT subscribed to `refund.*` (only `charge.refunded`):**
- No-job orders refunded by the legacy button or the Dashboard stay `refund_status='pending'` forever.
- The customer keeps seeing "กำลังคืนเงิน", and the merchant sees a pending refund.
- The money is still refunded; only the status is wrong.
- This is a regression vs today (MEDIUM, operational). If the endpoint is subscribed, nothing changes, because the `refund.*` mapping already existed before this change.

### Required preflight (read-only) and deploy order
**1. Webhook event evidence (SQL, counts only).** The webhook records every event in `food_stripe_webhook_events` before it processes it:

```sql
select event_type, count(*) as events, max(received_at) as last_received
from public.food_stripe_webhook_events
where event_type in ('charge.refunded','refund.created','refund.updated','refund.failed','charge.refund.updated')
group by event_type order by event_type;
```

- **Pass:** at least one of `refund.created` / `refund.updated` / `charge.refund.updated` has been received since `charge.refunded` started appearing.
- **No rows at all:** inconclusive. Go by the Stripe Dashboard check.
- **Only `charge.refunded`:** the endpoint is not subscribed to `refund.*`. The Founder must add those events first.

**2. Stripe Dashboard (Founder, read-only check).**
- Location: Developers → Webhooks → the Connect ("events on connected accounts") endpoint that points to `/functions/v1/stripe-webhook`.
- Its event list must include `refund.created`, `refund.updated`, `refund.failed` and `charge.refund.updated`.
- Keep `charge.refunded`; it is harmless.
- Also confirm the endpoint API version sends Refund objects for these events.

**3. Legacy in-flight count, to watch after deploy:**

```sql
select count(*) from public.food_orders o
where o.payment_provider='stripe' and o.refund_status='pending' and o.stripe_refund_id is not null
  and (to_regclass('public.food_stripe_jobs') is null or not exists
       (select 1 from public.food_stripe_jobs j where j.order_id=o.id and j.kind='refund'));
```

The number should fall as the `refund.*` events arrive.

Recommend adding checks 1 and 3 to the `preflight` step of `food-apply-zoky-stripe-jobs.yml`.

**Deploy order (each step Founder-gated):**
0. preflight: function definitions + checks 1–3 + the Dashboard event list confirmed.
1. Deploy `stripe-webhook` from main (`deploy-edge-functions.yml`, option `stripe-webhook`). Then verify in Stripe test mode: a refund in pending → succeeded marks the order refunded only on succeeded, and `charge.refunded` is noop.
2. Deploy `food-stripe-refund-worker`.
3. `jobs`.
4. `cron`. Must come after step 1, as the migration header says, so the safety-net revert is not hit by old `charge.refunded` handling.
5. ZOKY EDGE/PHASE.
6. Watch 24–48 h.
7. `activate`.

`backfill` is optional, after `cron`, once the candidates have been reviewed with the merchants (Re-test 2 note).

### Bug status after Re-test 3
| ID | Status |
|---|---|
| ZOKY-147, 148, 149, 150, 151 | Fixed, verified (Re-test 2), no regression in Re-test 3 |
| ZOKY-153 MEDIUM | **Fixed, verified**. Condition: preflight checks 1–2 above |
| ZOKY-152 LOW | Open, deferrable (`internal.food_order_status_notify` text) |
| ZOKY-148 residual LOW | Customer view of a parked refund still shows the "ตรวจอีเมลจาก Stripe" copy |
| Team name | Fixed on the DB side ("ทีม ZOKY"). The web `retryStripeRefund` PGRST202 copy still says "ทีม WYNOS" (LOW) |

### Still not testable here
- Real Stripe test mode: refund event ordering and the event subscription itself; PromptPay refund email/`requires_action`; the ฿10 PromptPay refund fee.
- pg_cron, pg_net and Vault.
- HTTP-level edge functions.
- WebKit/desktop Playwright.
- A Stripe test-mode E2E is still required at the Staging/Founder gate.

## Final Status: PASS

The QA & Security gate for the code passed, with no CRITICAL, HIGH or MEDIUM issue open. Conditions carried into the rollout, each Founder-gated:
- (a) Run preflight checks 1–2 and confirm the `refund.*` webhook subscription before deploying `stripe-webhook`.
- (b) Follow the deploy order above, with `stripe-webhook` deployed before `cron`.
- (c) Pass the Stripe test-mode E2E for PromptPay refunds before Founder Gate.

Open LOW items (ZOKY-152, ZOKY-148 customer copy, one "ทีม WYNOS" string, backfill review) can follow.
→ CTO final review, then AI Deploy & DevOps.
