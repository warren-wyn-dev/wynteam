# Zoky Merchant Flutter verification — 2026-10-22

## Scope and result

Embedded Flutter UI in the existing Food/Next.js application, at `/merchant/flutter`. The existing account gate, backend authorization, RPCs, storage and service worker remain in use. No migrations or production configuration changes are included. Merchant-origin root routing defaults to the existing app; enabling Flutter requires the reviewed deployment flag.

Independent contract/security review exercised 16 bridge cases and 19 Flutter cases. No unresolved CRITICAL/HIGH issue was reported in the reviewed source. This is a source/mock assessment, not a production penetration test or hosted release approval.

## Local checks

`npm run check`: **PASS** — ESLint (0 errors, 17 pre-existing warnings), TypeScript, **343 Node regression tests**, Flutter analysis (no issues), **19 Flutter tests**, production Flutter compilation, font/license guard and Next.js production build. Environment used a dummy Supabase URL/key; no live services were exercised. The Flutter compiler emits its SDK-level Cupertino icon-font warning; the UI uses Material icons and tested flows render successfully.

`python tools/check_wynos_release_freeze.py`: **PASS**, coordinated freeze preserved. Staged secret-pattern scan and `git diff --check`: **PASS**.

The dedicated `tests/merchant-browser` suite runs through `playwright.merchant-flutter.config.ts` after compilation; the general Next.js browser suite does not require a Flutter artifact.

## Browser evidence

`PLAYWRIGHT_CHROMIUM_EXECUTABLE=/path/to/chromium npm run qa:merchant-flutter`: **8/8 passed** on Chromium mobile (Pixel 5) and desktop. Tests cover signed-out recovery, existing shared-session embedding, token-free bridge, view disposal, bundle failure recovery, and actual compiled Flutter rendering from slip review through payment confirmation, acceptance, preparation, dispatch and mandatory-photo completion. Missing evidence is rejected. The photo/payment/backend responses are synthetic fixtures; no real payment, account, customer data or database is used.

- [Mobile completed order](mobile-order-completed.png)
- [Desktop completed order](desktop-order-completed.png)

The screenshots contain synthetic customer/store details only. They show the compiled Flutter interface rather than a design mockup.

## Release boundary and remaining verification

Local verification is not a hosted staging result. Safari/WebKit rendering, camera/file chooser interaction on physical phones, hosted session/cookie behavior, push delivery, live RPC/RLS grants and private Storage policies still require the controlled staging/release procedure with approved test accounts. Advanced finance, staff, payment-provider and operating-hours tools remain in the existing `/merchant` UI.

The general production freeze remains enforced (`tools/check_wynos_release_freeze.py` passes; acceptance #1142 is still open). Do not deploy all of main. The existing ZOKY exception workflow authorizes a separately pinned release branch, not this feature branch. The preview workflow is manually gated and the production GitHub environment currently permits only main with a required reviewer. No protection or release guard has been weakened, no deployment has run, and the production alias has not moved.

## Operations / recovery

Build: `ZOKY_FLUTTER_SDK=/path/to/flutter-3.47.7 npm run build`, with pinned Flutter revision and enforced pub lockfile. Flutter analysis/tests run before compilation. Build output is generated and excluded from Git. No credentials go into Dart.

Verify the reviewed staged artifact at `/merchant/flutter`, its manifest and same-origin `/merchant-flutter/` assets. Keep `ZOKY_MERCHANT_FLUTTER_ENABLED` unset until hosted checks pass. Existing `/merchant` links remain available. Any production rollback follows the repository's Founder-controlled process; preserve the prior deployment identifier and monitor route/asset errors, failed RPCs and upload/payment errors without logging customer data or tokens.
