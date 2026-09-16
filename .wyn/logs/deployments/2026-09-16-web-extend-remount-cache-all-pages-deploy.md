# WYNOS Web Beta1 — Extend Remount-Cache Fix to Every Page Deploy

Date: 2026-09-16

## Release

- Scope: extend the Home/Clubs/Notifications/Search "loading skeleton
  flash on every revisit" fix to every remaining live page in the app.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#483](https://github.com/warren-wyn-dev/wynteam/pull/483) — merged by warren-wyn-dev (this session) at 2026-09-16T07:40:00Z
- Commit deployed: `2bffe86077b0851f453622db9c4d6ae9a3e0077b` (merge commit on `main`: `3394fec3882cedcc68341bc85bb9d663826adb25`)

## Trigger

Follow-up to PR #481. After confirming the fix worked, Founder asked:
"ต่อไปแก้ทุกหน้าได้ไหม" (can you fix every page next?).

## QA Status

PASS. Applied the same `lib/mount-cache.ts` pattern used in PR #481
(seed initial render state from a per-key cache instead of blank/loading,
keep refetching in the background exactly as before) to every remaining
**live** page that seeded its own loading state to `true` on mount:

- Post detail (`post-detail-route.tsx`), keyed by `dropId`
- Club detail (`club-detail-golden.tsx`), keyed by `clubId`
- Club post detail (`deep-link-routes.tsx`'s `ClubPostInner`), keyed by `postId`
- Bookmarks (`bookmarks-route.tsx`)
- Settings (`settings-route.tsx`)
- Followers/following lists (`profile-follow-list-route.tsx`), keyed by `profileId`+`kind`
- Profile's own posts/redrops/likes tabs (`profile-route.tsx`'s
  `ProfileFeed`), keyed by `profileId`+`kind` — the profile summary
  itself already used `react-query` (whose `QueryClient` lives above the
  page-transition boundary) and was unaffected
- Chat conversation view (`chat-routes.tsx`'s `ConversationInner`),
  keyed by `conversationId` — still resubscribes to realtime and
  refetches on every mount, only the initial skeleton flash is removed
- Search result tabs (`search-route.tsx`'s `UserResults`/`DropResults`/
  `ClubResults`), keyed by query text — switching between User/โพสต์/Club
  tabs unmounts the others, so this had the same symptom

Left untouched: dead/unused code paths confirmed via `grep` for actual
imports (`chat-routes.tsx`'s `ChatInboxInner`, `club-detail-route.tsx`,
`deep-link-routes.tsx`'s `DropDetailInner`/`ClubInner`/`ClubInviteInner`
— all superseded by other live components), and pre-auth screens
(`auth-flow/screens.tsx`, `parity-email-auth.tsx`) which need a fresh
session check every time and aren't part of the "browsing between app
pages" complaint.

Verified with `npm run check` (lint + `tsc --noEmit` + `next build`,
clean — only the 2 pre-existing baseline warnings) and a full
`chromium-desktop` Playwright run against the correct browser binary:
same 8 pre-existing baseline failures, no new ones.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed /
  26 failed, identical failing spec lines and root causes already
  documented and stood down on in #468/#469/#471/#473/#475/#477/#479/#481.
  Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/483#issuecomment-5693810574
- Flutter, Admin (Next.js), both Supabase jobs, schema.sql ordering: success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

9 files in `web/`: `components/post-detail-route.tsx`,
`components/club-detail-golden.tsx`, `components/deep-link-routes.tsx`,
`components/bookmarks-route.tsx`, `components/settings-route.tsx`,
`components/profile-follow-list-route.tsx`, `components/profile-route.tsx`,
`components/chat-routes.tsx`, `components/search-route.tsx`. All reuse
the existing `lib/mount-cache.ts` helper added in PR #481 — no new
library files. No backend/database/RLS/Edge Function changes.

## Deployment Result

Automatic: merging PR #483 into `main` triggered `wyn-158-production-deploy.yml`
([run 35069695233](https://github.com/warren-wyn-dev/wynteam/actions/runs/35069695233),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T07:40:22–07:40:51Z)
2. `Deploy to Vercel production` — success (2026-09-16T07:40:51–07:41:38Z)
3. `Verify production routes` — success (2026-09-16T07:41:38–07:41:40Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: spot-check a few of the newly-covered
  pages after switching away and back in the same session — post detail,
  club detail, bookmarks, settings, a followers/following list, own
  profile's tabs, a chat conversation, and search result tabs — and
  confirm none of them flash a loading skeleton or visibly refetch on
  return

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — purely
  client-side state seeding, same low-risk pattern as PR #481; every
  affected page's data-fetching logic and network calls are unchanged.
- If a regression is found (e.g. stale data lingering too long on a
  specific page): fix-forward with a corrective commit to `main` (or a
  hotfix branch → PR → merge), which re-triggers
  `wyn-158-production-deploy.yml` automatically. A hard rollback requires
  explicit Founder direction per `.wyn/company/VERSION_CONTROL.md`.
