# WYNOS Finance — real QA Auth/JWT & browser handoff

## 2026-10-09 approved one-time, self-cleaning QA Admin automation

**Implementation already committed to Sandbox, with no real user created or granted yet.**

- `supabase/sandbox/gp/finance_qa_ephemeral_admin_lifecycle.mjs`: QA-only Auth Admin REST `createUser` with synthetic `@wynos.online` email + 36-byte random temporary password generated inside runner memory. Automatically writes a scoped Finance Admin allowlist entry for that exact new user and invokes existing `finance_qa_password_auth_runner.mjs` to test the original QA owner, unrelated QA user and new Admin through **real signed JWT HTTP**.
- The script deletes **the allowlist grant first**, confirms it is absent, and deletes **only the newly created Auth user** after checking its exact CI-generated ID and email. Cleanup runs in `finally` and in a second GitHub Actions `if: always()` step. If cleanup fails, the job is red; an authorized operator must manually revoke it by exact QA Auth user ID. No Production user is modified.
- `.github/workflows/wynos-finance-approved-auth-lifecycle.yml` runs on Sandbox only using a protected GitHub Environment `wynos-finance-qa-approved`, requiring explicit variable/actor gate and human environment review. **The normal GitHub “Run workflow” option is not reliably available for a workflow present only on a non-default branch**. To comply with the no-main rule, the workflow supports a one-time **Sandbox push of `supabase/sandbox/gp/FINANCE_AUTH_QA_RUN_REQUEST.md`** rather than changing main. The newly created request file is `DISARMED` and its initial run was correctly **skipped**.
- `finance_qa_ephemeral_admin_safety.test.mjs` checks refusal of wrong repo/project/branch, unapproved pushes, bad secrets and no-op cleanup without network calls. No secrets are saved in GitHub source.

### Required authorized GitHub UI setup (not accessible via current GitHub connector)

1. In repository **Settings → Environments**, configure `wynos-finance-qa-approved` to allow **only** branch `sandbox/stripe-testmode-20261008`, enable required trusted reviewers if the GitHub plan supports it, and confirm the access controls are enforced. **Do not store a service-role key in an unrestricted repository secret. Stop if protected Environment secrets are unavailable.**
2. In **that protected Environment's Secrets**, set `WYNOS_QA_SERVICE_ROLE_LEGACY_JWT` (legacy **service_role JWT for QA PROJECT ONLY**, never Production), `WYNOS_QA_ANON_KEY` (publishable or legacy QA anon), `WYNOS_QA_OWNER_EMAIL`, `WYNOS_QA_OWNER_PASSWORD`, `WYNOS_QA_UNRELATED_EMAIL` and `WYNOS_QA_UNRELATED_PASSWORD` (credentials only for already-existing, dedicated QA owner/outsider users). These are server-side runner environment secrets, NEVER frontend/client or committed code. Verify both existing QA users genuinely support email/password Auth; do not modify their passwords without separate consent.
3. In **Environment or Repository Actions Variables**, set `WYNOS_QA_OWNER_STORE_ID` to a QA store owned by that owner user; `WYNOS_QA_OTHER_STORE_ID` to a different QA store; `WYNOS_QA_ONE_TIME_TRIGGER=true`; and `WYNOS_QA_APPROVED_ACTOR` to the exact GitHub login of the trusted operator who will push the request. The workflow still validates project URL, branch, project acknowledgement and manually approved workflow mode.
4. Trusted operator edits only the `RUN_REQUEST: DISARMED` line in <https://github.com/warren-wyn-dev/wynteam/blob/sandbox/stripe-testmode-20261008/supabase/sandbox/gp/FINANCE_AUTH_QA_RUN_REQUEST.md> to a one-time run marker and commits it **on Sandbox only**. A `push` touching that specific file then requests the protected CI job; environment reviewer should inspect the changed SHA before allowing execution. It must not be merged to main.
5. Confirm **real signed-JWT HTTP PASS** for owner/outsider/Admin in GitHub run logs and **cleanup PASS**. **Immediately** set `WYNOS_QA_ONE_TIME_TRIGGER=false`; remove or rotate the temporary provisioning credentials as appropriate, confirm QA Auth user count returns to the expected baseline 2 and `food_gp_admin_allowlist` returns to 0, with no finance snapshots, adjustments or real GP collection.
6. If a CI crash or missed cleanup leaves a synthetic `finance-qa-<runId>-...@wynos.online` account, the operator must **first** revoke its exact Finance QA allowlist entry and then delete only that synthetic Auth user from the QA Auth dashboard. Do not delete existing QA owner/outsider accounts or use SQL INSERT/DELETE on `auth.users`.

**No Auth account, allowlist grant, or GitHub credential was created in this conversation:** the existing Supabase/GitHub connectors do not expose the necessary Admin API / protected secret management actions. The approved QA operation remains **armed only by the human operator's secure environment configuration and file edit**.


**Scope:** GitHub branch `sandbox/stripe-testmode-20261008`; Supabase QA project `pcatuxtenluqzjzzwsvl` ONLY. Do **not** deploy, merge `main`, access Supabase Production, collect GP, call Stripe Refund, or create actual transfers/payouts.

## Readiness observed on 2026-10-09 local time

Read-only Supabase QA catalog counts:
- Auth users: **2**
- Active store-owner memberships: **1**
- Stores: **3**
- `food_gp_admin_allowlist` entries: **0**
- Persistent GP order snapshots: **0**

**APPROVAL RECEIVED (2026-10-09), BUT NOT EXECUTED:** The founder explicitly approved provisioning ONE temporary third QA Auth Admin and its temporary allowlist grant, with removal after testing. Full independent-owner/unrelated/allowlisted-admin HTTP proof still needs three genuinely authenticated QA users. The existing QA does **not** have all three accounts/roles. A role claim or user_metadata value cannot substitute for genuine allowlist membership. **The approved procedure is restricted to the temporary QA-only lifecycle, not persistent accounts, credentials, Production or actual payouts.**

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
