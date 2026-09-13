# WYN-158 — Next.js Consumer Web Migration

Status: completed (production cutover confirmed on real iPhone Safari, 2026-09-13)
Date: 2026-09-13
Owner: Founder

## Outcome

WYNOS consumer web migrated from Flutter Web production to **Next.js 16 + React 19 + browser/OS system fonts**, preserving the existing Supabase Auth/RLS/RPC/storage/realtime contracts. No Apple/SF Pro font files are bundled and no service-role/management secret is exposed to browser code.

`wynos.online` now serves the Next.js consumer web. The Flutter source remains in `app/`; it was not deleted or automatically reverted.

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

Merged through PR #413 at `1ae2757917cb937e716eab20b8aafd85ddcf6019`.

- Search + Discovery.
- Own/other Profile, follow/request, DM entry, block/mute, Posts/Reposts/Likes and editing.
- Notifications.
- Chat inbox/requests/new conversation/realtime thread/pagination/text+image/read/delete.
- Settings.
- Deep links for profiles, drops, pops, clubs, club posts and invites.

## Phase 4 — UX/UI Parity + QA (complete)

Completed through PR #414.

- Next.js app-local navigation.
- Browser-native DOM and OS/system-font architecture.
- Native `<img>` architecture for signed Supabase media/WebKit lifecycle behavior.
- Playwright QA across Home, Search, Profile, Notifications, Chat, Settings and deep-link shells.
- iPhone-like WebKit, Android Chromium and desktop Chromium coverage.
- Guards for fatal page errors, overflow, Flutter platform-view remnants, system-font regressions and route churn/session survival.

## Phase 5 — Production cutover (complete)

Founder approved Phase 5 and confirmed the physical iPhone Safari release-candidate gate passed on 2026-09-13.

### Readiness

- Cutover-readiness infrastructure merged through PR #415.
- Hosted Vercel Preview browser QA hardened through PR #416 at `68b04d3321b9e39032b46a8f601e9ef4cf812b76`.
- Release-candidate hardening and physical-iPhone checklist merged through PR #417 at `9a296f22db8ced79c1cd8d94a3f6f0e3c18156b0`.
- Hosted preview smoke + Playwright passed across iPhone-like WebKit, Android Chromium and desktop Chromium.
- Real iPhone Safari QA passed by Founder confirmation.
- Consumer Web lint/type/build, browser QA and full repository CI passed before cutover.

### Production cutover

The manual `Consumer Web Phase 5 Production Cutover` workflow was run from `main` with the exact double confirmations `CUTOVER-WYNOS-ONLINE` and `IPHONE-PASS`.

The production deployment built successfully on Vercel and Vercel reported:

- production deployment URL created successfully;
- `wynos.online` aliased to the new deployment;
- Next.js production build completed successfully.

The workflow's first post-deploy verification ran immediately after aliasing and reported a false-negative before production propagation had settled. It did **not** represent a failed deployment: the deploy/alias step was already successful. Founder then opened `wynos.online` on a real iPhone Safari and confirmed the WYNOS Next.js landing/login screen was being served publicly.

Production-verification hardening was merged through PR #419 at `d54ddec9f6139e7ceeaa6a731df4ddb17bfd0cab` so future cutovers wait for alias/cache propagation and distinguish protection/auth responses from legacy Flutter content.

### Final production state

- `wynos.online`: **Next.js consumer web** — confirmed on real iPhone Safari.
- Legacy Flutter production alias: **replaced** by the Next.js deployment.
- Flutter source: retained in the repository; no automatic rollback was performed.
- Supabase backend contracts: unchanged.
- Phase 5: **COMPLETE**.
