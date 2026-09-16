# WYNOS Web Beta1 — Disable Pinch-to-Zoom for Native App Feel Deploy

Date: 2026-09-16

## Release

- Scope: disable pinch-to-zoom on the WYNOS Web UI so the home-screen-
  launched (standalone) app behaves like a native app rather than a
  regular webpage.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#479](https://github.com/warren-wyn-dev/wynteam/pull/479) — merged by warren-wyn-dev (this session) at 2026-09-16T06:38:37Z
- Commit deployed: `64bdbc9f1f20a0c730755103a544896da1d4b07f` (merge commit on `main`: `f931dc4de0a964c751fbc8f802515f76168280c9`)

## Trigger

Founder reported: "ทำไม เว็ปเพิ่มไปโฮม แล้วซูมได้" (why can the web app,
after adding it to the home screen, still be zoomed?) — pinch-zoom
remained possible even when launched standalone from the home-screen
icon, unlike a real native app (and unlike the Flutter app this web
build mirrors).

## QA Status

PASS. Root cause: the `viewport` metadata export in `app/layout.tsx`
only ever set `width`, `initialScale`, and `viewportFit` — it never set
`maximumScale`/`userScalable`, so the browser's default pinch-zoom
behavior stayed enabled in every mode, including standalone.

Fix: added `maximumScale: 1, userScalable: false` to the `viewport`
export.

Verified with `npm run check` (lint + `tsc --noEmit` + `next build`,
clean) and by starting a local dev server and curling `/welcome` to
confirm the rendered `<meta name="viewport">` tag reads
`width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no,
viewport-fit=cover`.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed /
  26 failed, identical failing spec lines and root causes already
  documented and stood down on in #468/#469/#471/#473/#475/#477. Full
  analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/479#issuecomment-5693149123
- Flutter, Admin (Next.js), both Supabase jobs, schema.sql ordering: success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

1 file in `web/`: `app/layout.tsx` — `viewport` export now includes
`maximumScale: 1, userScalable: false`. No other files changed. No
backend/database/RLS/Edge Function changes.

## Deployment Result

Automatic: merging PR #479 into `main` triggered `wyn-158-production-deploy.yml`
([run 35064651732](https://github.com/warren-wyn-dev/wynteam/actions/runs/35064651732),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T06:39:05–06:39:42Z)
2. `Deploy to Vercel production` — success (2026-09-16T06:39:42–06:40:20Z)
3. `Verify production routes` — success (2026-09-16T06:40:20–06:40:23Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: reopen the app from its home-screen icon
  (or re-add it if a cached instance is still open) and confirm pinch
  gestures on the screen no longer zoom the UI

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a
  single-file metadata change.
- If disabling zoom causes an accessibility or usability complaint:
  revert `maximumScale`/`userScalable` in a follow-up commit to `main`,
  which re-triggers `wyn-158-production-deploy.yml` automatically. A
  hard rollback requires explicit Founder direction per
  `.wyn/company/VERSION_CONTROL.md`.
