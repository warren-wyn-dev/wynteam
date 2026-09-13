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

## Phase 4 — UX/UI Parity + QA (active)

Founder explicitly requested Phase 4.

Acceptance target:

- Mobile/desktop responsive parity, safe-area and overflow checks.
- App-local navigation uses Next.js routing without unnecessary full-page reloads.
- Browser-native DOM/system fonts remain intact; no Apple/SF Pro assets.
- Automated browser smoke/stress coverage across Home, Search, Profile, Notifications, Chat, Settings and deep-link route shells.
- Lint, TypeScript, production build, font/license guard and full repository CI remain green.
- Auth/RLS/storage/realtime contracts are regression-checked without weakening authorization.

Automated browser emulation is not physical-device confirmation. Real iPhone confirmation remains a distinct QA gate before public cutover.

## Still outside Phase 4

- Public production cutover.
- Replacing/deleting the Flutter app.
- Any new WYNOS version number.
- Switching `wynos.online` to Next.js; that remains Phase 5 and requires explicit Founder approval.
