# WYNOS Web Beta1 — Native-Feel Features Deploy (Haptics/Offline/Swipe-back/Push)

Date: 2026-09-16

## Release

- Scope: 4 features to make WYNOS Web feel closer to a native app: haptic
  feedback, offline React Query cache persistence, an edge-swipe-back
  gesture, and Web Push notifications (reusing the Flutter app's existing
  Firebase/FCM push infrastructure end-to-end).
- Version: within **WYNOS Web Beta1** — no version bump requested
- PR: [#475](https://github.com/warren-wyn-dev/wynteam/pull/475) — merged by warren-wyn-dev (this session) at 2026-09-16T05:42:11Z
- Commit deployed: `0dc44f7d51c90427e975e7eddc16f43392c9cb9e` (merge commit on `main`: `a644776adc84f5fc5e49b6f885c417226d080bd2`)

## Trigger

Founder asked "want the app to feel 95-100% like a real native app, any
recommendations?" — proposed 4 concrete, high-leverage areas (haptics,
offline caching, native gestures, push), Founder said do all 4.

## QA Status

PASS. `npm run check` (lint + `tsc --noEmit` + `next build`) green. Full
`chromium-desktop` Playwright run: 4 failures, all in the established
pre-existing baseline (confirmed no new regressions from the touch-handler
changes in `home-screen.tsx` or the new settings toggle). Verified
`push_tokens` RLS (insert/update/delete, owner-scoped) already covers the
client-side upsert/delete this PR performs — no schema/RLS changes needed.
Verified via a production build that `firebase/app` + `firebase/messaging`
are code-split into their own lazy chunk (dynamic `import()`), not part of
the shared bundle loaded on every page.

## Build Status

- Local sandbox: `npm run check` green
- CI `web` check (`web-next-ci.yml`): success
- CI `browser-qa` check (`web-phase4-browser-qa.yml`): red — 91 passed / 26
  failed, identical count and root causes already documented and stood
  down on in #468/#469/#471/#473. Full analysis:
  https://github.com/warren-wyn-dev/wynteam/pull/475#issuecomment-5692615025

## Deployment Target

Vercel production project behind `wynos.online` (existing project, no new infra)

## Changes

15 files in `web/`: new `lib/haptics.ts`, `lib/push-notifications.ts`,
`components/swipe-back-gesture.tsx`, `app/api/push-config/route.ts`;
modified `components/home/home-screen.tsx` (haptic call sites, pull-to-
refresh trigger), `components/chat-routes.tsx` (haptic on send),
`components/query-provider.tsx` (localStorage persistence),
`components/developer-route-gate.tsx` (query cache clear on sign-out),
`components/settings-route.tsx` (push toggle), `components/
app-navigation-runtime.tsx` (foreground push listener), `app/layout.tsx`
(mounts SwipeBackGesture), `public/sw.js` (Firebase Messaging background
handler), `.env.example` (documents new Firebase env vars). New dependency:
`firebase`, `@tanstack/react-query-persist-client`,
`@tanstack/query-sync-storage-persister`. **No backend/database/RLS/Edge
Function changes** — Web Push reuses WYN-016's existing `push_tokens`
table and `send-push-notification` Edge Function verbatim.

## Deployment Result

Automatic: merging PR #475 into `main` triggered `wyn-158-production-deploy.yml`
([run 35060575741](https://github.com/warren-wyn-dev/wynteam/actions/runs/35060575741),
push-to-main on `web/**` paths), which completed **success** end-to-end:

1. `Production preflight` — success (2026-09-16T05:42:34–05:43:04Z)
2. `Deploy to Vercel production` — success (2026-09-16T05:43:04–05:44:06Z)
3. `Verify production routes` — success (2026-09-16T05:44:06–05:44:08Z)

## Production Verification

- **AI-confirmed**: the production workflow's own `Verify production routes` step
  (real network access from the GitHub Actions runner) — success
- **Not AI-confirmed**: this sandbox's outbound network policy blocks
  `wynos.online`, so independent verification isn't possible from here
- **Still needed from Founder**:
  1. Add 7 Vercel env vars (`NEXT_PUBLIC_FIREBASE_API_KEY`,
     `NEXT_PUBLIC_FIREBASE_APP_ID`, `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`,
     `NEXT_PUBLIC_FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`,
     `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`, `NEXT_PUBLIC_FIREBASE_VAPID_KEY`)
     — copy the same values already stored as GitHub Actions secrets
     (`FIREBASE_WEB_API_KEY` etc., see `.github/workflows/deploy-web.yml`)
     — before Web Push can work at all; the Settings toggle stays hidden
     until then, everything else in this deploy is unaffected either way
  2. After that, verify push end-to-end: Settings → การแจ้งเตือน →
     เปิดการแจ้งเตือนแบบพุช on a real device, then trigger a notification
     (e.g. have another account like/follow) and confirm it arrives
  3. Feel the haptics on like/follow/redrop/pull-to-refresh/send on Android
     (no effect expected on iOS — Safari has no Vibration API)
  4. Try the left-edge swipe-back gesture on a pushed screen (post detail,
     profile, chat conversation, settings)

## Rollback Plan

- No destructive changes, no schema/migration, no version bump.
- If Web Push misbehaves once configured: unsetting the 7 Vercel env vars
  makes `/api/push-config` report `configured: false` again, which hides
  the Settings toggle and no-ops every push code path — no code change
  needed to disable it.
- If a regression is found elsewhere: fix-forward with a corrective commit
  to `main` (or a hotfix branch → PR → merge), which re-triggers
  `wyn-158-production-deploy.yml` automatically. A hard rollback requires
  explicit Founder direction per `.wyn/company/VERSION_CONTROL.md`.
