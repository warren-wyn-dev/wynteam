# Zoky Merchant — Flutter frontend in the Food system

## Founder scope (2026-10-21)

Founder clarified that Merchant is the same system as Food, requested Flutter code and a usable web application, and instructed: “จัดการให้เรียบร้อยทั้งหมด พร้อมใช้งานเลยได้มั้ย”. This authorizes implementation, review, branch/PR delivery, testing and release preparation for Merchant in the existing wynteam repository. Production remains subject to the repository's enforced scoped-release guards; it does not authorize releasing unrelated main-branch features or weakening auth/security/release checks.

## Acceptance criteria

1. Flutter source is in `web/merchant_flutter`; no separate repository/database.
2. Existing WYNOS shared browser client and account gate exclusively own login, refresh, account switching, logout and push cleanup. No credentials/tokens or second auth session in Flutter.
3. Authorized merchants can list stores, edit menu/store, manage existing promotions, read server sales reports and process the order lifecycle, including manual-slip checks, cancellation and mandatory delivery photos.
4. Existing RPCs/RLS/validation/payment verification/storage remain authoritative. No production schema changes or live-data tests.
5. Realtime refresh and push subscription reuse existing services and worker. Legacy advanced tools and existing deep links remain reachable.
6. Flutter is embedded at `/merchant/flutter` with a disposable engine view. Root cutover is controlled, same Food/consumer deployment, and no unrelated origin changes.
7. Functional/error/permission/isolation/upload tests, browser smoke and reviewed build evidence precede a scoped release.

## Design

Next.js embeds Flutter in a host element and installs a typed JSON bridge around existing merchant services. Existing DeveloperRouteGate owns the session. The bridge rechecks identity/store authorization and scopes order evidence lookups before every operation. Flutter renders UI and never receives session credentials. Dedicated multi-view mounts remove cached UI/data when an account or route changes.

## Release boundary

Do not dispatch the general main production workflow while its final acceptance freeze is active. A deploy must use a reviewed Merchant-only production-based release artifact via the repository release process; keep root routing off until the compiled artifact and flow verification pass. Preserve the previous Merchant entry as recovery path; rollback requires Founder direction.

## Status

Production release completed on 2026-10-25 at 17:51:44 UTC after both owner-approved GitHub Production reviews. All jobs in run `40205781151` passed, and `merchant.wynos.online` now serves the reviewed Flutter-root artifact `dpl_AzSiNf7cK7GfS7qboogk3YtR1q73` / source `49e34d35657771949e26472fa14f1f4744955af0`. Public HTTP, anonymous mobile/desktop login and all production alias checks passed. Full evidence and limitations: `.wyn/logs/deployments/2026-10-25-zoky-merchant-ui-release.md`. Keep this task active pending the Founder's actual store-account acceptance; deployment success alone does not move it to completed.

Initial integration evidence (before the later final-home and account-exit follow-ups): `npm run check` passed (351 Node tests, 23 Flutter tests, analysis, lint/typecheck and production build), focused Chromium mobile/desktop browser QA passed 10/10 with synthetic fixtures, and release-freeze validation passed. Historical QA: `docs/qa/zoky-merchant-flutter/README.md`. Review PR: https://github.com/warren-wyn-dev/wynteam/pull/1229.

GitHub review follow-up fixed Stripe callback routing, no-slip receipt confirmation, preparation ETA, synchronous push permission, merchant-filtered store listing and deferred delivery-photo uploads. Residual private object after an ultimately failed delivery RPC and abandoned session is documented in the QA report; no immutable evidence policy was weakened.

## Founder visual follow-up (2026-10-23)

Match the live ZOKY consumer brand: pink gradient, berry actions, white surfaces and clear semantic status colors. See `docs/qa/zoky-merchant-flutter/brand-refresh.md`. The visual follow-up stays within the existing Merchant preview scope.

Founder supplied the original Merchant screens as a layout reference. Restored four primary destinations, sales/open-store home, category menu cards and a More tools page while keeping ZOKY pink. Verification and limits: `docs/qa/zoky-merchant-flutter/reference-layout.md`.

## Implemented home structure (2026-10-24)

Founder explicitly requested real UX/UI implementation from the latest structure. Flutter home now renders the actual selected-store status, sales, functional tool links, readiness checklist and customer-review aggregates. Validation/limitations: `docs/qa/zoky-merchant-flutter/real-home.md`. Production remains unchanged.

## Final home and explicit production instruction (2026-10-24)

Founder requested “เอาขึ้นเว็บจริง” and “ต่อ”. Final home now has eight pink 3D tool shortcuts, a same-row shop/bell header, actual editable status pill, smaller baseline-aligned sales fractions and readiness, without the lower quality card. Quality remains an actionable tool showing actual all-review data. Source validation: 374 Node +27 Flutter tests and 10/10 compiled mobile/desktop browser cases passed. Evidence: `docs/qa/zoky-merchant-flutter/final-home.md`.

PR #1229 merged the earlier integration, not these later UI refinements. Live Merchant shares Vercel project `web` with Food; the new scoped candidate uses actual live base `e6f577dc`, replacing the stale `0533fb` candidate. A narrow reviewed release workflow retains the production environment reviewer and the general release freeze. Source completion is not a claim that production changed.

## Stability QA follow-up (2026-10-25–26)

After publication the Founder reported instability and requested QA. Reproduced three issues: sign-in defaulted to the legacy dashboard, background refresh could permanently lock an open editor after Save, and realtime order changes arriving during a read could be dropped until the next poll. Scoped fixes preserve the shared session/backend, explicit return paths, other origins, permission checks and single-write guards. Evidence and remaining acceptance limits: `docs/qa/zoky-merchant-flutter/stability-2026-10-25.md`.

Production remains on the previously published `49e34d35657771949e26472fa14f1f4744955af0` during QA. Source repair, code integration and production publication are separate states; the old one-off release must not be redispatched after its live-base drift guard has become stale.
