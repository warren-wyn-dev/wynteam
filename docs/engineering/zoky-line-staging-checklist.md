# Zoky Merchant LINE — Stage integration and operator release gates

This is **documentation for later rollout**, not permission to deploy. Zoky and WYNOS share the same Supabase project. No direct `execute_sql` against production, production Edge Functions, LINE Webhook URL, GitHub merge, or real outbound LINE messages should be attempted until the gates pass.

## Current source layout

- `supabase/functions/zoky-line-account`: signed-in Merchant store membership, status/begin/unlink
- `supabase/functions/zoky-line-webhook`: raw-body HMAC verification, accountLink and postback event handling
- `supabase/functions/zoky-line-notify`: secret-protected outbox sender and stable LINE retry key
- `web/app/merchant/line-connect/page.tsx`: Merchant login, store picker, LINE confirmation, connection status and revoke
- `docs/engineering/zoky-line-end-to-end-schema-candidate.sql`: **UNAPPLIED** schema candidate; explicit `zoky_line_enabled_stores` opt-in, no stores enabled by default
- `supabase/tests/zoky_line_contract_test.sh`: isolated PostgreSQL RLS/link replay and order transition tests (no production access)

## Pre-release test checklist (tasks 1–6)

1. All GitHub CI jobs and the focused `Zoky LINE isolated Postgres + Node contract` job pass on the **last** SHA; run Deno tests and Next.js i18n, lint and type checks. No ignored CI failures.
2. Compare the SQL candidate with the **live** `food_transition_order` contract and the Stripe jobs/auto-refund triggers and test both COD, paid transfer, Stripe-paid and rejected/cancelled orders. LINE must delegate state changes to the same canonical order RPC. Test no cross-store unauthorized transition.
3. Apply migrations ONLY to a disposable/staging database first (Supabase Preview Branch can incur hourly charges). Run RLS tests with anon, authenticated, service_role; test concurrent nonce consumption and double accepts.
4. Add a synthetic Zoky store ID to staging-only `zoky_line_enabled_stores`, create demo Merchant staff account, validate link + unlink + re-link using LINE test Channel in staging. No WYNOS store ID is ever allowed.
5. Test new paid order -> outbox -> signed mocked LINE Push -> verified postback -> status change/notification/refund jobs -> Merchant UI. Verify the content of outbound cards contains no shipping address, telephone number, payment slip or financial secret.
6. Test LINE API 429, timeouts, replay webhook events, aborted link, blocked OA and worker failure. No duplicate accepted orders or forwarded messages.

## Worker scheduler design (later, after Edge deploy)

- Provision an independently generated **>=40 character random** `ZOKY_LINE_WORKER_KEY` as a secret on the worker Edge Function; store a matching value in Supabase Vault for the cron owner. Do not put it in this file, GitHub, screenshots or chat.
- Allow an isolated cron task to issue a POST with header `x-zoky-line-worker-key` to the deployed `https://<project-ref>.supabase.co/functions/v1/zoky-line-notify`. Start with one minute cadence and a limit of 20 claimed rows per call.
- The outbox sender must use the **persisted** Retry Key for each delivery, set delivered state on HTTP success, and store backoff/failure without logging LINE IDs or order data.
- Verify paid-order eligibility again at claim time, including linked user + membership, explicit Zoky store allowlist, correct order state and payment status.
- Set up per-channel LINE quota limits, error monitoring, recovery for expired leases, worker alerts, and a manual off switch. In-app Merchant notifications remain the fallback.

## Production enablement (tasks 7–8, *not authorized by this stage*)

After founder approval, reviewed migration/rollback, current GitHub CI and staging E2E: deploy 3 Edge Functions, configure secrets in dashboard without exposing values, run an authenticated test of the worker, then set the LINE Developers Webhook URL to the actual deployed HTTPS endpoint. Verify LINE callback with an empty events payload, enable Use webhook, and pilot with one explicitly approved Zoky store.

Rollback: disable LINE webhook, unschedule worker, block `zoky_line_enabled_stores` opt-ins / revoke connections, then revert Edge Functions; do not delete live orders or shared WYNOS schema.
