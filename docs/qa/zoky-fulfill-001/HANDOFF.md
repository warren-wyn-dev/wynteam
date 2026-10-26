# ZOKY-FULFILL-001 — local verification complete, hosted release pending

The complete web/database candidate is based on integration d7f1d797, which derives from actual web production71f7fb0f. A separate Admin candidate at /workspace/wynteam-admin is based on actual Admin production8fab9b4b; no unrelated main application changes are combined into web.

## Implemented

- Production-definition-pinned additive schema/RPCs: same-day Bangkok pickup slots, store opt-ins, COD cash completion and GP0, cancellation requests and explicit merchant/no-show refund decisions, private immutable refund evidence, pickup report/history/review support, Admin read models.
- RPC authorization and RLS/Storage controls, no direct order state or fulfillment-setting updates, no legacy scheduling bypass. Completed transfer refunds cannot be undone through old payment/refund RPCs. Legacy orders with no buyer cannot be claimed via null ownership comparisons.
- Food checkout supports pickup contacts without an address, server-issued slots, delivery-only COD, transfer/manual slip verification and paused Stripe offerings. Merchant supports both modes, pending cancellation and refund proof; Stripe legacy callbacks/code remain.
- Scoped Admin shows modes/payment/status/code/time, overdue refunds and aggregate finance split. No data is fabricated on failed reads.
- Scoped release controls pin exact code, paths, production baselines, migration/verification hashes and deployment identities. They preserve the existing general release freeze, require staging/production reviews and stage artifacts without switching domains before promotion.

## Evidence (2026-10-26)

- SQL behavior:48 assertions +4 rollback/drift checks =52 pass on disposable PostgreSQL17. Baseline fixture contains selected definitions only from approved read-only run40318273032, no production rows. The server-only clock helper is overridden only inside the disposable tests for deterministic Bangkok boundaries; production uses now().
- Existing GP and coupon regression scripts pass in local PostgreSQL.
- Web unit tests426/426; Flutter analyze clean and36/36 tests; full web/Flutter production build passes.
- Synthetic Chromium mobile/desktop Food+Merchant browser22/22. Food pickup without delivery address and COD request payloads tested in real rendered checkout. No test signs in to a real account.
- Admin3/3 tests; production build and TypeScript pass. Web lint0errors17existing warnings; Admin0errors1existing warning.
- Release guard3/3 tests; catalog-only verification matches32 reviewed function definitions and protected schema/policy/trigger/anonymous-role invariants.

## Remaining release gates

Publish/review the application PR into feat/zoky-fulfill-001 and the separately scoped Admin PR; publish the workflow-only ops PR onto main with finalized candidate hashes and approved file lists. Main application source must NOT be released wholesale. A protected staging run must validate the real hosted staging baseline and migration before production. If it differs from the approved baseline, stop and review a staging preparation plan rather than overwrite it.

The Founder already requested production publication; no repeat chat authorization is needed. Required GitHub staging/production environment reviews and any branch-protection reviews still apply. Author-only release approval is prohibited by AGENTS.md / docs/engineering/GIT_WORKFLOW.md. No live customer rows/secrets have been read, no production migration or deployment performed. Hosted DB/browser integration and actual push delivery are not yet verified.
