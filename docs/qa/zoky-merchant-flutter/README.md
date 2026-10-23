# Zoky Merchant Flutter verification — 2026-10-22

## Scope and result

Embedded Flutter UI in the existing Food/Next.js application, at `/merchant/flutter`. The existing account gate, backend authorization, RPCs, storage and service worker remain in use. No migrations or production configuration changes are included. Merchant-origin root routing defaults to the existing app; enabling Flutter requires the reviewed deployment flag.

Initial independent contract/security review exercised 16 bridge cases and 19 Flutter cases. Subsequent GitHub review identified four P1 and two P2 findings; the fixes and remaining limits are recorded below. These are source/mock assessments, not a production penetration test or hosted release approval.

## Review follow-up — 2026-10-23

- Stripe Connect `payments=return/refresh` root callbacks stay on the legacy payment setup handler.
- Pending manual no-slip payments require explicit received-money confirmation; Stripe stays server verified.
- Preparation ETA is selected on acceptance and serialized to the existing transition RPC.
- Push permission is captured synchronously during the tap, before async session work; identity is checked again before token registration.
- Store listing queries indexed user memberships/staff grants and server-filters store IDs/accounts; no public catalog scan or per-store authorization fan-out.
- Delivery selection stays local, canceled/replaced selections revoke their preview, and upload occurs only at final confirmation. Failed completion retains the uploaded path for retry. A final RPC failure followed by abandoning the session can still leave an unreferenced private object under the existing immutable evidence policy; no policy relaxation or unsafe deletion is introduced.

Focused regression evidence: **23 Flutter tests**, **34 bridge/loader/routing/font Node tests** plus **10 push helper tests**, and **10/10 Chromium mobile/desktop browser cases**. Browser cases cover both slip and explicit no-slip payment through ETA-bearing acceptance and delivery. The full `npm run check` follow-up **PASS** includes lint/typecheck, **351 Node tests**, Flutter analysis/**23 tests**, Flutter + Next.js production build and font guard.

On prior commit `a786b01`, GitHub Consumer Web, Merchant Browser QA, Signup Security and repository CI passed. General Phase 4 browser QA reported 1208 pass, 27 skip and one WebKit Home scroll/chrome failure (`home-scroll-chrome.spec.ts`, outside the Merchant source); this gate is not described as passing or bypassed. Protected preview access remains blocked by Vercel connector HTTP 403.

## Initial local checks

`npm run check`: **PASS** — ESLint (0 errors, 17 pre-existing warnings), TypeScript, **343 Node regression tests**, Flutter analysis (no issues), **19 Flutter tests**, production Flutter compilation, font/license guard and Next.js production build. Environment used a dummy Supabase URL/key; no live services were exercised. The Flutter compiler emits its SDK-level Cupertino icon-font warning; the UI uses Material icons and tested flows render successfully.

`python tools/check_wynos_release_freeze.py`: **PASS**, coordinated freeze preserved. Staged secret-pattern scan and `git diff --check`: **PASS**.

The dedicated `tests/merchant-browser` suite runs through `playwright.merchant-flutter.config.ts` after compilation; the general Next.js browser suite does not require a Flutter artifact.

## Browser evidence

`PLAYWRIGHT_CHROMIUM_EXECUTABLE=/path/to/chromium npm run qa:merchant-flutter`: **10/10 passed in the follow-up** (initial suite: 8/8) on Chromium mobile (Pixel 5) and desktop. Tests cover signed-out recovery, existing shared-session embedding, token-free bridge, view disposal, bundle failure recovery, and actual compiled Flutter rendering from slip review through payment confirmation, acceptance, preparation, dispatch and mandatory-photo completion. Missing evidence is rejected. The photo/payment/backend responses are synthetic fixtures; no real payment, account, customer data or database is used.

- [Mobile completed order](mobile-order-completed.png)
- [Desktop completed order](desktop-order-completed.png)

The screenshots contain synthetic customer/store details only. They show the compiled Flutter interface rather than a design mockup.

## Release boundary and remaining verification

Local verification is not a hosted staging result. Safari/WebKit rendering, camera/file chooser interaction on physical phones, hosted session/cookie behavior, push delivery, live RPC/RLS grants and private Storage policies still require the controlled staging/release procedure with approved test accounts. Advanced finance, staff, payment-provider and operating-hours tools remain in the existing `/merchant` UI.

The general production freeze remains enforced (`tools/check_wynos_release_freeze.py` passes; acceptance #1142 is still open). Do not deploy all of main. The existing ZOKY exception workflow authorizes a separately pinned release branch, not this feature branch. The preview workflow is manually gated and the production GitHub environment currently permits only main with a required reviewer. No protection or release guard has been weakened, no deployment has run, and the production alias has not moved.

## Operations / recovery

Build: `ZOKY_FLUTTER_SDK=/path/to/flutter-3.47.7 npm run build`, with pinned Flutter revision and enforced pub lockfile. Flutter analysis/tests run before compilation. Build output is generated and excluded from Git. No credentials go into Dart.

Verify the reviewed staged artifact at `/merchant/flutter`, its manifest and same-origin `/merchant-flutter/` assets. Keep `ZOKY_MERCHANT_FLUTTER_ENABLED` unset until hosted checks pass. Existing `/merchant` links remain available. Any production rollback follows the repository's Founder-controlled process; preserve the prior deployment identifier and monitor route/asset errors, failed RPCs and upload/payment errors without logging customer data or tokens.
