# WYNOS Web Beta1 — Post Composer Same-Route Navigation Fix Deploy

Date: 2026-09-16

## Release

- Scope: fix the bottom nav's "โพสต์" (Post) button intermittently not
  opening the composer.
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#477](https://github.com/warren-wyn-dev/wynteam/pull/477) — merged by warren-wyn-dev (this session) at 2026-09-16T06:14:20Z
- Commit deployed: `e23d59543ecb64d2d80ce3087432320a19448975` (merge commit on `main`: `988e4d1a56ac8f86c200ecd96f18c176889ac9b9`)

## Trigger

Founder reported "ปุ่มโพสต์ ชอบกดไม่ได้" (the Post button often can't be
pressed). Cache-clear troubleshooting didn't resolve it. The decisive
diagnostic detail from the Founder — "กดครั้งแรกไม่ติด กดเปลี่ยนแทปบาร์
เรื่อยๆ ถึงติด" (first press doesn't register; after switching tabs
repeatedly it eventually works) — pinpointed a same-route-navigation bug
rather than a touch/hydration/cache issue.

## QA Status

PASS. Root cause: `composerOpen` in `home-screen.tsx` was seeded from
`searchParams` via a `useState` lazy initializer, which only runs once at
the component's original mount. Tapping "โพสต์" while already on `/` is a
same-route navigation (only the `?compose=1` query param changes), so Home
stays mounted and the initializer never re-runs — the composer silently
never opened on that path. Navigating in fresh from another route worked,
since that mount reads the param directly, explaining why cycling through
tabs "fixed" it.

Three other hypotheses were tested and ruled out first, per explicit
Founder feedback that basic troubleshooting hadn't worked: hydration
timing under throttled network/CPU (native `<a href>` always navigated,
even pre-hydration), a stale service-worker cache (Founder confirmed
clearing site data + re-adding to home screen did not fix it), and a
touch-handler conflict with the new swipe-back gesture or the feed's own
pull-to-refresh handler (ruled out via bounding-box math and passive-
listener/DOM-sibling code inspection).

Fix: derive `composerOpen` directly from `searchParams` on every render
instead of mirroring it into local state — structurally eliminates this
bug class. Simplified `Beta4Composer`'s `onClose` to just `router.replace("/")`,
since `composerOpen` now clears itself once the query param is gone.

Verified with `npm run check` (lint + `tsc --noEmit` + `next build`, clean)
and a full `chromium-desktop` Playwright regression run: same 8
pre-existing baseline failures, no new regressions.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed / 26
  failed, identical root causes already documented and stood down on in
  #468/#469/#471/#473/#475. Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/477#issuecomment-5692918154
- Flutter, Admin (Next.js), both Supabase jobs, schema.sql ordering: success

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

1 file in `web/`: `components/home/home-screen.tsx` — `composerOpen` is now
derived directly from `searchParams` instead of a `useState` lazy
initializer; `Beta4Composer`'s `onClose` simplified accordingly. No other
files changed. No backend/database/RLS/Edge Function changes.

## Deployment Result

Automatic: merging PR #477 into `main` triggered `wyn-158-production-deploy.yml`
([run 35062823417](https://github.com/warren-wyn-dev/wynteam/actions/runs/35062823417),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T06:14:47–06:15:23Z)
2. `Deploy to Vercel production` — success (2026-09-16T06:15:23–06:16:06Z)
3. `Verify production routes` — success (2026-09-16T06:16:06–06:16:09Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**: from Home, tap "โพสต์" on the bottom nav
  repeatedly without switching tabs in between, and confirm the composer
  opens reliably every time (the originally reported failure mode)

## Rollback Plan

- No destructive changes, no schema/migration, no version bump — a
  single-file, purely client-side state-derivation change.
- If a regression is found: fix-forward with a corrective commit to `main`
  (or a hotfix branch → PR → merge), which re-triggers
  `wyn-158-production-deploy.yml` automatically. A hard rollback requires
  explicit Founder direction per `.wyn/company/VERSION_CONTROL.md`.
