# Deployment Log — WYN-049 (WYN Admin Foundation)

Release: code-integration push to the designated session branch (not `main`, and not a production/end-user deploy — see "Deployment Target" below)
Date: 2026-08-24

## QA Status

**PASS** — see `.wyn/tasks/approved/WYN-049-admin-foundation.md`'s "Independent QA" section. All testable-without-live-infra behavior verified independently (lint/build clean, all 6 routes redirect unauthenticated requests to `/login`, no service-role key anywhere in the built bundle, sign-in/reject logic read adversarially for cookie-state correctness). Live 3-role auth round-trip is the one thing that needs a real Supabase project to verify — documented honestly as a residual gap, not assumed passing.

## Build Status

Verified independently in this session, Node.js v22.22.2:

- `npm install`: clean
- `npm run lint` (ESLint): **0 issues**
- `next build`: **clean, 0 errors/warnings** (including the TypeScript check `next build` runs as part of its pipeline)
- Live dev server + `curl`: `/`, `/users`, `/moderation`, `/reports`, `/audit-log`, `/announcements` all return `307` to `/login` when unauthenticated; `/login` renders the real form
- `grep` of `.next/static` (the actual built bundle, not just source) for `service_role`/`SERVICE_ROLE`: **no matches**

## Deployment Target

**`claude/phase-7-continuation-5s8by3` on GitHub only** (`warren-wyn-dev/wynteam`) — pushed via `git push`, not merged into `main`, and no pull request opened.

Same reasoning as WYN-044's deployment log (`.wyn/logs/deployments/2026-08-24-wyn-044-push-to-branch.md`): this session operates under an explicit instruction not to open a pull request unless a human asks for one, and the Founder's instruction this round was "Phase 7 ต่อเลย" (continue Phase 7), not a PR request. The code is merge-ready as far as this session can verify — QA passed, `next build` is clean — but merging (or opening a PR) is left for an explicit request.

**Note on the target repository itself**: unlike every prior WYN-0XX task, this one adds a brand-new application (`admin/`) rather than changing the existing Flutter apps. There is no Vercel project currently pointed at this new directory — deploying it to an actual live preview URL requires the Founder to either create a new Vercel project with `admin/` as its root directory, or reconfigure hosting once the code is reviewed. This is a distinct, separate step from the GitHub merge itself.

## Changes

45 files changed (8,245 insertions), committed as `a150b2a` on `claude/phase-7-continuation-5s8by3`:

- New `admin/` directory: Next.js 16 (App Router) + TypeScript + Tailwind v4 scaffold, `@supabase/ssr`-based auth (`lib/supabase/`), hand-written shadcn/ui primitives (`components/ui/`, `ui.shadcn.com` is blocked by this sandbox's network policy so the CLI couldn't be used), sign-in flow (`app/login/`) gated by `profiles.platform_role`, admin layout shell with a 6-item sidebar (`app/(admin)/`, `components/admin/`) — only Dashboard has a task number assigned so far (WYN-050); the other 5 are placeholders.
- Docs: `.wyn/tasks/approved/WYN-049-admin-foundation.md`, `.wyn/docs/design/wyn-049-admin-foundation.md`, `.wyn/company/CONTEXT.md`/`DECISIONS.md` updated (the latter records the Founder's stack approval as a Major Architecture decision).

Full history: `.wyn/tasks/approved/WYN-049-admin-foundation.md`.

## Deployment Result

**Pushed successfully to `claude/phase-7-continuation-5s8by3`.** Code-complete and QA-approved; not yet merged into `main`, not yet deployed to any live URL.

## Production Verification

**Not applicable — no production environment, and no hosting target yet exists for this new app specifically.** The whole-project Readiness Gate (unchanged since every prior assessment: no real Supabase project's credentials wired in, no distribution channel, no CI) applies here too, plus the new admin-specific gap noted above (no Vercel project pointed at `admin/` yet).

## Rollback Plan

- **Code**: nothing has touched `main` yet. Reverting on the session branch is a plain `git revert a150b2a`.
- **Database**: no schema changes at all in this task (Foundation scope deliberately doesn't touch `supabase/schema.sql` — see the Product spec).
- **Distribution**: not applicable — nothing has been deployed anywhere yet.

## Next Steps (Founder-only)

1. Say the word to open a PR / merge `claude/phase-7-continuation-5s8by3` into `main` (same as WYN-044's pending merge).
2. When ready to see it live: create a Vercel project pointed at the `admin/` subdirectory (Root Directory setting), and set `NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` there — same Supabase project as `app/`/`seller_app/` already use.
3. At least one real `profiles` row needs `platform_role = 'admin'` (or `'moderator'`) with a real Supabase Auth email/password credential to actually sign in and verify the live flow end-to-end — this is the live-round-trip QA noted as untestable in this sandbox.
4. Phase 7 continues with WYN-050 (Admin Dashboard) next, per the roadmap.
