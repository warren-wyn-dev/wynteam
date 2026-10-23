# Merchant-only release candidate

Candidate branch: `release/zoky-merchant-flutter-20261022`.

Parent: `0533fb3649f3c327f451bc95832674d63c0f6873` (`release/zoky-web-20261018`). This candidate carries the reviewed Merchant source from PR #1229 onto the existing production-based ZOKY release lineage. It does not merge main. Existing ZOKY origins, legacy Food redirect/cleanup and release-specific regressions are preserved. The candidate changes only `web/`, `docs/` and `.wyn/`; it changes no workflow, edge function, database or infrastructure configuration. The unrelated homepage banner/featured-store modules remain absent.

Verification on this release base: `npm run check` PASS — 367 Node regressions, Flutter analysis, 23 Flutter tests, Flutter + Next.js production builds and font guard; dummy public configuration only. The routing test loads this release's `food-origin` module and verifies that Merchant's flag does not change either phase of the existing Food redirect. Focused compiled-renderer/shared-auth Chromium mobile/desktop browser QA passed **10/10** on this candidate. Whitespace and release-delta path checks passed.

This is a candidate for review, not a deployed or approved release. The currently pinned production release branch has not been changed. `ZOKY_MERCHANT_FLUTTER_ENABLED` remains off by default. The existing general release freeze and environment protection remain intact. The existing one-time ZOKY exception must not be assumed to approve Merchant cutover automatically: record the exact reviewed candidate SHA and staging evidence through the existing Founder-controlled release process before promoting it or enabling the root flag.

Hosted preview verification is currently blocked by Vercel connector HTTP 403 for the existing `wynteam-gesb` project/team. No access or deployment protection setting was weakened. Keep the existing `/merchant` entry and previous production deployment available for Founder-directed recovery.

Source review follow-up from `e2ea20d1` is included: Stripe callback routing, explicit manual receipt confirmation, preparation ETA, synchronous Push permission, membership-filtered stores and deferred photo upload. The immutable-storage residual on abandoned failed completions remains documented for review. No production deployment has occurred.
