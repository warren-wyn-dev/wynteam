# WYNOS Web Beta1 — WYN-170 Chat Inbox Premium Polish Deploy

Date: 2026-09-19

## Release

- Scope: **WYN-170** — Chat Inbox premium polish pass, following the Founder's "ออกแบบหน้าใหม่ได้ไหม
  มันไม่สวย" feedback through 6 rounds of iterative design (interactive HTML Artifact demos at each step,
  including one built from a real Instagram screenshot the Founder sent as a reference). Final scope: header
  title left-aligned, the requests entry point collapsed into a single always-visible "คำขอ" toggle that
  swaps content inline (replacing both the old modal and the WYN-169 conditional header pill), the compose
  ("เขียนข้อความใหม่") entry point removed from this screen entirely (starting a new conversation now goes
  through the existing profile-page "ส่งข้อความ" button), search bar reduced to 40px, chat rows reverted to
  a flat Instagram-style layout with press-scale kept, a `.is-solo` height modifier for the Notes row, and a
  permanent end-of-list marker fixing a real defect (a short inbox previously left a large dead blank area).
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- PR: [#550](https://github.com/warren-wyn-dev/wynteam/pull/550) (WYN-170 implementation) — merged
  2026-09-19T14:23:24Z by warren-wyn-dev (Founder), merged directly on GitHub only ~28 seconds after the PR
  was opened, before CI had finished running on the PR itself (see Process Note)
- Commits deployed: `315e3acc..f9b5563b` on `main`, merge commit `f9b5563b`

## Trigger

Founder saw the real Chat Inbox screen on production and said it wasn't pretty, without specifics. AI
Design audited the real code against the screenshot, found a concrete defect (no design existed for a
"few messages, not zero" list state), and proposed a narrow fix. Founder asked "โอเค แก้แค่นี้หรอ" —
prompting a Founder-approved scope expansion, then a Founder-sent Instagram reference screenshot reshaped
the row style and introduced the requests-tab concept, then further rounds of annotated-screenshot feedback
moved the toggle into the header, removed the compose button (after confirming via grep a working
alternative entry point exists via the profile page), and adjusted the title alignment and search bar size.
Full history: `.wyn/company/DECISIONS.md`, `.wyn/docs/design/wyn-170-chat-inbox-premium-polish.md`,
`.wyn/tasks/approved/WYN-170-chat-inbox-premium-polish.md`.

## QA Status

**PASS** — 12/12 test cases, verified against the real CSS cascade (7 files loaded in the exact
`app/layout.tsx` import order) via an isolated Playwright harness: title left-alignment, search bar exactly
40px, zero compose-button elements remaining, the requests toggle's full open/close cycle, press-scale
motion on both the toggle and chat rows (light/dark/reduced-motion), the divider line correctly suppressed,
the end-of-list marker, WCAG contrast on the toggle's new active state (18.97:1 light / 18.88:1 dark — no
WYN-168-style regression), and the Notes row's `.is-solo` modifier. No CRITICAL/HIGH/MEDIUM findings.

## Build Status

- Local sandbox: `npm run typecheck` / `npm run lint` / `npm run build` all green (AI Coding, then
  independently re-run by AI QA & Security and again by AI Deploy & DevOps before opening the PR)
- CI on PR #550: not fully observed before merge — see Process Note below
- CI on `main` post-merge (commit `f9b5563b`): **all green** — `schema.sql ordering`, `Admin (Next.js)`,
  `Supabase Edge Functions (Deno)`, `Supabase PostgreSQL integration`, `Flutter` all success
- `WYN-158 Production Deploy` workflow (run #137): **all green** — preflight, Vercel production deploy,
  route verification all success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

`web/components/chat-inbox-parity.tsx`, `web/app/chat-notes.css` (the interaction/state and CSS changes
described above). Plus `.wyn/` process docs. No backend/RPC/schema changes, no new dependencies, no new
environment variables.

## Deployment Result

[Run #137](https://github.com/warren-wyn-dev/wynteam/actions/runs/35448587838) (PR #550 merge, commit
`f9b5563b`) — **success**, all steps green: preflight, Vercel production deploy, route verification. Full
`main`-branch `CI` workflow ([run #1386](https://github.com/warren-wyn-dev/wynteam/actions/runs/35448587846))
also finished green on the same commit, confirmed after the merge (see Process Note).

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from
  the GitHub Actions runner) — success. Post-merge `main` CI also independently confirmed green.
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder
- **Still needed from Founder**: open `wynos.online/chat` on a real phone/browser and confirm the new
  header layout (title left-aligned, single "คำขอ" toggle button), that tapping "คำขอ" correctly swaps to
  the requests list inline, that no way to compose a new message remains on this screen, and that the chat
  list no longer ends in a large blank area when short

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — 2 files, both fully reversible.
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix branch → PR →
  merge), which re-triggers `wyn-158-production-deploy.yml` automatically.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md`.

## Process Note

Founder merged PR #550 directly on GitHub themselves, ~28 seconds after AI Deploy & DevOps opened it —
before the PR's own CI checks had finished running (still `in_progress` at merge time). This is within the
Founder's full authority as final decision maker; AI Deploy & DevOps did not merge it and had not yet asked
for approval this round. Since the merge happened ahead of CI completion, AI Deploy & DevOps's job shifted
to confirming CI was actually green **after the fact**, on the post-merge `main` commit and the production
deploy workflow it triggered — both were monitored to completion and came back fully green, so no follow-up
fix PR was needed this time. Recorded here as a reminder (same lesson as the 2026-09-19 WYN-167/168 log):
"the PR merged" is not the same as "CI is green" — both must be checked independently, especially when a
merge happens faster than CI can finish.
