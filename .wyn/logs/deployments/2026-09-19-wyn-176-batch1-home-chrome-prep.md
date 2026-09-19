# WYNOS Web Beta1 — WYN-176 Batch 1 (Home Chrome) Deploy Prep

Date: 2026-09-19
Status: **DONE — deployed and Founder-confirmed on production ("ชอบผ่าน")**

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
- PR: [#553](https://github.com/warren-wyn-dev/wynteam/pull/553) — opened 2026-09-19 after Founder confirmed
  "เปิด PR" in chat. **Merged by Founder** within seconds of opening, merge commit
  `48f7c41d03aaf1e36ad10286797ca95800a88207` on `main`.

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

PR #553 merged into `main` by Founder (commit `48f7c41d03aaf1e36ad10286797ca95800a88207`).
[WYN-158 Production Deploy run #140](https://github.com/warren-wyn-dev/wynteam/actions/runs/35457524004) —
**success**, all steps green: Production preflight, Deploy to Vercel production, Verify production routes
(completed 2026-09-19T17:17:23Z, total runtime ~2 minutes). Post-merge
[`CI` run #1394](https://github.com/warren-wyn-dev/wynteam/actions/runs/35457524012) on the same commit also
**success**.

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from
  the GitHub Actions runner) — success. Post-merge `main` CI independently confirmed green as well.
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder.
- **Founder-confirmed** (2026-09-19, in chat: "ชอบผ่าน"): tested on real production, likes it, passes. Batch 1
  is fully verified end-to-end.

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — CSS-only, fully reversible.
- If a regression is found: fix-forward with a corrective commit to `main`, which re-triggers
  `wyn-158-production-deploy.yml` automatically.
- A hard rollback requires explicit Founder direction per `.wyn/company/WEB_VERSION_CONTROL.md`.
