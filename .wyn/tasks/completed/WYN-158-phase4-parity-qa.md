# WYN-158 — Phase 4 UX/UI Parity + QA

Status: COMPLETE (superseded by production cutover — see closing note, 2026-09-20)
Date: 2026-09-13
Owner: Founder

Phase 4 starts only after Phase 3 is merged. It keeps the Next.js consumer web developer-gated and does not authorize public production cutover.

## Scope

- UX/UI parity across Home, Search/Discovery, Profile, Notifications, Chat, Settings and deep-link surfaces.
- Responsive/safe-area behavior for iPhone-sized, Android-sized and desktop viewports.
- Internal navigation through the Next.js router; no full-page reloads for app-local routes.
- Browser-native DOM/system-font rendering; no Apple/SF Pro font assets and no `@font-face`.
- Automated browser smoke/stress coverage for route shells, navigation, layout overflow and reload/crash regressions.
- Re-run lint, TypeScript, production build, font/license guard and full repository CI.

## Release boundary

- `wynos.online` remains on the current Flutter production deployment during Phase 4.
- Physical iPhone confirmation is a distinct QA gate and cannot be substituted by automated browser emulation.
- Production domain cutover remains Phase 5 and requires explicit Founder approval.

## Closing note (2026-09-20, web-beta1-readiness audit)

Phase 5 cutover happened and `wynos.online` has been the live Next.js production site since (see `.wyn/tasks/completed/WYN-158-nextjs-consumer-web-migration.md`, Phase 5 readiness — COMPLETE). This scope doc's boundary is fully superseded by that cutover. Moved to `.wyn/tasks/completed/`.
