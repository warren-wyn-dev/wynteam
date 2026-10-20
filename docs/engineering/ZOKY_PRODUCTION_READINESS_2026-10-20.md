# ZOKY readiness patch — 2026-10-20

## Scope and source

User request: fix the findings at zoky.wynos.online and prepare the service for real use; subsequently requested drafting the missing terms/privacy documents.

Patch base is the actual production release, `0533fb3649f3c327f451bc95832674d63c0f6873` on `release/zoky-web-20261018`, rather than the unrelated current `main` line. Dedicated branch: `fix/zoky-production-readiness-20261019`. Published source hashes matched the tracked baseline in 508 inspected files; only generated `next-env.d.ts` differed. Production deployment observed: `dpl_AkiQauWxjz9FLnNrm5evmfmQAPqD`, Vercel project `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`, team `team_Kamt1PUT5XKn9MWrF404re1w`.

## Changes

- Remove the imperative temporary theme-color node from Food splash. React had adopted that node and crashed with `removeChild` after its timer removed it. Keep the existing Next viewport color, splash timing and session behavior.
- Keep password recovery in ZOKY through server-resolved exact return-path allowlisting, matching SSR/hydration branding, safe URL scrubbing, reload and successful reset. Preserve Social recovery and one-time-token checks.
- Draft public terms/privacy pages with signup links, accessible navigation and existing English translation support. Keep the drafts explicitly unapproved/noindex until real operator/contact/effective-date details and content approval are supplied.
- Fail closed when a previous Stripe Checkout cannot be verified, reuse open sessions, and replace only confirmed expired sessions.
- Allow an explicitly configured exact HTTPS Sandbox return origin only for a proven test-mode Stripe key. Use fixed `/food` and `/merchant` paths on generic Preview hosts; retain live guards and canonical behavior. Both actual Checkout payloads and hosted onboarding v1/v2 URL builders are covered. New Sandbox orders are required because an existing open Checkout retains its original return URLs.
- Protect terminal payment-ledger states from delayed concurrent Checkout or cancellation writes.
- Expire Checkout before customer cancellation; enforce that requirement in the locked cancellation RPC. Serialize slip submission against webhooks and keep refunded/paid states monotonic under out-of-order events. Late payment of a cancelled order enters the existing explicit merchant refund queue; no automatic refund policy is introduced.

## Verification

- `npm ci --ignore-scripts --no-audit --no-fund` used the existing lockfile; no dependency upgrade.
- Full `npm run check`: lint with 0 errors (17 existing warnings), typecheck, 18 Node suite runs/356 assertions, and optimized production build passed. Subsequent payment-terminal and Sandbox-return regression passed in the focused final Stripe suite: 58/58. Independent return-origin review passed 40 adversarial assertions after a literal-wildcard hostname rejection fix. Deno 2.9.6 also typechecked Checkout, Cancel, Merchant Connect and the shared helper successfully without changing repository dependencies or executing handlers.
- Production-build browser QA: 26/26 Chromium Android/desktop cases; no skipped, flaky or failed cases. Covers first-session splash navigation, required menu options, basket persistence, public policy links, recovery-token security and mocked successful recovery to both supported login destinations.
- PostgreSQL 17.11: 35 real local behavior/concurrency assertions plus the existing Stripe SQL suite passed. Three deliberately regressed SQL controls and separate Edge negative controls fail as expected.
- Independent technical/security review passed for this bounded patch and staging. No production payment or account was used in the tests.
- Read-only production aggregate preflight on 2026-10-20 returned zero Stripe-linked order rows and zero mismatches in the inspected paid/refunded/cancelled-refund-queue categories. This establishes no historical Stripe rows to reconcile in those checks; it does not establish provider integration readiness.
- Subsequent WebKit iPhone-emulation QA passed 13/13 cases with no skips, failures or flaky results. Missing runtime libraries were SHA-256-verified and unpacked into a scratch directory without system installation or browser-binary changes; a custom launcher preserves that library path. Combined local Chromium/WebKit coverage is 39 project-cases. This is Linux WebKit emulation, not physical iOS Safari verification.
- Hosted Preview verification passed all 26 distinct Chromium mobile/desktop cases: 24 initially, then the two API-fixture cases passed after correcting the test environment HTTPS proxy. No application source change was needed. A separate real public-catalog smoke returned HTTP 200 with no page errors or horizontal overflow at 390px; it submitted no order or payment.

