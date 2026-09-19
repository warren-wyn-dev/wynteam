# WYNOS Web Beta1 — WYN-165/166 Username Border Fix + Thai Birth Date Selects Deploy

Date: 2026-09-19

## Release

- Scope: 2 fixes to the WYNOS Web Signup Step 1 screen, both raised by the Founder after WYN-163/164 went
  live. **WYN-165**: fixed the "ชื่อผู้ใช้" (username) field's border rendering broken/incomplete on
  production — a nested box-model collision between the field's custom wrapper `<div>` and the shared
  `.wyn-input` CSS class the `Input` component always applies (even with `bare`). **WYN-166**: replaced the
  hand-typed "วว / ดด / ปปปป" birth date text field with 3 Thai dropdowns (วัน/เดือน/ปี), after an initial
  native `<input type="date">` attempt was rejected by the Founder for displaying in English. Year dropdown
  shows Buddhist Era (พ.ศ.); stored/validated value stays Gregorian. No backend/schema/env changes.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- PR: [#546](https://github.com/warren-wyn-dev/wynteam/pull/546) — merged by warren-wyn-dev (Founder) at
  2026-09-19T08:52:07Z
- Commit deployed: merge commit `f841aabf62d3a5d6fc77e6a209100e7a1f9020e4` on `main`

## Trigger

Founder reported a real production visual bug (username field border missing, screenshot from a real
iPhone) → AI Debug Engineer fixed it (WYN-165). Same session, Founder asked for an easier birth date picker
→ AI proposed native date input vs. custom Thai selects, Founder chose native first, then rejected it after
seeing it render in English and asked for Thai (WYN-166, 2 rounds). Both went through AI QA & Security
independent re-testing (adversarial: invalid calendar dates, DOM-injected out-of-range values, a genuine
sessionStorage resume-after-reload simulation, dark mode, console error sweep) — **PASS**, no
CRITICAL/HIGH/MEDIUM findings. Full decision history: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-165,
WYN-166 and its follow-up). Full QA report: `.wyn/tasks/approved/WYN-166-signup-birthdate-thai-selects.md`,
`.wyn/tasks/bugs/WYN-165-signup-username-field-border-broken.md`.

## QA Status

**PASS** (2026-09-19, AI QA & Security, independent re-test — not just re-confirming Coding/Debug's own
checks). 21 automated adversarial checks plus a dark-mode/console-error sweep across all 7 auth screens, all
passed. No CRITICAL/HIGH/MEDIUM findings.

## Build Status

- Local sandbox: `npm run typecheck` / `npm run lint` / `npm run build` all green (re-verified independently
  by QA, not just trusting Coding/Debug's own report)
- CI on PR #546: `web`, `Admin (Next.js)`, `Flutter`, `Supabase PostgreSQL integration`, `schema.sql
  ordering`, `Supabase Edge Functions (Deno)`, Netlify preview deploy — all green
- `browser-qa` (runs the project's Playwright suite, 141 tests): **1 failure on first run** —
  `[webkit-iphone] › reference buttons connect the auth routes` (a pre-existing navigation test this change
  doesn't touch — Welcome→Login→ForgotPassword→back→Login→"สร้างบัญชีใหม่"→step-1 — failed only on the
  webkit-iphone browser project, passed on chromium-android and chromium-desktop for the identical test).
  Investigated per the CI-red protocol before accepting it: this exact test passed on the immediately-prior
  CI run (PR #545, commit `e3bbe468`, ~2.5 hours earlier) with no relevant code changed since, and this PR's
  diff never touches `WelcomeScreen`/`LoginScreen`/their navigation or button handlers. Re-ran the failed job
  once (`rerun_failed_jobs`) — **all 141 tests passed on re-run**, confirming a WebKit-specific CI flake, not
  a regression from WYN-165/166. Not fixed/changed as part of this deploy (nothing to fix — it's flake, not
  a bug in the diff); noted here for the record per the "never silent" rule on a CI-red finding.

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

`web/components/auth-flow/screens.tsx`, `web/app/auth-reference.css`,
`web/tests/browser/auth-reference-flow.spec.ts`, plus `.wyn/` process docs (DECISIONS.md, task files,
learning logs). No backend/RPC/schema changes, no new dependencies, no new environment variables.

## Deployment Result

Automatic: merging PR #546 into `main` triggered `wyn-158-production-deploy.yml`
([run #133, id 35433161442](https://github.com/warren-wyn-dev/wynteam/actions/runs/35433161442)), which
completed **success** end-to-end:

1. `Production preflight` — success (2026-09-19T08:52:33–08:53:12Z)
2. `Deploy to Vercel production` — success (2026-09-19T08:53:12–08:53:56Z)
3. `Verify production routes` — success (2026-09-19T08:53:56–08:53:58Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from
  the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder
- **Still needed from Founder**: open `wynos.online/signup/step-1` on a real phone/browser to confirm (1)
  the username field's border now renders as a complete rounded rectangle, and (2) the birth date field now
  shows 3 Thai dropdowns (วัน/เดือน/ปี) with Thai month names and a พ.ศ. year, since this log covers
  infrastructure-level success, not a human's read on the actual visual result

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a code-only Vercel deployment, CSS +
  component changes only (no data model impact). The DB-level `profile_private_date_of_birth_min_age`/
  `profile_private_date_of_birth_not_future` constraints are pre-existing and untouched.
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix branch → PR →
  merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- If either fix needs to be pulled without a full revert, they're independently revertable:
  - WYN-165: the inline `style` override on the username field's `<Input>` in `screens.tsx` can be reverted
    to its pre-fix state on its own (reintroduces the border bug, but touches nothing else).
  - WYN-166: the 3-select markup + `.wyn-select` CSS rule can be reverted back toward the WYN-163-era text
    field independently of WYN-165's change, since they're different fields on the same screen.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md`.
