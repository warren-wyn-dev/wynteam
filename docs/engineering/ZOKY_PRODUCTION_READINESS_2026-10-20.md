# ZOKY readiness patch — 2026-10-20

## Scope and source

User request: fix the findings at zoky.wynos.online and prepare the service for real use; subsequently requested drafting the missing terms/privacy documents.

Patch base is the actual production release, `0533fb3649f3c327f451bc95832674d63c0f6873` on `release/zoky-web-20261018`, rather than the unrelated current `main` line. Dedicated branch: `fix/zoky-production-readiness-20261019`. Published source hashes matched the tracked baseline in 508 inspected files; only generated `next-env.d.ts` differed. Production deployment observed: `dpl_AkiQauWxjz9FLnNrm5evmfmQAPqD`, Vercel project `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`, team `team_Kamt1PUT5XKn9MWrF404re1w`.

## Changes

- Remove the imperative temporary theme-color node from Food splash. React had adopted that node and crashed with `removeChild` after its timer removed it. Keep the existing Next viewport color, splash timing and session behavior.
- Keep password recovery in ZOKY through server-resolved exact return-path allowlisting, matching SSR/hydration branding, safe URL scrubbing, reload and successful reset. Preserve Social recovery and one-time-token checks.
- Draft public terms/privacy pages with signup links, accessible navigation and existing English translation support. Keep the drafts explicitly unapproved/noindex until real operator/contact/effective-date details and content approval are supplied.
- Fail closed when a previous Stripe Checkout cannot be verified, reuse open sessions, and replace only confirmed expired sessions.
- Protect terminal payment-ledger states from delayed concurrent Checkout or cancellation writes.
- Expire Checkout before customer cancellation; enforce that requirement in the locked cancellation RPC. Serialize slip submission against webhooks and keep refunded/paid states monotonic under out-of-order events. Late payment of a cancelled order enters the existing explicit merchant refund queue; no automatic refund policy is introduced.

## Verification

- `npm ci --ignore-scripts --no-audit --no-fund` used the existing lockfile; no dependency upgrade.
- Full `npm run check`: lint with 0 errors (17 existing warnings), typecheck, 18 Node suite runs/356 assertions, and optimized production build passed. Subsequent additional payment-terminal regression passed in the focused final Stripe suite: 52/52.
- Production-build browser QA: 26/26 Chromium Android/desktop cases; no skipped, flaky or failed cases. Covers first-session splash navigation, required menu options, basket persistence, public policy links, recovery-token security and mocked successful recovery to both supported login destinations.
- PostgreSQL 17.11: 35 real local behavior/concurrency assertions plus the existing Stripe SQL suite passed. Three deliberately regressed SQL controls and separate Edge negative controls fail as expected.
- Independent technical/security review passed for this bounded patch and staging. No production payment or account was used in the tests.
- Read-only production aggregate preflight on 2026-10-20 returned zero Stripe-linked order rows and zero mismatches in the inspected paid/refunded/cancelled-refund-queue categories. This establishes no historical Stripe rows to reconcile in those checks; it does not establish provider integration readiness.
- Safari/WebKit did not run: downloaded browser requires system libraries unavailable in this environment, and system installation was denied. Chromium mobile emulation does not establish Safari compatibility.

Evidence logs/screenshots are in the session workspace `/workspace/zoky-audit/`; they are not shipped as application source or credential-bearing CI artifacts.

## Release boundaries and sequence

The source patch and local verification are complete. They do not establish provider, fulfillment, notification or payout end-to-end operation in production.

Before production approval: review actual operator/contact details and final policy text; verify the reviewed artifact in staging; run the designated customer/order/payment/webhook/cancel/refund/merchant flow in an isolated Stripe sandbox; review aggregate historical order/ledger consistency without exposing customer data. The preventive migration does not silently rewrite historical records.

After explicit production approval under `AGENTS.md`, release the reviewed `food-stripe-checkout` and `food-stripe-cancel` functions to Supabase `kqokpocajhfbidcxpvhh`, apply `20261019174958_food_stripe_cancellation_payment_race_guard.sql`, and release the reviewed web artifact to the existing Vercel project. New SQL guards make older clients fail closed until they reload the new cancellation preflight. Do not change accounts, access policy, GP rates or payment modes during this release.

Perform post-release public login/navigation smoke checks and controlled payment-state checks. Retain the previous deployment/function revisions and prior function definitions as recovery references. Production rollback remains a Founder decision; do not automatically roll back or restore unsafe payment semantics. Record exact release versions, results and any separately approved reconciliation.

Production domains share this web deployment (Social, Merchant and Maps included), so retain the unchanged baseline and test relevant common routes. Preview configuration adds only the two existing public Supabase browser variables to the preview target; production configuration remains unchanged. Vercel has no connected GitHub account, so a source-file preview is the supported fallback; no new hosting project or paid infrastructure is required.