Evidence logs/screenshots are in the session workspace `/workspace/zoky-audit/`; they are not shipped as application source or credential-bearing CI artifacts.

## Hosted artifact and sandbox preflight

Reviewed application commit: `4f2c0b9feedec725b61dfc1fce8d5ccda9bb24ed`. Draft PR: https://github.com/warren-wyn-dev/wynteam/pull/1228. Protected Preview: https://web-3p1rz8343-warren14.vercel.app (Vercel sign-in required). Preview deployment `dpl_5wD3jBi3Kon5vFGXimu5xMd28kbG` is ready; production remains the baseline deployment recorded above. Temporary deployment-specific access expired and local authentication state was removed.

The existing separate Stripe sandbox contains earlier test payments/refund events, but lacks current customer-access, quote/create, cancellation and merchant-fulfillment RPCs and has no published catalog for the current browser flow. An active merchant membership exists; empty legacy staff tables alone do not establish an access blocker. Its authorized fixture session is unavailable. Root-level legacy migration files contain baseline definitions, but replaying them wholesale can replace newer functions, access policies, rollout and campaign settings. A guarded sandbox-only alignment bundle needs separate review and rehearsal before use. No sandbox or production schema was changed by this preflight.

The user subsequently created and connected **ZOKY-QA**, verified as test mode. Connect was enabled there, and a connected-account snapshot webhook (10 selected events) plus Accounts v2 thin destination (7 source-handled events) were created for the isolated Supabase project. This does not wire backend keys automatically: secure test-key/signing-secret configuration and supported test Auth sessions remain outstanding. A separate protected Preview, https://web-77aa30xtn-warren14.vercel.app, is ready against the isolated database; the earlier general Preview remains unchanged. Its deployment-only build configuration pins public Supabase values without changing project environment variables. No live financial mutation was attempted and no provider end-to-end success is asserted.

## Release boundaries and sequence

The source patch and local verification are complete. They do not establish provider, fulfillment, notification or payout end-to-end operation in production.

Before production approval: review actual operator/contact details and final policy text; verify the reviewed artifact in staging; run the designated customer/order/payment/webhook/cancel/refund/merchant flow in an isolated Stripe sandbox; review aggregate historical order/ledger consistency without exposing customer data. The preventive migration does not silently rewrite historical records.

After explicit production approval under `AGENTS.md`, release the reviewed `food-stripe-checkout`, `food-stripe-cancel` and `merchant-stripe-connect` functions with their shared `_lib.ts` dependency to Supabase `kqokpocajhfbidcxpvhh`, apply `20261019174958_food_stripe_cancellation_payment_race_guard.sql`, and release the reviewed web artifact to the existing Vercel project. New SQL guards make older clients fail closed until they reload the new cancellation preflight. Do not change accounts, access policy, GP rates or payment modes during this release.

Perform post-release public login/navigation smoke checks and controlled payment-state checks. Retain the previous deployment/function revisions and prior function definitions as recovery references. Production rollback remains a Founder decision; do not automatically roll back or restore unsafe payment semantics. Record exact release versions, results and any separately approved reconciliation.

Production domains share this web deployment (Social, Merchant and Maps included), so retain the unchanged baseline and test relevant common routes. Preview configuration adds only the two existing public Supabase browser variables to the preview target; production configuration remains unchanged. Vercel has no connected GitHub account, so a source-file preview is the supported fallback; no new hosting project or paid infrastructure is required.
