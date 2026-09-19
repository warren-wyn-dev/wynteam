# WYNOS Web Beta1 — WYN-175 Perceived Speed & Motion Deploy Prep

Date: 2026-09-19
Status: **DEPLOYED — production deploy workflow succeeded, waiting on Founder physical-device confirmation**

## Release

- Scope: **WYN-175** (WYN-174 Track 1) — skeleton loading for Search (users/clubs/discovery/drops tabs) and
  Notifications (replacing the generic spinner), `:active` press feedback (scale 0.96, 90ms) on search
  result rows and notification rows that had none, and route transitions changed from a 70ms opacity-only
  fade to a 220ms directional slide+fade (Founder-approved "Option B" from the preview artifact), with
  `prefers-reduced-motion` handling throughout.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- Branch: `claude/wynos-online-version-1pqqws`, 7 commits ahead of `origin/main`, clean fast-forward (no
  conflicts)
- PR: [#552](https://github.com/warren-wyn-dev/wynteam/pull/552) — opened 2026-09-19 after Founder confirmed
  "เปิดเลย" in chat. **Merged by Founder** (`warren-wyn-dev`) at 2026-09-19T16:46:00Z, ~44s after opening —
  same fast-merge pattern as PR #550/#551. Merge commit `497d836de4ad17049cd85fbc74184f1050c7e1d1` on `main`.

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

PR #552 merged into `main` by Founder (commit `497d836de4ad17049cd85fbc74184f1050c7e1d1`).
[WYN-158 Production Deploy run #139](https://github.com/warren-wyn-dev/wynteam/actions/runs/35456002342) —
**success**, all steps green: Production preflight, Deploy to Vercel production, Verify production routes
(completed 2026-09-19T16:48:05Z, total runtime ~2 minutes). Post-merge
[`CI` run #1391](https://github.com/warren-wyn-dev/wynteam/actions/runs/35456002373) on the same commit also
**success**. The PR's own CI (run #1390, on the final pushed commit) was also **success** before merge.

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from
  the GitHub Actions runner) — success. Post-merge `main` CI independently confirmed green as well.
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder.
- **Still needed from Founder**: open `wynos.online/search` and `wynos.online/notifications` on a real
  phone/browser and confirm: skeleton placeholders appear briefly instead of a spinner, tapping a
  search/notification row visibly presses before navigating, and switching pages shows a visible slide
  instead of an instant cut.

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — all changes are presentational
  (CSS/component-level), fully reversible.
- If a regression is found after deploy: fix-forward with a corrective commit to `main` (or a hotfix branch
  → PR → merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md` — AI must never roll back on its own.
