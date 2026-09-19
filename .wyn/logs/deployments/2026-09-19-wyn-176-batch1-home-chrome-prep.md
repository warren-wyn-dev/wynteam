# WYNOS Web Beta1 — WYN-176 Batch 1 (Home Chrome) Deploy Prep

Date: 2026-09-19
Status: **PREPARED — not yet opened as a PR, waiting on Founder**

## Release

- Scope: **WYN-176 Batch 1** (of a multi-batch visual design rollout, WYN-174 Track 2) — extends WYN-163's
  Apple-style squircle press-feedback (`scale(0.96)`, 160ms spring) and a modest, proportional radius bump to
  Home's non-Flutter-locked chrome: the side drawer (shared with Notifications), its close button, action
  sheet rows, and the `.route-primary`/`.route-secondary`/`.route-pill`/`.route-more` button family (shared
  with Search/Notifications). Does **not** touch the Flutter-parity-locked post card or bottom nav dock, and
  does not include the remaining WYN-176 batches (Composer, Chat, Profile/Settings, Search/Notifications/Club)
  — those haven't started.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- Branch: `claude/wynos-online-version-1pqqws`, diverged from `origin/main` at merge-base `c22b184` (main's
  only extra commit there is `497d836`, the merge of this same branch's own prior PR #552 — no unrelated
  changes landed on `main` since, confirmed via `git diff origin/main...HEAD`, which shows only this
  branch's own new files). PR would merge cleanly, no conflicts expected.
- PR: not opened yet — waiting on Founder confirmation before creating one (per this session's own rule
  requiring an explicit ask)

## QA Status

**PASS** (independent re-verification) — 32/32 checks: console/HTTP error sweep on live dev server (`/`,
`/notifications`, `/search`, `/welcome`), computed border-radius against the full 38-file CSS cascade, real
mouse-down/up press feedback on all 8 touched elements plus release verification, confirmation that
`.wyn-redrop-sheet-option` and `.wyn-home-header-action` were left untouched, and `prefers-reduced-motion`
on 4 elements. No CRITICAL/HIGH/MEDIUM findings, no security findings. Full detail:
`.wyn/tasks/active/WYN-176-visual-design-rollout-squircle.md`.

## Build Status

Independently re-run just now by AI Deploy & DevOps:

- `npm run typecheck` — clean, 0 errors
- `npm run lint` — clean, 0 errors (3 pre-existing warnings in unrelated files)
- `npm run build` (Next.js production build) — succeeded, exit 0, all routes compiled

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra, no new environment
variables, no new dependencies)

## Changes

`web/app/parity-final.css` (drawer identity + menu row radius/press-feedback, drawer close button
press-feedback), `web/app/parity-audit.css` (action sheet row press-feedback), `web/app/phase3.css`
(`.route-primary`/`.route-secondary`/`.route-pill`/`.route-more` press-feedback). Plus `.wyn/` process docs.
CSS-only diff — no `.tsx` component files, no backend/RPC/schema changes.

## Deployment Result

Not yet — waiting on Founder to say whether to open the PR now.

## Production Verification

Not applicable yet. Once merged, `wyn-158-production-deploy.yml` runs automatically, same as every prior web
deploy. This sandbox can't reach `wynos.online`, so independent post-deploy verification relies on the
workflow's own `Verify production routes` step; physical-device confirmation will still need the Founder to
open the side drawer on `wynos.online` (from Home or Notifications) and a post's action sheet, and confirm
rows visibly press when tapped and the drawer's rounded corners look slightly more pronounced than before.

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — CSS-only, fully reversible.
- If a regression is found: fix-forward with a corrective commit to `main`, which re-triggers
  `wyn-158-production-deploy.yml` automatically.
- A hard rollback requires explicit Founder direction per `.wyn/company/WEB_VERSION_CONTROL.md`.
