# WYNOS Web Beta1 — WYN-175 Perceived Speed & Motion Deploy Prep

Date: 2026-09-19
Status: **PREPARED — not yet opened as a PR, waiting on Founder**

## Release

- Scope: **WYN-175** (WYN-174 Track 1) — skeleton loading for Search (users/clubs/discovery/drops tabs) and
  Notifications (replacing the generic spinner), `:active` press feedback (scale 0.96, 90ms) on search
  result rows and notification rows that had none, and route transitions changed from a 70ms opacity-only
  fade to a 220ms directional slide+fade (Founder-approved "Option B" from the preview artifact), with
  `prefers-reduced-motion` handling throughout.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- Branch: `claude/wynos-online-version-1pqqws`, 7 commits ahead of `origin/main`, clean fast-forward (no
  conflicts)
- PR: **not opened yet** — this session's system instructions require an explicit Founder request before
  opening a pull request; asking Founder directly in chat before proceeding

## QA Status

**PASS** (round 2, independent re-verification) — 29/29 checks: the original 13-point harness (skeleton
dimension parity for all 4 row types, shimmer animation, `:active` press feedback tested with real
mouse-down/up on 3 row types, `prefers-reduced-motion` on both transition and shimmer), the new committed
regression spec's 6 assertions run live against a browser, and 10 additional end-to-end checks (HTTP 200 +
no console/page errors on `/`, `/search`, `/notifications`, `/welcome`; `PageTransition` mounts without
crashing; the new dev fixture route isn't linked from anywhere in the app). No CRITICAL/HIGH/MEDIUM findings.
Full detail: `.wyn/tasks/approved/WYN-175-web-perceived-speed-motion.md`.

One bug was found and fixed mid-pipeline: `NotificationSkeleton`/Discovery hashtag skeleton row heights
didn't match production (CSS cascade mismatch, not caught until QA rendered against the real cascade) — see
`.wyn/tasks/completed/WYN-175-skeleton-row-height-cascade-mismatch.md`.

## Build Status

Independently re-run just now by AI Deploy & DevOps (not trusting the QA/Coding reports alone):

- `npm run typecheck` — clean, 0 errors
- `npm run lint` — clean, 0 errors (3 pre-existing warnings in unrelated files, not introduced by this branch)
- `npm run build` (Next.js production build, Turbopack) — succeeded, exit 0, all 31 routes compiled including
  `/search`, `/notifications`, and the new `/dev/wyn-175-skeleton-fixture` test fixture

CI on the PR itself has not run yet since no PR is open.

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra, no new environment
variables, no new dependencies)

## Changes

`web/app/skeleton.css`, `web/app/phase3.css`, `web/app/dev/wyn-175-skeleton-fixture/page.tsx`,
`web/components/dev/wyn-175-skeleton-fixture.tsx`, `web/components/notifications-route.tsx`,
`web/components/search-route.tsx`, `web/components/ui/page-transition.tsx`,
`web/components/ui/skeleton.tsx`, `web/tests/browser/wyn-175-skeleton-parity.spec.ts`, plus `.wyn/` process
docs (product/design/decision/task/learning records). No backend/RPC/schema changes.

## Deployment Result

Not yet — waiting on Founder to say whether to open the PR now.

## Production Verification

Not applicable yet — no deploy has happened. Once merged, the existing `wyn-158-production-deploy.yml`
workflow (`WYN-158 Production Deploy`) will run automatically on merge to `main`, same as every prior web
deploy in this log folder. This sandbox's outbound network policy blocks `wynos.online`, so independent
post-deploy verification will rely on the workflow's own `Verify production routes` step; physical-device
confirmation (per the WYN-158 lesson that CI green ≠ confirmed working on a real phone) will still need the
Founder to open `wynos.online/search` and `wynos.online/notifications` on a real device and confirm: the
skeleton placeholders appear briefly instead of a spinner, tapping a search/notification row visibly presses
before navigating, and switching pages has a visible slide instead of an instant cut.

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — all changes are presentational
  (CSS/component-level), fully reversible.
- If a regression is found after deploy: fix-forward with a corrective commit to `main` (or a hotfix branch
  → PR → merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md` — AI must never roll back on its own.
