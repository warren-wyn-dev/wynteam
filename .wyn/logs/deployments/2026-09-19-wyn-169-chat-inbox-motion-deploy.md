# WYNOS Web Beta1 — WYN-169 Chat Inbox Motion Deploy

Date: 2026-09-19

## Release

- Scope: **WYN-169** — extended WYN-163/167's Apple-style press-scale motion to the WYNOS Web Chat Inbox
  header. Scoped to exactly 2 buttons confirmed (via grep) to be declared solely in `web/app/chat-notes.css`,
  used only by `chat-inbox-parity.tsx`: `.wyn-chat-compose-action` (✎ new-message icon) and
  `.wyn-chat-requests-link` ("คำขอ N" requests pill). Both get `transform: scale(0.96)` on `:active` with the
  same `160ms cubic-bezier(0.34, 1.56, 0.64, 1)` transition used in WYN-163/167, plus a new
  `@media (prefers-reduced-motion: reduce)` block (this file had none before). The back button
  (`.flutter-chat-header-action`) was intentionally left untouched — its CSS is declared redundantly across 4
  separate files, needing its own cascade audit first.
- Version: within **WYNOS Web Beta1** — no version bump requested by Founder
- PR: [#549](https://github.com/warren-wyn-dev/wynteam/pull/549) (WYN-169 implementation, merged
  2026-09-19T13:15:07Z by warren-wyn-dev/Founder)
- Commits deployed: `d6cf8276..315e3acc` on `main`, merge commit `315e3acc`

## Trigger

Founder asked to continue the Apple-style redesign rollout to the Chat inbox screen next, explicitly skipping
the Composer step WYN-160's original plan had listed before Chat. AI Design audited the real codebase (not
the older WYN-159 backlog spec, which references a Cyan brand color that doesn't exist anywhere in the web's
actual `--wyn-*` token system) and scoped WYN-169 narrowly, the same way WYN-167 was scoped for Home feed.
Founder asked to see an interactive demo before approving scope (`ขอดูรูปก่อนตัดสินใจ`) — an HTML Artifact
using the real CSS values was built and shared, then Founder approved the scope ("เห็นด้วย") and separately
confirmed wanting WYN-159 revisited as its own future task. See `.wyn/company/DECISIONS.md` (2026-09-19),
`.wyn/docs/design/wyn-169-chat-inbox-apple-style-extension.md`,
`.wyn/tasks/approved/WYN-169-chat-inbox-apple-style-extension.md`.

## QA Status

**PASS** — 6/6 test cases. Verified against the real CSS cascade (all 4 files touching
`.flutter-chat-header-action`, loaded in the exact `app/layout.tsx` import order) via an isolated Playwright
harness: press-scale fires correctly on both in-scope buttons, the back button has zero motion,
`prefers-reduced-motion` correctly disables the transition while still snapping to the pressed state, and
WCAG contrast for all 3 header buttons is 19.8:1 (light) / 21:1 (dark) — far above AA, no WYN-168-style
regression. No CRITICAL/HIGH/MEDIUM findings.

## Build Status

- Local sandbox: `npm run typecheck` / `npm run lint` / `npm run build` all green (AI Coding, then
  independently re-run by AI QA & Security and again by AI Deploy & DevOps)
- CI on PR #549: all 11 checks green on the first push, including `browser-qa` — no CI-red rounds needed this
  time (unlike WYN-167/168's PR #547→#548)
- `mergeable_state: clean`, no merge conflicts

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

`web/app/chat-notes.css` only (+17 lines: 2 `transition` additions to existing rule blocks, 2 new `:active`
rules, 1 new `@media (prefers-reduced-motion: reduce)` block). No `.tsx` changes, no backend/RPC/schema
changes, no new dependencies, no new environment variables. Plus `.wyn/` process docs.

## Deployment Result

[Run #136](https://github.com/warren-wyn-dev/wynteam/actions/runs/35445198178) (PR #549 merge, commit
`315e3acc`) — **success**, all steps green: preflight (13:15:31–13:16:10), Vercel production deploy
(13:16:10–13:16:45), route verification (13:16:45–13:16:48). The full `main`-branch `CI` workflow (run
[#1383](https://github.com/warren-wyn-dev/wynteam/actions/runs/35445198089)) also finished green on the same
commit — `Supabase Edge Functions`, `schema.sql ordering`, `Admin (Next.js)`, `Flutter`, `Supabase PostgreSQL
integration` all success. No CI-red rounds this deploy (unlike WYN-167/168's #547→#548) — PR #549 was green
on its first push and stayed green through merge.

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step (real network access from
  the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks `wynos.online`, so independent
  verification isn't possible from here — same limitation as every prior web deploy in this log folder
- **Still needed from Founder**: open `wynos.online/chat` (or equivalent) on a real phone/browser and press
  the "คำขอ" pill and the ✎ compose icon to confirm the press-scale motion is visible and feels right — since
  this log covers infrastructure-level success, not a human's read on the actual result

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a single CSS file, additive only (nothing
  removed or overridden).
- If a regression is found: fix-forward with a corrective commit to `main` (or a hotfix branch → PR → merge),
  which re-triggers `wyn-158-production-deploy.yml` automatically.
- Trivially revertable: reverting the single commit that touches `web/app/chat-notes.css` fully undoes this
  change with no side effects on any other screen.
- A hard rollback (`vercel rollback` or reverting the merge commit) requires explicit Founder direction per
  `.wyn/company/WEB_VERSION_CONTROL.md`.
