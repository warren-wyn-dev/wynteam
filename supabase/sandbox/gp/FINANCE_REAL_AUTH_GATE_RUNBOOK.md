# WYNOS Finance — real QA Auth/JWT & browser handoff

**Scope:** GitHub branch `sandbox/stripe-testmode-20261008`; Supabase QA project `pcatuxtenluqzjzzwsvl` ONLY. Do **not** deploy, merge `main`, access Supabase Production, collect GP, call Stripe Refund, or create actual transfers/payouts.

## Readiness observed on 2026-10-09 local time

Read-only Supabase QA catalog counts:
- Auth users: **2**
- Active store-owner memberships: **1**
- Stores: **3**
- `food_gp_admin_allowlist` entries: **0**
- Persistent GP order snapshots: **0**

**BLOCKER:** Full independent-owner/unrelated/allowlisted-admin HTTP proof needs three distinct, legitimately authenticated QA users. The existing QA does **not** have all three accounts/roles. A role claim or user_metadata value cannot substitute for genuine allowlist membership. **Do not create Auth accounts or modify the allowlist without the founder's explicit approval of the specific QA-only fixture lifecycle.**

## Infrastructure already in Sandbox (no real user JWT execution yet)

- `.github/workflows/wynos-finance-signed-jwt-qa.yml`: opt-in QA-only Action. It is **skipped** until GitHub Actions Variable `WYNOS_QA_JWT_HTTP_ENABLED=true` and must only run on this Sandbox branch.
- `supabase/sandbox/gp/finance_http_signed_jwt_qa.mjs`: read-only PostgREST HTTPS tests on the **exact** QA host. Validates authentic Supabase-signed user identities only when actual HTTP requests run; local JWT decode is just a preflight.
- `supabase/sandbox/gp/finance_qa_password_auth_runner.mjs`: **alternative** to storing rapidly expiring JWTs. Takes existing QA-only users' email and password from GitHub Secrets, calls **only** the fixed QA `/auth/v1/token?grant_type=password` endpoint to obtain short-lived JWTs in memory, then runs the existing HTTP authorisation tests. Does **not** sign up users, change passwords, grant admin rights, or write finance data.
- `supabase/sandbox/gp/finance_qa_password_auth_preflight.test.mjs`: negative preflight for wrong environment/project, same identities, secret key etc.; tested offline as part of the isolated concurrency CI (no password sign-in attempted in test).
- Fake-client Playwright `web/tests/browser/finance-qa-preview.spec.ts` already checks real Preview React rendering but it is **not** a signed-user browser integration test. Use Auth with real authorized accounts in a separate, QA-only browser E2E job after the prerequisites below.

## One-time steps for the designated authorized QA operator

1. Confirm a dedicated, separately approved **third** QA Auth account exists and can sign in. Confirm three independent QA role identities: active **owner** of a known QA store; **unrelated** user who is not owner or finance admin; and separate, explicitly **allowlisted QA Finance Admin**. Validate correct QA project. Avoid test-user signup through Production flows or using live merchant identities.
2. With founder approval, add **only** the designated dedicated QA Admin user to `public.food_gp_admin_allowlist` using a controlled QA-only action; record who authorized, which account, why, when, and how/when to reverse. Do **not** use a production user or leave test allowlist entries unexpectedly. This is a persisted privilege grant and is not part of the rollback-only SQL suite, so it was deliberately **not done**.
3. In GitHub repo Actions **Secrets** set these QA-only credentials:
   - `WYNOS_QA_ANON_KEY` (QA publishable key or validated QA legacy anon key; **never service_role**)
   - `WYNOS_QA_OWNER_EMAIL` / `WYNOS_QA_OWNER_PASSWORD`
   - `WYNOS_QA_UNRELATED_EMAIL` / `WYNOS_QA_UNRELATED_PASSWORD`
   - `WYNOS_QA_APPROVED_ADMIN_EMAIL` / `WYNOS_QA_APPROVED_ADMIN_PASSWORD`
   Ensure restricted scope where supported; don't print passwords, JWTs, or authorization headers. **Do not paste these secrets in chat or commit them.**
4. In Actions **Variables** set:
   - `WYNOS_QA_OWNER_STORE_ID` and `WYNOS_QA_OTHER_STORE_ID` to distinct **real QA** store UUIDs, where the first is actually owned by owner QA test identity;
   - `WYNOS_QA_USE_PASSWORD_AUTH=true`;
   - `WYNOS_QA_JWT_HTTP_ENABLED=true` **only for the authorized QA test window**.
   The workflow sets the exact QA project acknowledgement and `WYNOS_QA_STRICT_AUTH_GATE=true`. For the fallback manually supplied short-lived JWT flow, leave `WYNOS_QA_USE_PASSWORD_AUTH` off and instead supply the existing three `WYNOS_QA_*_JWT` Secrets (not recommended because tokens expire rapidly).
5. Run the GitHub Actions workflow **WYNOS Finance Signed-JWT HTTP QA** from branch `sandbox/stripe-testmode-20261008` once. A **skipped** job, local JWT claims spoof regression, or passing preflight does **not** count as this HTTP gate. Inspect a **green job with owner/outsider/admin positive and negative HTTP checks**.
6. Immediately set `WYNOS_QA_JWT_HTTP_ENABLED=false`, rotate/revoke test credentials and QA Auth sessions as appropriate, remove the explicitly approved temporary allowlist grant, and verify `food_gp_admin_allowlist` returns to its expected empty state. Repeat read-only QA financial fixture counts and check test order `WF000005` remains paid/none, Test Mode PromptPay.

**If no third approved QA identity or allowlist authority exists, STOP before enabling this job.** Never fake an admin JWT, forge a DB session sub as a replacement, or bypass authorization by invoking service-role credentials.

## Security warnings & release boundary

QA Advisor findings at last check: `authenticated_security_definer_function_executable` **25 WARN**, `rls_enabled_no_policy` **16 INFO**, `auth_leaked_password_protection` **1 WARN**. All 10 Finance reporting wrappers were catalog-audited for owner/admin checks and non-anon EXECUTE; private reporting cores remain invoker-only in unexposed schema, and direct Finance tables have RLS and no user SELECT/INSERT. These reviews **do not** clear all project-wide Auth/security warnings. Independently approve strengthening leaked-password checks via <https://supabase.com/docs/guides/auth/password-security>, without altering Production.

The runbook covers authorization QA only. Real GP collection requires founder approval of rates, delivery split, who funds discounts, taxation, Stripe Connect PromptPay fee treatment, actual balance-transaction reconciliation, payouts/refunds and a separate release decision.
