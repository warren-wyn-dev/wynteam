# WYNOS Finance — Phase 1 QA security hardening follow-up (2026-10-08)

**Allowed scope:** GitHub `warren-wyn-dev/wynteam` branch `sandbox/stripe-testmode-20261008`, Supabase QA `pcatuxtenluqzjzzwsvl` exclusively. No Production Supabase, Main branch, Stripe Live, real refunds, GP collection, payouts, Vercel deployment or live checkout/webhook changes.

## Actual work performed

1. Inspected QA project status and the original finance/reporting migrations; confirmed finance projection/refund snapshots and GP rates still contain zero permanent rows.
2. Installed migration `supabase/migrations_wynos_food_finance_private_reporting_core_sandbox_v1.sql`. It moves `food_finance_report_core_qa` and `food_finance_events_core_qa` to the non-exposed `wynos_finance_qa_private` schema as `SECURITY INVOKER`, denies `USAGE` and `EXECUTE` to `anon`/`authenticated`, and preserves the established Admin and Merchant public RPC wrappers and their owner/allowlist verification.
3. Updated `finance_reporting_smoke.sql` and `finance_authz_role_smoke.sql` to assert denial on **the new private core location**. Initially these two scripts failed because they referred to the former public core. After correction the entire six-script SQL regression set ran successfully and rolled back:
   - `refunds_smoke.sql`
   - `refunds_edge_smoke.sql`
   - `finance_smoke.sql`
   - `finance_reporting_smoke.sql`
   - `finance_authz_role_smoke.sql`
   - `refunds_cross_store_guard_smoke.sql`
4. Added and **executed** `finance_claims_spoof_smoke.sql`, with `BEGIN/ROLLBACK`. An unrelated authenticated QA database role supplied admin/owner flags in simulated JWT metadata and was **denied** Admin/Merchant Finance RPC access. This is **not** a cryptographically signed JWT test.
5. Added `finance_http_signed_jwt_qa.mjs` (dependency-free Node 22) for actual HTTP/RPC tests using **legitimately obtained** short-lived QA user JWTs through environment variables. Strict QA URL and acknowledgement safeguards; no secrets committed. **Syntax-checked but NOT executed**: no verified QA user JWT credentials in the active session and the local runtime cannot resolve the QA Supabase hostname. This runner intentionally does only read-only Finance RPC requests and checks forbidden access.
6. Added `finance_two_session_order_lock_probe_qa.mjs`, requiring psql and a QA-only DB connection string. It coordinates **two independent PostgreSQL sessions** to test the existing WF000005 order-row `FOR UPDATE` locking; both transactions ROLLBACK, no Finance/refund records. **Syntax-checked but NOT executed** in this environment because direct QA DB networking and psql are unavailable. Importantly, even when executed this proves row locking infrastructure **not a true simultaneous refund RPC race**.

## Security findings

- Internal Finance Reporting cores are confirmed located in `wynos_finance_qa_private`, `SECURITY INVOKER`, and denied to `anon`/`authenticated` at function and schema levels.
- Public Admin/Merchant wrappers remain callable by `authenticated` *after* a server-side allowlist/store-owner check. Supabase Security Advisor still flags these intentional `SECURITY DEFINER` wrappers for review: **not suppressed, not declared fully remediated**.
- Finance tables remain RLS enabled and deny direct `anon`/`authenticated` SELECT/INSERT.
- No claim is made about cryptographic JWT validation, HTTP access, or real concurrent double-spend protection until an external environment executes the relevant tests.

## Running the remaining tests safely (on an authorized QA test machine)

For signed JWT HTTP tests, supply from your secret manager (not source code or shell history):
`WYNOS_QA_HTTP_ACK` = `pcatuxtenluqzjzzwsvl`,
`WYNOS_QA_ANON_KEY`,
`WYNOS_QA_OWNER_JWT`,
`WYNOS_QA_UNRELATED_JWT`,
`WYNOS_QA_OWNER_STORE_ID`,
`WYNOS_QA_OTHER_STORE_ID`.
Optional: `WYNOS_QA_APPROVED_ADMIN_JWT` to test positive Admin access.
Run: `node supabase/sandbox/gp/finance_http_signed_jwt_qa.mjs`.
Do not paste tokens into GitHub or commit them.

For the non-destructive two-session **order-row lock** probe, provide
`WYNOS_QA_LOCK_ACK` = `pcatuxtenluqzjzzwsvl` and `WYNOS_QA_DB_URL` from the QA-only project, use an environment with `psql` and QA DB DNS access, then run:
`node supabase/sandbox/gp/finance_two_session_order_lock_probe_qa.mjs`.
The script refuses database hostnames outside `db.pcatuxtenluqzjzzwsvl.supabase.co`.
Do not treat a pass as validation of simultaneous refund RPCs.

**Open blocker for true concurrent Refund append:** the QA Finance projection table has zero committed rows. A projection created within transaction A is invisible to transaction B; rolling back both sessions cannot yield a shared committed projection. Without relaxing the explicit ROLLBACK-only test fixture rule or designing a separate isolated test database with a permitted ephemeral fixture, true concurrent Refund append remains unverified. Do not create committed test finance records on this shared QA database without separate authorization.

## Final verification to perform before closing

- Repeat the 7 rollback-only SQL tests; verify QA GP rate, Finance projection, refund and allowlist counts remain zero.
- Check WF000005 stays test-mode PromptPay `paid` and `refund_status=none`.
- Review Security Advisor on QA; warnings must be evaluated with code-level authorization checks.
- After authorized signed-JWT HTTP QA tests and verifiable two-session refund concurrency tests pass, Phase 1 can be fully closed. Otherwise continue as **partially completed, pending proof**.
