# WYNOS Web Beta1 — Bottom Navigation Revert Deploy

Date: 2026-09-16

## Release

- Scope: Founder-directed correction of PR #468's bottom-nav icon change. Reverts
  `components/bottom-navigation.tsx` and `components/home/home-header.tsx` back to
  their pre-#468 (PR #467) state: bottom nav is **หน้าหลัก/คลับ/โพสต์/แชท/โปรไฟล์**
  (Home/Club/Post/Chat/Profile), header top-right corner is **ค้นหา/การแจ้งเตือน**
  (Search/Notification). No PWA/animation/touch-target changes from #468 are touched.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#469](https://github.com/warren-wyn-dev/wynteam/pull/469) — merged by warren-wyn-dev (this session) at 2026-09-16T01:22:18Z
- Commit deployed: `73babdb2965dbf7875cba3f8a0d4eb16d55ae79c` (merge commit on `main`: `802f3c447750b0a1ce98e5158ed9a5061af354ce`)

## Trigger

Founder reviewed the #468 bottom-nav change (Home/Search/Post/Notification/Profile,
Chat moved into the Home header) on a live production device via a screenshot and
rejected it, stating the bottom bar "ต้องมี" (must have) Home/Club/Post/Chat/Profile
with Search/Notification only in the header's top-right corner. Recorded as a
permanent decision in `.wyn/company/DECISIONS.md`.

## QA Status

PASS. `npm run check` (lint + `tsc --noEmit` + `next build`) green locally. Targeted
Playwright run of `tests/browser/parity.spec.ts`'s "source contracts" test (the
bottom-nav label/href contract, updated to match the reverted component) — passed.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed / 26 failed,
  identical count and root causes already documented and stood down on in PR #468
  (font-rendering drift in visual snapshots, a stale source-text assertion on
  `post-actions.tsx` predating both PRs, pre-existing CSS/test drift in
  `app/bottom-nav.css`, and `next dev`-only artifacts). Full analysis posted as a PR
  comment before merging: https://github.com/warren-wyn-dev/wynteam/pull/469#issuecomment-5690590848

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

5 files in `web/`: `components/bottom-navigation.tsx`, `components/home/home-header.tsx`,
`components/home/home-screen.tsx`, `components/home/home-fixture.tsx`,
`tests/browser/parity.spec.ts`. No backend/RPC/schema changes, no new dependencies,
no new environment variables.

## Deployment Result

Automatic: merging PR #469 into `main` triggered `wyn-158-production-deploy.yml`
([run 35043813672](https://github.com/warren-wyn-dev/wynteam/actions/runs/35043813672),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T01:22:36–01:23:11Z)
2. `Deploy to Vercel production` — success (2026-09-16T01:23:11–01:23:50Z)
3. `Verify production routes` — success (2026-09-16T01:23:50–01:23:52Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so I
  could not independently curl it myself — same limitation as prior deploys
- **Still needed from Founder**: opening wynos.online on a real phone to confirm the
  bottom nav now reads Home/Club/Post/Chat/Profile and the header shows Search/Notification

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a straightforward
  code-only Vercel deployment reverting two components to their known-good PR #467 state.
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix
  branch → PR → merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
  A hard rollback (`vercel rollback` or `git revert`) requires explicit Founder direction
  per `.wyn/company/VERSION_CONTROL.md`.
