# WYN-158 — Next.js Consumer Web Migration

Status: ACTIVE
Date: 2026-09-13
Owner: Founder

## Founder approval

Founder explicitly approved moving the consumer web frontend toward **Next.js/React + browser/OS system fonts + the existing Supabase backend**, while preserving the current WYNOS UX/UI. Production cutover is a separate release gate and is **not** approved by this task alone.

## Problem

Flutter Web paints most UI through its web renderer rather than normal browser DOM. On iPhone/iPad this prevents WYNOS from reliably using the device's installed system text fonts through Flutter canvas rendering. Previous attempts to render every text fragment as an HTML platform view restored native browser fonts but created too many platform views in scrolling feeds and contributed to WebKit stability pressure.

## Approved direction

Build a consumer web frontend in `web/` using Next.js + React. Keep Supabase as the backend and preserve current authorization/RLS contracts. Do not bundle or redistribute Apple font files. Use a CSS system-font stack so the browser chooses the installed OS font.

## Rollout

1. Keep Flutter `app/` and current production deployment unchanged during migration.
2. Build and test the new web frontend independently.
3. New frontend remains internal/developer-only until Founder approves public cutover.
4. Production deployment/cutover requires a separate Founder approval.
5. No automatic rollback of WYNOS versions.

## Phase 1 — Foundation (merged)

- Next.js 16 + React 19 + TypeScript foundation.
- Browser system-font CSS stack; no font assets and no `@font-face`.
- Existing Supabase publishable-client configuration only; no service-role key in the browser.
- Existing `is_developer_account()` RPC used as a fail-closed internal preview gate.
- Existing `get_wynos_ranked_feed()` RPC used for the first read-only Home feed migration slice.
- Mobile-first WYNOS Home shell matching current palette, spacing direction, tabs, post cards and bottom navigation.
- Native browser `<img>` for feed/avatar images.
- CI for lint, TypeScript, production build and font-license guard.

Phase 1 merged through PR #411 at `741fad1a93a97464b2e6020088324306dabccd36`. It did not cut over Production.

## Phase 2 — Home interactions (complete)

Completed through PR #412 and squash-merged to `main` at `41ac064cc3e69cc75a2ea69c6f598f9a5540a373`.

- Ranked/Following/Trending Home surfaces.
- Like, Save, Standard Repost, Follow/Follow Request.
- Post detail, comments and comment likes.
- Create Drop for text + up to nine images.
- Retry-safe atomic publication through the existing Supabase RPC/storage contracts.
- Browser-native text/images with no Apple/SF Pro font redistribution.

Phase 2 acceptance passed Consumer Web CI and full repository CI; `wynos.online` remained Flutter Production.

## Phase 3 — Main routes (active)

Founder explicitly requested Phase 3 to be carried through to completion. This phase migrates the remaining primary consumer-web routes while preserving the same developer-only rollout gate and existing backend authorization contracts.

Implemented on `feat/wyn-158-phase3-routes`:

- Shared fail-closed developer/session gate for migrated routes.
- Search + Discovery: explicit-submit User/Post/Club search, trending hashtags, rising profiles and suggested profiles.
- Profile: own/other profile, follow/follow-request, message entry, block/mute, Posts/Reposts/Likes, edit display name/bio/username/avatar/cover.
- Notifications: paginated list, mark-all-read and content/profile/chat navigation.
- Chat: inbox, message requests, user search/new conversation, request accept/delete, conversation history pagination, realtime updates, text/image sending, read markers and message delete.
- Settings: account privacy, interaction permissions, Likes visibility, online-status privacy, notification categories, blocked/muted management, data export/account deletion, legal document viewer and sign-out.
- Deep links: `/@username`, `/drop/:id`, `/pop/:id`, `/club/:id`, `/club-post/:id`, `/club-invite/:code`, plus migrated internal routes.
- Home navigation bridge exposes the migrated Search/Notifications/Profile/Settings routes without rewriting the Phase 2 Home component.
- All browser UI continues to use native DOM/system fonts; no font files or `@font-face` are added.

### Phase 3 acceptance criteria

- Consumer Web ESLint, TypeScript, production build and font-license guard all pass.
- Full repository CI remains green.
- Search/Profile/Notifications/Chat/Settings and supported deep links are reachable and use existing Supabase Auth/RLS/RPC/storage contracts.
- No service-role/management secret or authorization bypass is introduced.
- Public Production cutover is still excluded; `wynos.online` remains Flutter until Phase 5 approval.

## Still outside Phase 3

- Pixel-perfect/interaction parity and physical-device stress QA across iPhone/Android/Desktop (Phase 4).
- Public staging-to-production domain cutover (Phase 5; separate Founder approval).
- Replacing/deleting the Flutter app.
- Any new WYNOS version number.
