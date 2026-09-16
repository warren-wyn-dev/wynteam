# WYNOS Web Beta1 — apple-mobile-web-app-capable Fix Deploy

Date: 2026-09-16

## Release

- Scope: restores the `apple-mobile-web-app-capable` meta tag so a home-screen
  icon added via Safari's "Add to Home Screen" launches WYNOS standalone
  (no browser chrome) instead of opening inside Safari like a bookmark.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#473](https://github.com/warren-wyn-dev/wynteam/pull/473) — merged by warren-wyn-dev (this session) at 2026-09-16T05:04:59Z
- Commit deployed: `00d7c2deb14b97ad5c4d371dc2e9565f3aa693e1` (merge commit on `main`: `6948cb75e64796d9b23f9015decf15326ec81d97`)

## Trigger

Founder reported (with screenshots) that opening WYNOS from its home-screen
icon on iOS still showed Safari's own address bar/toolbar instead of
launching full-screen, even after deleting and re-adding the icon. Root
cause found by inspecting the rendered `<head>` directly: this Next.js
version's `appleWebApp` metadata option only emits the generic
`mobile-web-app-capable` tag (confirmed against this repo's own bundled
docs, `node_modules/next/dist/docs/01-app/03-api-reference/04-functions/
generate-metadata.md`) — not `apple-mobile-web-app-capable`, which iOS
Safari specifically needs to launch a home-screen icon standalone. Every
"Add to Home Screen" since the PWA work shipped (PR #468) would have saved
a plain bookmark instead.

## QA Status

PASS. `npm run check` (lint + `tsc --noEmit` + `next build`) green. Verified
the rendered production HTML head now includes both
`<meta name="apple-mobile-web-app-capable" content="yes">` and
`<meta name="mobile-web-app-capable" content="yes">`.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 92 passed / 25
  failed, one fewer than the usual 26 (the webkit-only
  `auth-reference-flow.spec.ts:63` cold-start timeout, previously documented
  as timing-dependent, didn't trigger this run). Every remaining failure is
  the same pre-existing set root-caused in #468/#469/#471; none touches
  `app/layout.tsx`, the only file this PR changed. Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/473#issuecomment-5692320892

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

1 file: `app/layout.tsx` (adds `apple-mobile-web-app-capable: "yes"` via
`metadata.other`). No backend/RPC/schema changes, no new dependencies, no
new environment variables.

## Deployment Result

Automatic: merging PR #473 into `main` triggered `wyn-158-production-deploy.yml`
([run 35058106338](https://github.com/warren-wyn-dev/wynteam/actions/runs/35058106338),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T05:05:33–05:06:09Z)
2. `Deploy to Vercel production` — success (2026-09-16T05:06:09–05:06:48Z)
3. `Verify production routes` — success (2026-09-16T05:06:48–05:06:52Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: after this deploys, **remove the existing
  WYNOS home-screen icon and re-add it** via Safari's Share → Add to Home
  Screen (iOS caches the web-clip type from when the icon was first added,
  so the stale bookmark-type icon will not self-heal), then confirm the new
  icon launches full-screen with no address bar/toolbar

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a single
  additive meta tag, purely additive (does not remove or change any
  existing tag).
- If a regression is found: fix-forward with a corrective commit to `main`
  (or a hotfix branch → PR → merge), which re-triggers
  `wyn-158-production-deploy.yml` automatically. A hard rollback requires
  explicit Founder direction per `.wyn/company/VERSION_CONTROL.md`.
