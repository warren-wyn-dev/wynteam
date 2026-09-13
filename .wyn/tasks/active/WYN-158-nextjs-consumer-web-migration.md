# WYN-158 — Next.js Consumer Web Migration

Status: ACTIVE
Date: 2026-09-13
Owner: Founder

## Founder approval

Founder approved moving the consumer web frontend toward **Next.js/React + browser/OS system fonts + the existing Supabase backend**, while preserving the current WYNOS UX/UI. Founder explicitly approved **starting Phase 5** on 2026-09-13. Founder confirmed the **physical iPhone Safari release-candidate gate passed** on 2026-09-13. The actual `wynos.online` production alias switch remains protected by the dedicated double-confirmed cutover workflow.

## Approved direction

Build the consumer web in `web/` with Next.js + React. Keep Supabase Auth/RLS/RPC/storage contracts. Never put service-role/management keys in browser code. Do not bundle or redistribute Apple font files; use a CSS system-font stack so the browser chooses the installed OS font.

## Rollout boundary

1. Flutter `app/` and current Production remain unchanged until the Phase 5 production cutover is deliberately executed.
2. New consumer web stays developer/staging-only until the production switch is explicitly executed.
3. Production domain cutover is Phase 5 and uses a separate manual workflow with explicit confirmation.
4. No automatic rollback of WYNOS versions or production deployments.

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

Automated WebKit emulation is not physical-device confirmation.

## Phase 5 — Production cutover (active)

Founder explicitly approved starting Phase 5 on 2026-09-13.

### Hosted readiness completed

- Phase 5 cutover-readiness infrastructure merged through PR #415.
- Hosted Vercel Preview browser QA hardened and merged through PR #416 at `68b04d3321b9e39032b46a8f601e9ef4cf812b76`.
- Release-candidate hardening and the physical-iPhone checklist merged through PR #417 at `9a296f22db8ced79c1cd8d94a3f6f0e3c18156b0`.
- The deployed preview passed route smoke checks and the full Playwright suite against the hosted Vercel deployment across iPhone-like WebKit, Android Chromium and desktop Chromium.
- Vercel Deployment Protection remains enabled. CI creates a masked temporary automation bypass only for hosted QA and revokes it at the end of the run.
- Consumer Web lint/type/build, Phase 4 browser QA, hosted Phase 5 QA and full repository CI all passed on the reviewed release-candidate head before merge.
- No production alias was moved during readiness or hosted QA. `wynos.online` still serves the current Flutter production deployment until the production workflow is deliberately executed.

### Cutover architecture

- `.github/workflows/web-next-phase5-preview.yml` deploys the Next.js consumer web to the **existing Vercel production project as a preview deployment only**. It reuses the existing Vercel project/org/token secrets and Supabase public configuration, and does not move the `wynos.online` production alias.
- `.github/workflows/web-next-phase5-production.yml` performs the actual production switch from Flutter Web to Next.js. It is manual-only, must run from `main`, and requires both `CUTOVER-WYNOS-ONLINE` and `IPHONE-PASS` confirmations.
- The production workflow runs lint/type/build preflight before deployment and verifies after deployment that core `wynos.online` routes respond, Next.js assets are present, and the legacy Flutter bootstrap is absent.
- Neither workflow performs an automatic rollback. If a production regression is found, preserve evidence and wait for Founder-directed recovery.

### Production cutover gate

1. Phase 5 preview workflow succeeds against the existing Vercel project. **PASS**
2. Hosted preview smoke + Playwright/WebKit/Chromium QA succeeds against the deployed Vercel preview. **PASS**
3. Preview is tested on a **real iPhone in Safari** for layout, safe areas, scrolling, media behavior, typography, authentication and reload/crash stability. **PASS — Founder confirmed 2026-09-13**
4. Any real-device blocker is fixed and the preview/CI gates are green again. **N/A — no blocker reported in the passing gate**
5. Production workflow may now be run from `main` with exact confirmations `CUTOVER-WYNOS-ONLINE` and `IPHONE-PASS`. **READY**
6. After cutover, verify `wynos.online` core routes and normal signed-in flows before Phase 5 is marked complete. **PENDING**

### Current production state

The real-device gate is complete. Until the production workflow is deliberately executed, `wynos.online` remains on the current Flutter Web deployment. The Flutter source is not deleted or reverted as part of Phase 5 readiness work.
