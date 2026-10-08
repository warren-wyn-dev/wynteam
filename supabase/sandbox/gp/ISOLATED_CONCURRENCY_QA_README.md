# WYNOS Finance — zero-new-Supabase-project isolated concurrency QA

**Date:** 2026-10-08

## Why a new Supabase project was NOT created

The actual Supabase organization `wyn-dev` (`ttyuzfbqrpralxnljysq`) is on the **Free** plan and already has two ACTIVE_HEALTHY projects. The provider reports new-project creation cost `0 / month`, but the Free plan only allows two simultaneously active projects across the account and Supabase Branching is not included on Free. A paid preview branch would cost `$0.01344 per hour` (provider-specific quote). No upgrade, billed branch, new Supabase project, existing project pause, or use of any unrelated inactive WYNOS project was authorized or performed.

## Implemented alternative — fully ephemeral, independent Postgres service

The sandbox GitHub Actions workflow `.github/workflows/wynos-finance-qa-isolated.yml` provisions a **fresh disposable PostgreSQL 17 service container on GitHub Actions**. It is NOT any Supabase database. It loads exact WYNOS QA refund math and `food_finance_append_refund_qa` implementations and their real original immutable ledger **table definitions** from these already-existing branch files:

- `supabase/migrations_wynos_food_gp_engine_sandbox_v1.sql`
- `supabase/migrations_wynos_food_finance_sandbox_v1.sql`
- `supabase/migrations_wynos_food_finance_refunds_sandbox_v1.sql`
- `supabase/migrations_wynos_food_finance_refund_guard_sandbox_v2.sql`

Minimal fake `food_orders`, `food_stores`, `food_stripe_payments` dependencies simulate the relevant paid Test Mode PromptPay state. No real Stripe credentials, network API, actual order or real money is involved. The CI service is destroyed after the job. Because this database is fully disposable, its concurrent sessions may `COMMIT` solely to expose state to each other, unlike the strict ROLLBACK-only requirements of the existing shared Supabase QA project. All user production and existing QA data are untouched.

Run only from **GitHub branch** `sandbox/stripe-testmode-20261008`, on changes affecting test sources/workflow, or manually from Actions if the workflow is available. The job has `contents: read` permission and no deploy, Production or Stripe steps.

## Actual concurrent scenarios covered by the new Node runner

`supabase/sandbox/gp/isolated_refund_concurrency.mjs` invokes `psql` on a new session for each request:

1. **Same-key double request**: Session A holds the real Finance projection `FOR UPDATE` lock; Session B requests the same simulation key and waits. Exactly one insert; Session B must return `already_adjusted`.
2. **Concurrent over-refund**: Session A applies a 3333-satang food refund, while waiting Session B requests a further 3333 satang on 5000 satang basis. The second request must error without creating an adjustment.
3. **Distinct complementary refunds**: 3333 + 1667 satang produce exactly two adjustments and cumulative half-up GP reversal 375 satang.
4. **Same key, conflicting payload**: Second request with different amount must fail the replay check.
5. **10 simultaneous clients using one key**: Exactly one adjustment and nine idempotent replays.

Every scenario checks database event counts, financial amounts, balanced reversal lines, and that actual-refund fields remain zero and fake payment status is unchanged.

**Limits:** This is real multiconnection PostgreSQL execution of the exact QA functions using minimal *structural dependency stubs*. It is not a full Supabase Auth/PostgREST/Stripe E2E test and does not apply migrations to the existing QA server. The workflow and runner have been committed and JS syntax-checked but do not claim a full concurrency **PASS** unless a completed successful GitHub Actions run log is available.

## QA machine local run

Use an isolated, freshly created local PostgreSQL 17 database named `wynos_refund_isolated` with only nonproduction fake credentials. Set `PGHOST=127.0.0.1`, `PGPORT=5432`, `PGUSER`, `PGPASSWORD`, `PGDATABASE=wynos_refund_isolated`, `WYNOS_ISOLATED_PG_ACK=wynos_refund_isolated`, then run:

```bash
node supabase/sandbox/gp/isolated_refund_concurrency.mjs
```

This runner actively refuses remote PostgreSQL hosts, unknown target DB names, and network/service override variables. Do not repurpose it to any real WYNOS data server.

## Remaining signed-JWT requirement

`finance_http_signed_jwt_qa.mjs` is a separately prepared HTTP-only test for **real signed Supabase Auth user JWTs** (owner, unrelated user, optional allowlisted QA admin) and QA publishable/anon key. These cannot be replaced with fake claims from a SQL Session. Use a legitimate QA-only credential source on a network-capable runner. The HTTP test was **not** executed here because no authorized short-lived QA JWTs or direct QA network reachability were available. No JWTs or secrets must be committed or pasted into chat.

## Stop conditions

- Do not create/upgrade/bill a Supabase project or preview branch without explicit user approval after showing its actual cost.
- Do not pause existing WYNOS projects to reclaim a Free-plan slot.
- Do not merge this sandbox GitHub branch to main, change Production Supabase, issue real Stripe refund/transfer/payout, collect real GP, or deploy Vercel.
- Phase 1 is not fully closed until signed-JWT HTTP verification and concurrency CI run results are confirmed.
