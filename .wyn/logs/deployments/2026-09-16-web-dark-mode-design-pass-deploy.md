# WYNOS Web Beta1 — Dark Mode / Design Consistency Deploy

Date: 2026-09-16

## Release

- Scope: dark mode via CSS variables + `prefers-color-scheme` (web-only exception to
  WYN-071's light-only scope), fixes for 8 latent "hardcoded white on a background
  that flips to white in dark mode" bugs this surfaced, canonical spacing/radius
  CSS custom properties (mirroring Flutter's `wyn_spacing.dart`) applied wherever an
  existing literal already matched. Font left untouched (system font stack, per
  standing 2026-08-30/09-03 decisions).
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#471](https://github.com/warren-wyn-dev/wynteam/pull/471) — merged by warren-wyn-dev (this session) at 2026-09-16T01:54:04Z
- Commit deployed: `df677ac4838475a3de47a92f775dd0cbd4a04336` (merge commit on `main`: `a66849ba88822f3f301008eae7d59e088dedd9d6`)

## Trigger

Founder asked for a premium/consistent design pass (font, spacing, radius, dark mode)
on WYNOS Web Beta1, per the usual "check existing code first" instruction. Audit found
font and dark mode both conflict with standing, repeatedly-reaffirmed Founder decisions
(system font not Fraunces/Inter — 2026-08-30/09-03; WYNOS ships light-only — WYN-071,
2026-08-24). Asked the Founder before implementing; chose dark mode only, keep the
system font. Recorded as a permanent decision in `.wyn/company/DECISIONS.md`.

## QA Status

PASS. `npm run check` (lint + `tsc --noEmit` + `next build`) green. Dark mode verified
visually with Playwright `colorScheme: 'dark'` emulation against `/welcome`, `/login`,
and `/dev/home-fixture` — correct contrast, no white-on-white regressions from the 8
latent bugs found and fixed. Full `chromium-desktop` Playwright run showed 4 failures,
confirmed via `git stash` + re-run against the unmodified baseline to be byte-for-byte
identical pre-existing failures, not caused by this change.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed / 26 failed,
  identical count and root causes already documented and stood down on in PR #468/#469
  (visual-snapshot font drift, a stale source-text assertion on `post-actions.tsx`,
  pre-existing CSS/test drift in `app/bottom-nav.css`, `next dev`-only artifacts).
  Full analysis: https://github.com/warren-wyn-dev/wynteam/pull/471#issuecomment-5690839719

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

14 files: `app/globals.css`, `app/design-system.css` (dark-mode `@media` blocks +
spacing/radius custom properties), `app/layout.tsx` (dark `themeColor`),
`app/{auth,chat,club,content}-reference.css`, `app/phase3.css`,
`app/club-detail-golden.css`, `app/bottom-nav.css`, `app/home.css`, `app/skeleton.css`,
`components/auth-flow/screens.tsx`. No backend/RPC/schema changes, no new dependencies,
no new environment variables. Flutter's `WynApp` `ThemeMode.light` is untouched — this
is a web-only exception to WYN-071.

## Deployment Result

Automatic: merging PR #471 into `main` triggered `wyn-158-production-deploy.yml`
([run 35045892242](https://github.com/warren-wyn-dev/wynteam/actions/runs/35045892242),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T01:54:26–01:54:46Z)
2. `Deploy to Vercel production` — success (2026-09-16T01:54:46–01:55:24Z)
3. `Verify production routes` — success (2026-09-16T01:55:24–01:55:26Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`,
  so independent verification isn't possible from here — same limitation as prior deploys
- **Still needed from Founder**: opening wynos.online with the OS set to dark mode (or
  via browser devtools' "emulate CSS prefers-color-scheme: dark") to confirm dark mode
  reads correctly on a real device, since this log covers infrastructure-level success,
  not a human's read on the actual visual result

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a straightforward
  code-only Vercel deployment, purely additive CSS (existing light-mode values are
  unchanged; dark values only apply under `prefers-color-scheme: dark`).
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix
  branch → PR → merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
  A hard rollback (`vercel rollback` or reverting DECISIONS.md's WYN-071 exception)
  requires explicit Founder direction per `.wyn/company/VERSION_CONTROL.md`.
- If dark mode itself needs to be pulled without a full revert: removing the
  `@media (prefers-color-scheme: dark)` blocks in `app/globals.css` and
  `app/design-system.css` reverts every surface to light-only with no other code changes.
