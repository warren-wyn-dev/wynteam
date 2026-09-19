# WYNOS Web Beta1 — WYN-163/164 Onboarding Button Redesign Deploy

Date: 2026-09-19

## Release

- Scope: Apple-inspired squircle redesign of the WYNOS Web onboarding/auth screens (Welcome, Login,
  Signup step 1/2, Onboarding Profile, Forgot Password) + `/account/add` brought into the same treatment.
  Buttons/inputs moved from full-pill to squircle (24px/18px radius, 58px/56px tall), unified 32px/800
  screen headlines, a CSS press-scale on `:active`, an enlarged WYNOS logo mark on Welcome/Login, and a
  real Google "G" icon + reordered buttons on the Welcome screen's Google sign-in option. Colors unchanged
  (white/black/gray only). No backend/schema/env changes.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- PR: [#545](https://github.com/warren-wyn-dev/wynteam/pull/545) — merged by warren-wyn-dev (Founder) at
  2026-09-19T08:01:26Z
- Commit deployed: merge commit `a18f342cecfe19c16c07f8dae5f932fafd16b705` on `main`

## Trigger

Founder asked to redesign WYNOS's onboarding buttons from scratch ("เริ่มจาก0"), starting with color, then
shape. Went through full Design → Coding → QA (round 1: FAIL, 2 findings) → Debug (WYN-164) → QA (round 2:
PASS) → Deploy. Full decision history: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-163 rounds 1-8), design
spec: `.wyn/docs/design/wyn-163-onboarding-button-redesign.md`.

## QA Status

**PASS** (round 2, 2026-09-19). Round 1 found 2 MEDIUM findings (no security/functional impact) — `/account/add`
silently inheriting the new button sizing without the matching icon/headline, and the Welcome headline
wrapping mid-word at 320px — both fixed by AI Debug Engineer (WYN-164) and re-verified. Full report:
`.wyn/tasks/approved/WYN-163-onboarding-button-redesign.md`, `.wyn/tasks/bugs/WYN-164-onboarding-redesign-followup.md`.

## Build Status

- Local sandbox: `npm run typecheck` / `npm run lint` / `npm run build` all green
- CI on PR #545: all 8 relevant checks green — `web`, `browser-qa` (runs the project's Playwright suite,
  including the 2 new regression tests this change added), `Flutter`, `Admin (Next.js)`,
  `Supabase PostgreSQL integration`, `schema.sql ordering`, `Supabase Edge Functions (Deno)`, Netlify
  preview deploy

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

4 files: `web/app/auth-reference.css`, `web/components/auth-flow/screens.tsx`,
`web/components/account-add-route.tsx`, `web/tests/browser/auth-reference-flow.spec.ts`. No backend/RPC/
schema changes, no new dependencies, no new environment variables.

## Deployment Result

Automatic: merging PR #545 into `main` triggered `wyn-158-production-deploy.yml`
([run #132, id 35430883451](https://github.com/warren-wyn-dev/wynteam/actions/runs/35430883451)), which
completed **success** end-to-end:

1. `Production preflight` — success (2026-09-19T08:01:48–08:02:19Z)
2. `Deploy to Vercel production` — success (2026-09-19T08:02:19–08:03:04Z)
3. `Verify production routes` — success (2026-09-19T08:03:04–08:03:06Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access
  from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online` (confirmed via a
  direct `curl` attempt just now, connection failed/timed out) — same limitation as every prior web deploy
  in this log folder
- **Still needed from Founder**: open `wynos.online/welcome` (and `/login`, `/account/add`) on a real
  phone/browser to confirm the redesign reads correctly — bigger logo, squircle buttons, Google icon,
  reordered buttons — since this log covers infrastructure-level success, not a human's read on the actual
  visual result

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a code-only Vercel deployment, CSS +
  component changes only (no data model impact).
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix branch → PR →
  merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- If the redesign itself needs to be pulled without a full revert: `web/app/auth-reference.css`'s
  `.btn-primary`/`.btn-outline`/`.field .wyn-input`/`.field textarea` block and the `transform`/
  `@media (prefers-reduced-motion...)` rules can be reverted to their pre-WYN-163 values (999px radius,
  50px/44px height) independently of the headline/logo/Google-icon changes in `screens.tsx`/
  `account-add-route.tsx`, which are separate, independently-revertable edits.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md`.
