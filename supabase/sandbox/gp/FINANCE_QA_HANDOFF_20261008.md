# WYNOS Food Finance — QA Implementation & Handoff (2026-10-08)

**Branch**: `sandbox/stripe-testmode-20261008` in `warren-wyn-dev/wynteam`.
**Supabase QA**: `pcatuxtenluqzjzzwsvl` ONLY. Production Supabase, Stripe live funds, real GP/refunds, main and Vercel deployment are untouched.

## Completed today

- Implemented and installed read-only Finance Reporting **v2** SQL RPC migration `supabase/migrations_wynos_food_finance_reporting_v2_sandbox.sql`; corrected actual PostgreSQL `COALESCE` runtime error via follow-up additive migration `supabase/migrations_wynos_food_finance_reporting_v2_coalesce_fix_sandbox.sql` (QA migration versions `20261008161929`, `20261008162035`).
- Admin/owner-gated daily and monthly `Asia/Bangkok` time buckets; independent creation dates for projections and refunds; zero-event periods explicitly show zero values; max 366 days and validated granularity.
- Admin/owner-gated per-order projected food GP and simulated refund history. Stripe processing fee and net merchant payout remain **unknown/null**. Privileged read cores are `SECURITY INVOKER` in nonexposed `wynos_finance_qa_private`; direct `anon`/`authenticated` access denied. Public authenticated wrappers require QA admin allowlist or actual active merchant store owner.
- Added `finance_reporting_v2_smoke.sql` and `finance_reporting_v2_roles_smoke.sql` with rollback-only fixtures. **All 9/9 Finance SQL regression scripts executed without SQL errors** in QA after the v2 migration and correction.
- Extended `finance_http_signed_jwt_qa.mjs` to cover v2 HTTP RPCs. This is **prepared but not run against signed QA user JWTs**.
- Added opt-in **Merchant QA Finance v2 Preview** frontend `web/components/merchant/merchant-finance-qa-preview.tsx`, mounted in the Merchant Finance page without replacing existing actual merchant finance reporting. It renders only when `NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW=true` **AND** the current SupabaseClient URL equals exact `https://pcatuxtenluqzjzzwsvl.supabase.co`. Feature flag is **OFF by default**.
- Added `web/tests/finance-qa-preview-gate.test.mjs` structural guard and included it in the sandbox branch's disposable PostgreSQL GitHub Actions workflow. **Frontend typecheck, browser test and the CI run itself have not been observed passing** in this session, so do not claim those are done.
- Designed isolated 2-/10-session concurrent refund testing in `supabase/sandbox/gp/isolated_refund_concurrency.mjs` with `.github/workflows/wynos-finance-qa-isolated.yml`. Local single-transaction Postgres compile/reconciliation proof passed, but independent concurrent sessions have not been verified by a completed CI log. GitHub connector workflow-run inspection is limited to pull-request-triggered runs; zero such runs is **not** proof that push workflows failed or succeeded.
- Documented unresolved settlement, GP, tax/fee and refund policy decisions in `FINANCE_RELEASE_READINESS_AND_SETTLEMENT_DESIGN.md`. **No Stripe charging/settlement/refund automation is deployed or authorized.**

## Last independent QA verification

| Invariant | Verified |
| --- | --- |
| Refund/GP/Finance/Reporting SQL Regression | 9/9 successful, each ROLLBACK |
| Persistent GP draft rates | 0 |
| GP order snapshots | 0 |
| Finance projections/lines | 0 |
| Refund adjustments/lines | 0 |
| QA Admin allowlist rows | 0 |
| Actually collected GP in QA finance rows | 0 satang |
| WF000005 original order | payment paid, refund none, pending_acceptance |
| WF000005 Stripe payment | paid, promptpay, livemode false |
| QA v2 internal read cores | security_invoker; anon/authenticated schema/EXECUTE denied |
| QA v2 public Admin/Merchant RPCs | authenticated EXECUTE with independent allowlist/store-owner checks |

## Remaining actual blockers to “100%”

1. Collect a verifiable green GitHub Actions log for the **true concurrent refund** two-/ten-session tests. Do not modify `main` or deploy to get one.
2. Execute **signed user JWT HTTP** tests from a network-capable authorized QA runner using legitimately authenticated QA owner, outsider and optional allowlisted QA admin, never checking credentials into Git or chat.
3. Run **Next.js TypeScript build, lint and browser checks** on the sandbox preview, and verify it stays hidden on any non-QA Supabase client/Production host. These were not run because no local repo/dependencies or CI execution report is available here.
4. Review the 25 `authenticated_security_definer_function_executable` security adviser findings (includes existing public API wrappers and new v2 wrappers) for business authorization semantics; also separately review QA Auth leaked-password protection when authorized. The Finance RLS no-policy advisor INFOs are intentionally deny-by-default, not automatically misconfigurations.
5. Product/finance owner must approve GP rate activation, discount sponsorship, delivery fee split, Stripe Connect PromptPay model, processing-fee reconciliation, invoices/tax, real payout and refund roles. Without those decisions **no legitimate 100% end-to-end money-movement claim is possible**.
6. No production/public release until an explicit separate deployment approval and all relevant gates are green.

**No further action was taken to move funds or deploy websites.** This document records reproducible work and truthfully separates created files, successful SQL QA, and unverified external E2E tests.
