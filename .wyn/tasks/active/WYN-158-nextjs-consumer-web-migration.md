# WYN-158 — Next.js Consumer Web Migration

Status: ACTIVE
Date: 2026-09-13
Owner: Founder

## Founder approval

Founder approved moving the consumer web frontend toward **Next.js/React + browser/OS system fonts + the existing Supabase backend**, while preserving the current WYNOS UX/UI. Production cutover remains a separate release gate.

## Approved direction

Build the consumer web in `web/` with Next.js + React. Keep Supabase Auth/RLS/RPC/storage contracts. Never put service-role/management keys in browser code. Do not bundle or redistribute Apple font files; use a CSS system-font stack so the browser chooses the installed OS font.

## Rollout boundary

1. Flutter `app/` and current Production remain unchanged during migration.
2. New consumer web stays developer-only until explicit Founder approval for public rollout.
3. Production domain cutover is Phase 5 and requires separate Founder approval.
4. No automatic rollback of WYNOS versions.

## Phase 1 — Foundation (complete)

Merged through PR #411 at `741fad1a93a97464b2e6020088324306dabccd36`.

- Next.js 16 + React 19 + TypeScript foundation.
- Browser system-font CSS stack; no font assets and no `@font-face`.
- Existing Supabase publishable configuration and developer gate.
- Initial Home shell/read-only ranked feed.

## Phase 2 — Home interactions (complete)

Merged through PR #412 at `41ac064cc3e69cc75a2ea69c6f598f9a5540a373`.

- Ranked/Following/Trending Home surfaces.
- Like, Save, Standard Repost and Follow/Follow Request.
- Post detail, comments and comment likes.
- Create Drop with up to nine images and retry-safe atomic publication.

## Phase 3 — Main routes (complete)

Merged through PR #413 at `1ae2757917cb937e716eab20b8aafd85ddcf6019` after Consumer Web lint/type/build/font guard and full repository CI passed.

- Search + Discovery: User/Post/Club search, trending hashtags, rising/suggested profiles.
- Profile: own/other profile, follow/request, DM entry, block/mute, Posts/Reposts/Likes and editing.
- Notifications: paginated list, mark-all-read and content/profile/chat navigation.
- Chat: inbox, requests, new conversation, realtime thread, pagination, text/image messages, read state and delete.
- Settings: privacy/interaction/Likes visibility, online status, notifications, blocked/muted lists, export/delete account, legal docs and sign-out.
- Deep links: `/@username`, `/drop/:id`, `/pop/:id`, `/club/:id`, `/club-post/:id`, `/club-invite/:code`.

## Phase 4 — UX/UI Parity + QA (complete)

Completed through PR #414 after the automated Phase 4 gate passed on the reviewed branch.

Delivered:

- Migrated app-local navigation uses Next.js routing rather than avoidable full-document reloads.
- Browser-native DOM and OS/system-font architecture remains intact with no Apple/SF Pro assets or `@font-face`.
- Native browser `<img>` remains the deliberate consumer-web image architecture for signed Supabase media and WebKit lifecycle behavior.
- Playwright browser QA covers Home, Search, Profile, Notifications, Chat, Settings and supported deep-link shells.
- QA runs across iPhone-like WebKit, Android-like Chromium and desktop Chromium.
- Browser checks guard fatal page errors, horizontal overflow, Flutter platform-view elements, system-font regressions and repeated route churn/session survival.
- Consumer Web lint, TypeScript, production build, font/license guard, Phase 4 browser QA and full repository CI all passed before completion.
- Existing Supabase Auth/RLS/RPC/storage/realtime contracts remain unchanged; no authorization weakening or browser secret was introduced.

Automated WebKit emulation is not physical-device confirmation. Real iPhone Safari confirmation remains a required **Phase 5/public-cutover gate**, not a claim made by Phase 4 automation.

## Phase 5 — Production cutover (not started)

Requires separate explicit Founder approval before changing `wynos.online` or replacing the current Flutter production deployment.

Pre-cutover gate includes real iPhone Safari verification of layout, safe areas, scrolling, media behavior, typography and reload/crash stability. Any public-domain switch, production deployment or retirement of Flutter production remains outside the completed Phase 4 scope.
