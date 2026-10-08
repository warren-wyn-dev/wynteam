# WYNOS Finance QA Hardening — 2026-10-08

**QA-only target:** Supabase project `pcatuxtenluqzjzzwsvl` and GitHub branch `sandbox/stripe-testmode-20261008`. Never deploy to Production, call Stripe refund/payout/transfer APIs, configure default GP, alter checkout/webhooks, deploy Vercel or amend main.

## Defect actually reproduced and fixed

Before the guard change, an intentionally malformed finance projection (inserted with trusted QA SQL service privileges) referenced a store different from the linked paid PromptPay order. Calling `food_finance_append_refund_qa` with that projection returned `adjusted`, rather than rejecting the mismatched store. The test ran inside a transaction and **ROLLED BACK** all fixtures.

**Fix installed in QA:** `supabase/migrations_wynos_food_finance_refund_guard_sandbox_v2.sql` (migration `20261008154529`). This changes **only the QA refund simulation function**, adding fail-closed checks that:

- Order store and payment ledger store must match the immutable finance projection store.
- Order payment provider must remain Stripe, and its payment intent must match the projection.
- Payment order identifier must match the projection order.
- Projection payment method / charge model must remain `promptpay` / `direct_charge_connected_account`.
- Existing paid/refund eligibility checks, cumulative GP math, row locking, uniqueness, idempotency and immutable event ledger are preserved.

After the change, the same wrong-store fixture produces `payment_state_not_eligible` with no adjustment written. The original order and Stripe test-mode PromptPay payment remain paid.

## Tests actually executed after patch (all BEGIN/ROLLBACK, no SQL errors)

| Test file | Tested |
| --- | --- |
| `supabase/sandbox/gp/refunds_smoke.sql` | Existing partial/full, idempotency, immutable books, permission checks |
| `supabase/sandbox/gp/refunds_edge_smoke.sql` | Zero, negative, cross-key mismatch, half-up rounding, frozen GP, actual refund-state rejection |
| `supabase/sandbox/gp/finance_smoke.sql` | Existing snapshot/finance reconciliation regression |
| `supabase/sandbox/gp/finance_reporting_smoke.sql` | Admin/merchant totals and event pagination, cross-store permission checks |
| `supabase/sandbox/gp/finance_authz_role_smoke.sql` | PostgreSQL `anon` / `authenticated` role switching, transaction-local simulated claim subject; allowlisted admin, owner, non-owner; denies privileged mutation and direct tables |
| `supabase/sandbox/gp/refunds_cross_store_guard_smoke.sql` | Reproduced malformed cross-store projection now safely rejected |

**Important distinction:** Role tests mimic PostgREST DB role/claim context using `SET LOCAL ROLE` and `request.jwt.claim.sub`, but **do not validate actual signed JWT or HTTP access**. No QA signed user tokens/credentials were available for HTTP testing, and direct network DNS from the tool container was unavailable.

## Concurrency test status: NOT VERIFIED

The refund function uses `SELECT ... FOR UPDATE` on the immutable Finance projection and UNIQUE constraints on `(order_id,simulation_key)` and `(order_id,sequence_number)` as code/DB invariants.

A best-effort simultaneous two-session lock-contestion probe against an existing QA order did not observe contention; a separate advisory-lock probe also did not establish overlapping sessions. **Do not treat this as passing concurrent double-refund testing.** Rollback-only test projections created in session A cannot be seen by session B; meanwhile, committed projections currently count zero. Under the strict no-permanent-finance-test-data constraint, there is no shared committed projection fixture for a genuine double-refund race. A controlled test harness with verifiably independent overlapping DB sessions and a fixture lifetime policy is still required before claiming concurrency QA is complete.

## Security Advisor results after patch

- `rls_enabled_no_policy`: informational findings include finance/GP tables; this is an intentional **deny-by-default** design coupled with no client table grants.
- `authenticated_security_definer_function_executable`: finance/admin/merchant public wrappers are flagged. They have explicit independent owner/QA admin allowlist checks and were tested with simulated PostgreSQL roles. The warning is **not dismissed**; production design should consider moving privileged internals to a private schema and review API exposure.
- QA Auth leaked-password protection disabled; separate Auth project setting, not changed under this Finance-only task.
- Performance lints (including nonfinance issues) require separate triage before launch.

## Verified clean QA state after rollback

- Configured GP rates: `0`
- GP order snapshots: `0`
- Finance projections: `0`
- Simulated refund adjustments and lines: `0`
- QA finance allowlist: `0`
- Actual GP collected in QA projection records: `0 satang`
- WF000005: `payment_status=paid`, `refund_status=none`, Stripe payment `paid`, `promptpay`, `livemode=false`
- No actual Stripe refund/payout, no Vercel deployment, no changes to main/Production.

## Work remaining

1. Signed-JWT HTTP end-to-end authorization tests with consented QA test accounts and network-capable client.
2. True concurrent two-connection refund/idempotency tests on a safely isolated, visible projection fixture, with verified clean teardown and no real money.
3. Review `SECURITY DEFINER` API surface with Security Advisor and confirm the approved merchant finance-role scope before public UI release.
4. After those pass, progress to Finance Reporting v2. No actual GP, Stripe settlement, payouts or production deployments are authorized.
