# WYNOS Web Beta1 — WYN-167/168 Home Feed Motion + Dark-Mode Contrast Fix Deploy

Date: 2026-09-19

## Release

- Scope: **WYN-167** — extended WYN-163's Apple-style press-scale motion to 3 Home-feed-only elements (the
  follow pill, 3 header icon buttons, and the tab underline indicator, which now fades instead of snapping)
  per the WYN-160 rollout plan's own next step. No size/color/spacing change — Home's compact density
  untouched, and the shared `.route-primary`/`.route-secondary` classes (used by 13 other pages) were kept
  explicitly out of scope. **WYN-168** — found while dark-mode-testing WYN-167: the Follow button's
  background was hardcoded (`#f1f1f3`), not theme-aware, producing a 1.13:1 contrast ratio in dark mode
  (WCAG AA needs 4.5:1) — effectively unreadable, live on production since the 2026-09-16 dark mode pass,
  unrelated to WYN-167. Fixed using existing dark-mode tokens (no new color invented): contrast now 18.88:1
  (default state) and 5.91:1 (`.is-requested` state).
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- PRs: [#547](https://github.com/warren-wyn-dev/wynteam/pull/547) (WYN-167/168 implementation, merged
  2026-09-19T09:42:24Z) and [#548](https://github.com/warren-wyn-dev/wynteam/pull/548) (CI fix, merged
  2026-09-19T09:58:15Z) — both merged by warren-wyn-dev (Founder)
- Commits deployed: `f841aabf..d6cf8276` on `main`, primarily merge commits `248a638b` (PR #547) and
  `d6cf8276` (PR #548)

## Trigger

Founder asked to extend WYN-163's Apple-style redesign beyond onboarding, chose Home feed first. AI Design
scoped it narrowly (motion only, 3 Home-only classes) after auditing that WYN-140/DS-003 (prior Home design
docs) are Flutter-only and inapplicable now that Flutter is paused. Founder approved the scope. During QA's
adversarial dark-mode testing, found WYN-168 (unrelated pre-existing contrast bug) and Founder said to fix it
before deploying ("แก้ปัญหาก่อน ห้ามข้าม"). Both went through full Design → Coding/Debug → QA rounds — see
`.wyn/company/DECISIONS.md` (2026-09-19), `.wyn/docs/design/wyn-167-home-feed-apple-style-extension.md`,
`.wyn/tasks/bugs/WYN-168-home-follow-pill-dark-mode-contrast.md`.

## QA Status

**PASS** on both, independently re-tested twice (once before the CI-fix round, once implicitly re-verified
via the CI fix itself). No CRITICAL/HIGH/MEDIUM findings remaining.

## Build Status

- Local sandbox: `npm run typecheck` / `npm run lint` / `npm run build` all green throughout every round
- CI on PR #547: `web`, `Admin (Next.js)`, `Flutter`, `Supabase PostgreSQL integration`, `schema.sql
  ordering`, `Supabase Edge Functions (Deno)`, Netlify preview — all green. `browser-qa` finished red
  **after** the Founder had already merged (10 real failures — not a flake this time): 3 separate
  source-lock/pixel-parity test files independently pinned the literal string `"background: #f1f1f3"` from
  `home.css` as a drift contract, and WYN-168 intentionally changed that value. Filed as CI-red work,
  investigated, root-caused, and fixed in **PR #548**.
- PR #548 round 1: updated all 3 lock tests to expect the new value. A Codex bot review then correctly
  flagged that the fix was **vacuous** — `home.css` already had an unrelated `.wyn-post-media-item` rule
  using the same `background: var(--wyn-surface)` value, so the bare substring check would still pass even
  if the follow-pill's background were reverted to a hardcoded color. Verified the finding was correct by
  simulating the exact revert; fixed by combining the assertion with the immediately preceding
  `border-radius: var(--wyn-radius-full);` line, which is unique to the follow-pill rule (confirmed 1
  occurrence). Replied to and resolved the review thread.
- PR #548 round 2: all 11 checks green, including `browser-qa`.

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

`web/app/home.css` (WYN-167's 3 motion additions + WYN-168's 2-value token swap),
`web/tests/browser/home-visual-parity.spec.ts` (new dark-mode contrast regression test),
`web/tests/browser/founder-visual-parity.spec.ts`, `web/tests/browser/parity.spec.ts`,
`web/tests/browser/pixel-parity-pass-2.spec.ts` (3 source-lock assertions updated + scoped), plus `.wyn/`
process docs. No backend/RPC/schema changes, no new dependencies, no new environment variables.

## Deployment Result

Two automatic production deploys, both triggered by merges into `main`:

1. [Run #134](https://github.com/warren-wyn-dev/wynteam/actions/runs/35435438633) (PR #547 merge, commit
   `248a638b`) — **success**: preflight (09:42:50–09:43:29), Vercel deploy (09:43:29–09:44:11), route
   verification (09:44:11–09:44:13)
2. [Run #135](https://github.com/warren-wyn-dev/wynteam/actions/runs/35436120841) (PR #548 merge, commit
   `d6cf8276`) — **success**, all 3 steps green (test-only change, no functional code touched)

The currently-live production code corresponds to run #135 (the final, CI-fully-green state).

## Production Verification

- **AI-confirmed**: both production workflow runs' own `Verify production routes` steps (real network access
  from the GitHub Actions runner) — success on both
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder
- **Still needed from Founder**: open `wynos.online/home` (or equivalent) on a real phone/browser to confirm
  (1) the follow pill, header icons, and tab underline now have visible press/fade motion, and (2) with dark
  mode on, the "ติดตาม" button text is now clearly readable — since this log covers infrastructure-level
  success, not a human's read on the actual result

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — CSS + test-only changes, no data model
  impact.
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix branch → PR →
  merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- WYN-167 and WYN-168 are independently revertable: WYN-167's 3 `transition`/`:active` additions (plus the
  `prefers-reduced-motion` block) can be reverted on their own without touching WYN-168's 2-value token swap,
  and vice versa — they're in different, non-overlapping lines of the same file.
- A hard rollback (`vercel rollback` or reverting a merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md`.

## Process Note

This deploy round surfaced 2 real, non-flake CI failures post-merge (WYN-168's own lock-test breakage, then
the Codex-flagged vacuous-fix issue) — both were root-caused and fixed via follow-up PRs (#548, then a
same-PR push) rather than skipped or dismissed as flake. Recorded as a reminder that "the PR merged and
production deploy succeeded" is not the same as "CI is actually green" — both must be checked independently,
which is why this log distinguishes the two PRs and their respective CI histories explicitly.
