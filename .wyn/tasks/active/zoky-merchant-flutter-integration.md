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

Implementation and local verification complete: `npm run check` passed (343 Node tests, 19 Flutter tests, analysis, lint/typecheck and production build), focused Chromium mobile/desktop browser QA passed 8/8 with synthetic fixtures, and release-freeze validation passed. Evidence and hosted-verification limitations: `docs/qa/zoky-merchant-flutter/README.md`. Production remains blocked by staging/release gates; no deployment or root cutover has occurred. PR reference will follow branch publication.
