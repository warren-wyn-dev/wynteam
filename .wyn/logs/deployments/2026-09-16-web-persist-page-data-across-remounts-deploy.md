# WYNOS Web Beta1 — Persist Page Data Across Route Remounts Deploy

Date: 2026-09-16

## Release

- Scope: stop Home, Clubs, Notifications, and Search from re-showing a
  full loading skeleton and refetching from scratch every time the user
  navigates back to them, which read as the whole app "reloading" on
  every page change.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#481](https://github.com/warren-wyn-dev/wynteam/pull/481) — merged by warren-wyn-dev (this session) at 2026-09-16T07:14:09Z
- Commit deployed: `61a766fe2cf6030c792be9ad467bfe058760027d` (merge commit on `main`: `f0be75056eb4ab493c8dc62f15751c97a7278f9e`)

## Trigger

Founder reported: "ทำไมเวลาเปลี่ยนหน้า ชอบโหลดใหม่ตลอดเลย เป็นทุกหน้า"
(why does every page seem to reload every time I switch pages?).

## QA Status

PASS. First confirmed via Playwright that no actual full page reloads
ever occur — navigation is genuine client-side SPA routing throughout,
no `window.location` navigation, no service-worker-triggered reload.

Root cause: the root `PageTransition` (`components/ui/page-transition.tsx`)
deliberately fully unmounts/remounts every page on route change
(`key={pathname}`, `mode="wait"` — an existing, intentional design to
avoid a `position: fixed` containing-block issue from earlier work, left
unchanged). Home, Clubs, Notifications, and Search each seeded their own
`loading` state to `true` and fetched fresh on every mount with no cache
of their own, so returning to any of them (e.g. Home → คลับ → back to
Home) re-showed the full skeleton and refetched from scratch every
single time, even though the data had just been loaded moments before.

Chat inbox (`chat-inbox-parity.tsx`) and own-profile (`profile-route.tsx`)
already use `react-query`; its `QueryClient` lives in `QueryProvider` at
the root layout, above the `PageTransition` boundary, so it already
survives remounts — both were verified unaffected and left untouched.

Fix: a small module-level cache (`lib/mount-cache.ts`) that survives
component unmount, keyed per user (and additionally per feed mode for
Home, matching Home's own existing per-mode `feedCache` pattern). Each
affected page seeds its initial render state from the cache instead of
blank/loading, and still refetches in the background afterward exactly
as before — this only removes the skeleton flash on a page the user
already has fresh data for; no data-fetching behavior changed.

Verified with `npm run check` (lint + `tsc --noEmit` + `next build`,
clean) and a full `chromium-desktop` Playwright run against the correct
browser binary: same 8 pre-existing baseline failures, no new ones.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed /
  26 failed, identical failing spec lines and root causes already
  documented and stood down on in #468/#469/#471/#473/#475/#477/#479.
  Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/481#issuecomment-5693491525
- Flutter, Admin (Next.js), both Supabase jobs, schema.sql ordering: success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

5 files in `web/`: new `lib/mount-cache.ts`; modified
`components/home/home-screen.tsx` (module-level per-user, per-mode store
for feed/club rows, scroll positions, visible counts, identity, and
notification badge — `mode`/`visibleMode` mutations moved to fresh
`getHomeScreenStore(userId)` calls at each write site to satisfy the
stricter React Compiler lint's immutability rules), `components/clubs-
routes.tsx` (`ExploreClubs`/`MyClubs` seed from cache), `components/
notifications-route.tsx` (rows/unread/page/hasMore seed from cache),
`components/search-route.tsx` (`Discovery`'s hashtags/suggested seed from
cache). No backend/database/RLS/Edge Function changes.

## Deployment Result

Automatic: merging PR #481 into `main` triggered `wyn-158-production-deploy.yml`
([run 35067494439](https://github.com/warren-wyn-dev/wynteam/actions/runs/35067494439),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T07:14:25–07:14:46Z)
2. `Deploy to Vercel production` — success (2026-09-16T07:14:46–07:15:22Z)
3. `Verify production routes` — success (2026-09-16T07:15:22–07:15:25Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: from any account, switch repeatedly
  between Home, คลับ, แชท, การแจ้งเตือน, and ค้นหา and confirm no loading
  skeleton flashes and no content re-fetch delay when returning to a page
  already visited in the same session

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — purely
  client-side state seeding; every affected page's data-fetching logic
  and network calls are unchanged.
- If a regression is found (e.g. stale data lingering too long on a
  page): fix-forward with a corrective commit to `main` (or a hotfix
  branch → PR → merge), which re-triggers `wyn-158-production-deploy.yml`
  automatically. A hard rollback requires explicit Founder direction per
  `.wyn/company/VERSION_CONTROL.md`.
