# WYNOS Food Finance — QA Implementation & Handoff (2026-10-08)

**Branch**: `sandbox/stripe-testmode-20261008` in `warren-wyn-dev/wynteam`.
**Supabase QA**: `pcatuxtenluqzjzzwsvl` ONLY. Production Supabase, Stripe live funds, real GP/refunds, main and Vercel deployment are untouched.

## Completed today

- Implemented and installed read-only Finance Reporting **v2** SQL RPC migration `supabase/migrations_wynos_food_finance_reporting_v2_sandbox.sql`; corrected actual PostgreSQL `COALESCE` runtime error via follow-up additive migration `supabase/migrations_wynos_food_finance_reporting_v2_coalesce_fix_sandbox.sql` (QA migration versions `20261008161929`, `20261008162035`).
- Admin/owner-gated daily and monthly `Asia/Bangkok` time buckets; independent creation dates for projections and refunds; zero-event periods explicitly show zero values; max 366 days and validated granularity.
- Admin/owner-gated per-order projected food GP and simulated refund history. Stripe processing fee and net merchant payout remain **unknown/null**. Privileged read cores are `SECURITY INVOKER` in nonexposed `wynos_finance_qa_private`; direct `anon`/`authenticated` access denied. Public authenticated wrappers require QA admin allowlist or actual active merchant store owner.
- Added `finance_reporting_v2_smoke.sql` and `finance_reporting_v2_roles_smoke.sql` with rollback-only fixtures. **All 9/9 Finance SQL regression scripts executed without SQL errors** in QA after the v2 migration and correction.
- Extended `finance_http_signed_jwt_qa.mjs` to cover v2 HTTP RPCs. This is **prepared but not run against signed QA user JWTs**.
- Added opt-in **Merchant QA Finance v2 Preview** frontend `web/components/merchant/merchant-finance-qa-preview.tsx`, mounted in the Merchant Finance page without replacing existing actual merchant finance reporting. It renders only when `NEXT_PUBLIC_WYNOS_FINANCE_QA_PREVIEW=true` **AND** the build configuration `NEXT_PUBLIC_SUPABASE_URL` equals exact `https://pcatuxtenluqzjzzwsvl.supabase.co`. Feature flag is **OFF by default**.
- Added `web/tests/finance-qa-preview-gate.test.mjs` structural guard and included it in the sandbox branch's disposable PostgreSQL GitHub Actions workflow. **Confirmed** sandbox Web CI [run #37810110980](https://github.com/warren-wyn-dev/wynteam/actions/runs/37810110980) PASS: reproducible `npm ci`, scoped ESLint, preview guard tests, Next.js type generation, full web TypeScript strict check and full Next.js build **without deployment**. Browser-interaction QA still not confirmed.
- Designed isolated 2-/10-session concurrent refund testing in `supabase/sandbox/gp/isolated_refund_concurrency.mjs` with `.github/workflows/wynos-finance-qa-isolated.yml`. Local single-transaction Postgres compile/reconciliation proof passed, and independent real concurrent database sessions have **now been verified** from the actual GitHub Actions job log [run #37808564060](https://github.com/warren-wyn-dev/wynteam/actions/runs/37808564060): **5/5** scenarios PASS (same-key idempotency, over-refund denial, cumulative rounding, conflicting replay rejection, and 10 simultaneous connections). [Run #37810111186](https://github.com/warren-wyn-dev/wynteam/actions/runs/37810111186) also succeeded on updated sandbox branch. Both used disposable Postgres 17, not Supabase QA or Stripe.
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

1. **CLOSED for isolated SQL concurrency**: GitHub Actions [run #37808564060](https://github.com/warren-wyn-dev/wynteam/actions/runs/37808564060) PASS all five real multi-session cases; further full Supabase/PostgREST/Stripe HTTP E2E remains separate.
2. Execute **signed user JWT HTTP** tests from a network-capable authorized QA runner using legitimately authenticated QA owner, outsider and optional allowlisted QA admin, never checking credentials into Git or chat.
3. **CLOSED for build-level checks**: [sandbox Web QA run #37810110980](https://github.com/warren-wyn-dev/wynteam/actions/runs/37810110980) PASS full Next.js build, strict TS, scoped Finance component ESLint and three static QA feature-gate tests. **OPEN**: interactive Playwright/browser QA with legitimately authenticated QA merchant on the QA-only deployment (no website deployed here).
4. Review the 25 `authenticated_security_definer_function_executable` security adviser findings (includes existing public API wrappers and new v2 wrappers) for business authorization semantics; also separately review QA Auth leaked-password protection when authorized. The Finance RLS no-policy advisor INFOs are intentionally deny-by-default, not automatically misconfigurations.
5. Product/finance owner must approve GP rate activation, discount sponsorship, delivery fee split, Stripe Connect PromptPay model, processing-fee reconciliation, invoices/tax, real payout and refund roles. Without those decisions **no legitimate 100% end-to-end money-movement claim is possible**.
6. No production/public release until an explicit separate deployment approval and all relevant gates are green.

**No further action was taken to move funds or deploy websites.** This document records reproducible work and truthfully separates created files, successful SQL QA, and unverified external E2E tests.

## Verified final CI results (after this handoff was first written)

- **Concurrent Refund multi-connection test**: [GitHub Actions run #37808564060](https://github.com/warren-wyn-dev/wynteam/actions/runs/37808564060), job `isolated-refund-concurrency`, `success`. Job logs explicitly show **all 5 tests pass**; Docker Postgres 17 service was removed after the job. A later isolated workflow [run #37810111186](https://github.com/warren-wyn-dev/wynteam/actions/runs/37810111186) also completed successfully.
- **Merchant Finance Web preview build**: [GitHub Actions run #37810110980](https://github.com/warren-wyn-dev/wynteam/actions/runs/37810110980), job `finance-web-qa`, `success`. `npm ci --ignore-scripts`, static three-case preview gate tests, scoped ESLint, Next.js route generation, full `tsc --noEmit` and `next build` all passed. No deployment occurred. Initial failed CI runs detected two real TypeScript issues in new preview; these were fixed. The whole-web lint also exposed two existing errors in the unrelated Stripe sandbox return page, left unchanged in accordance with payment-scope safety.
- **Finance SQL QA**: reran all 9 rollback-only scripts with no SQL errors. 0 QA GP rates, GP order snapshots, projections, adjustments, refund lines, allowlist entries or collected GP persist. WF000005 remains `paid` / `refund_status=none`, and the payment remains Test Mode PromptPay (`livemode=false`).
- **Manual real signed-JWT testing remains OPEN**: created an opt-in [signed JWT HTTP workflow](https://github.com/warren-wyn-dev/wynteam/blob/sandbox/stripe-testmode-20261008/.github/workflows/wynos-finance-signed-jwt-qa.yml). Its workflow is intentionally not run until **short-lived authorized QA JWTs**, QA anon key and store IDs are set via GitHub Actions Secrets/Variables; it MUST NOT use Production or service-role credentials. The workflow is registered on Sandbox pushes but the test job is **skipped by default** unless repository Variable `WYNOS_QA_JWT_HTTP_ENABLED` equals `true`. Once enabled, missing secrets make the test fail rather than silently claiming PASS. No JWT role test has run yet.
- **Still not live-ready**: manual QA browser E2E, signed-JWT Auth HTTP, current advisor wrapper warnings / Auth leaked-password warning, business/financial/tax policy approval, Stripe settlement reconciliation design approval and separate Production release approval.

**Do not equate a successful SQL simulator, CI build, or isolated concurrency run with authorization for real GP collection, live payouts or real refunds.**

## Signed JWT CI setup required for final HTTP QA

A trusted QA operator can configure **GitHub repository Actions Secrets** (do not paste values into chat or commit them):
`WYNOS_QA_ANON_KEY` (QA publishable/anon), `WYNOS_QA_OWNER_JWT` and `WYNOS_QA_UNRELATED_JWT` (short-lived *real Supabase Auth user* JWTs for the QA project), optionally `WYNOS_QA_APPROVED_ADMIN_JWT` for the positive admin test. GitHub **Actions Variables**: `WYNOS_QA_OWNER_STORE_ID`, `WYNOS_QA_OTHER_STORE_ID`, and set `WYNOS_QA_JWT_HTTP_ENABLED=true` only while conducting authorized testing. Never use service-role, Stripe, Production or live-merchant credentials. Tokens may expire quickly; rotate as needed.

The opt-in workflow triggers only on sandbox workflow/HTTP test file changes or when dispatched where GitHub permits; toggling a Variable alone does not start a workflow, and a skipped job is **not a successful HTTP test**. This testing must explicitly complete with green run logs before declaring the Auth HTTP gate closed.

**Signed JWT strict gate update:** `WYNOS_QA_STRICT_AUTH_GATE=true` is enforced in sandbox HTTP CI. A missing positive **explicitly allowlisted** QA Admin JWT causes the runner to exit as **INCOMPLETE**, never green. Setting credentials without QA admin allowlist is not enough; this requires a separately authorized QA-only account/allowlist fixture lifecycle. No permanent QA allowlist entry was created automatically.

## Additional work: Browser E2E and Finance security catalog regression

Date: 2026-10-08, restricted to sandbox GitHub and QA Supabase only.

### Verified automated tests
- [Browser QA run #37812055147](https://github.com/warren-wyn-dev/wynteam/actions/runs/37812055147) **SUCCESS: 8/8 real Chromium tests**, covering Desktop and Android simulated viewport, day/month bucket selection, date invalidation, detailed simulated QA order lookup, masked real money fields, and error handling when mocked RPC denies access. Tests mount the **real React Finance Preview component** on an ephemeral Next.js route created only inside CI from `web/tests/finance-qa-browser-fixture.page.tsx`; the route is deleted after CI. **Mock RPC**, NOT signed Supabase Auth/browser E2E. No production deployment.
- First browser run #37811825711 exposed test locator ambiguity (4/8). Fixed Playwright assertions in `web/tests/browser/finance-qa-preview.spec.ts`, then reran to 8/8 PASS. No Finance application backend authorization code was relaxed.
- Security inventory regression `supabase/sandbox/gp/finance_security_catalog_smoke.sql`: **PASS** on Supabase QA under `BEGIN/ROLLBACK`; inspects 10 Finance public owner/admin gated functions, 4 private `SECURITY INVOKER` read cores, 8 GP/Finance restricted tables with RLS and explicit grants, and refund mutation isolation. **All 10/10 rollback-only Finance SQL regression scripts passed** including this new test.
- Signed JWT HTTP credential local preflight now checks QA issuer/project, no secret/service keys, legitimate authenticated role claims, short-lived unexpired JWT shape and separate QA identities *before network I/O*. This decoding is NOT JWT signature verification. Offline negative-only preflight regression `finance_http_preflight_qa.test.mjs` is integrated into the sandbox isolated concurrency CI. **Do not claim real signed-JWT HTTP passed.**

### Remaining security review findings
- Supabase QA Security Advisor lists 25 warning findings of authenticated-executable `SECURITY DEFINER` functions across the QA database; **10 belong to Finance public reporting wrappers** and these were examined with exact role/owner/allowlist checks via SQL. The warnings remain visible: they are an intentional, privileged wrapper architecture, not evidence that they have disappeared.
- 16 `rls_enabled_no_policy` informational findings; GP/Finance financial tables deliberately use deny-by-default with no direct authenticated/anon table access.
- `auth_leaked_password_protection` warning remains, requiring an authorized Auth configuration change, outside current Finance schema scope. No QA Auth policy was changed.
- Actual QA user HTTP signing/authorization remains unverified until authorized QA owner/unrelated user and explicitly allowlisted QA Admin JWTs exist in GitHub Actions Secrets. The opt-in signed-JWT gate job is skipped when `WYNOS_QA_JWT_HTTP_ENABLED` is not enabled and a skip is **not PASS**.

### Scope and no-live-money safety
All test orders and monetary totals in the browser CI harness are fake; never run the harness against production. Real GP collection, Stripe refunds, settlement, taxes and Production release still require distinct product/financial/legal approvals plus an explicit deployment action.

### 2026-10-08: JWT preflight and refreshed concurrency CI proof

[Isolated Finance QA run #37812532745](https://github.com/warren-wyn-dev/wynteam/actions/runs/37812532745) completed **successfully** on the sandbox branch. CI job logs show **8/8 negative QA credential-preflight cases passed** (no HTTP requests were made) and **all 5/5 concurrent refund cases passed** again on disposable PostgreSQL 17. Negative preflight tests reject wrong QA URLs, service/secret keys, expired or wrong-project JWT-shaped inputs, duplicated identities and unsafe store selection. These checks do not validate any actual JWT signature: they only prevent accidentally running the future real HTTP test under unsafe settings.

**Last QA DB read-only verification:** QA GP store rates=0, GP order snapshots=0, Finance projections=0, refund adjustments/lines=0, admin allowlist rows=0, actually collected GP=0 satang. Test order `WF000005` remains `paid`, `refund_status=none`, `pending_acceptance`, PromptPay payment `paid`, `livemode=false`.

**REMAINING approval gates:** signed-JWT HTTP with three separate, authorized Supabase QA users (Admin must be explicitly allowlisted), human-in-the-loop real QA merchant browser/auth end-to-end tests, decision/financial/tax review for GP/fees/discounts/delivery/Stripe settlement, assessment of project-level Auth leaked-password protection, and separate Production release approval. No live-money feature or release was enabled.
