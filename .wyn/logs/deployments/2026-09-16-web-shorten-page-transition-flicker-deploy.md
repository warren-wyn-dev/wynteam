# WYNOS Web Beta1 — Shorten Page-Transition Fade Deploy

Date: 2026-09-16

## Release

- Scope: shorten the root page-transition fade so navigating between
  pages no longer flickers, now that content itself loads instantly.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#485](https://github.com/warren-wyn-dev/wynteam/pull/485) — merged by warren-wyn-dev (this session) at 2026-09-16T07:55:05Z
- Commit deployed: `043fec0853e21ccd2a1c71cd2f74c09780481e51` (merge commit on `main`: `1d8df750bf68b2fc6bfaa06f87af0a921084fb5e`)

## Trigger

After PRs #481/#483 (remount-cache fixes), Founder reported: "มันดีขึ้น
แค่เวลากดเปลี่ยนหน้า กระพริบ นิดหน่อย ไม่ถึงวินาที" (it's better, just
a slight flicker under a second when switching pages).

## QA Status

PASS. `components/ui/page-transition.tsx` wraps every route in an
`AnimatePresence mode="wait"` opacity cross-fade. `mode="wait"` runs the
outgoing page's exit fade and the incoming page's enter fade
**sequentially**, not together, so the previous `0.16s` duration meant
a ~`0.32s` dip-to-transparent-and-back on every single navigation. With
content now loading instantly (per PRs #481/#483), that fade dip was
the only thing left reading as a "flicker."

Fix: shortened the duration to `0.07s`. `mode="wait"` and the
opacity-only animation are both kept exactly as before — the
component's own comment documents why: animating `transform` would
create a new containing block for the bottom nav's `position: fixed`,
making it jump during the transition.

Verified with `npm run check` (lint + `tsc --noEmit` + `next build`,
clean — only the 2 pre-existing baseline warnings) and a full
`chromium-desktop` Playwright run against the correct browser binary:
same 8 pre-existing baseline failures, no new ones.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed /
  26 failed, identical failing spec lines and root causes already
  documented and stood down on in #468 through #483. Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/485#issuecomment-5694000201
- Flutter, Admin (Next.js), both Supabase jobs, schema.sql ordering: success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

1 file in `web/`: `components/ui/page-transition.tsx` — fade
`transition.duration` reduced from `0.16` to `0.07`. No other files
changed. No backend/database/RLS/Edge Function changes.

## Deployment Result

Automatic: merging PR #485 into `main` triggered `wyn-158-production-deploy.yml`
([run 35070988092](https://github.com/warren-wyn-dev/wynteam/actions/runs/35070988092),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T07:55:25–07:55:49Z)
2. `Deploy to Vercel production` — success (2026-09-16T07:55:49–07:56:28Z)
3. `Verify production routes` — success (2026-09-16T07:56:28–07:56:32Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: switch between pages a few times and
  confirm the brief flicker reported earlier is gone or no longer
  noticeable

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a
  single-line animation-timing tweak.
- If the shorter duration ever feels too abrupt: adjust
  `transition.duration` in a follow-up commit to `main`, which
  re-triggers `wyn-158-production-deploy.yml` automatically. A hard
  rollback requires explicit Founder direction per
  `.wyn/company/VERSION_CONTROL.md`.
