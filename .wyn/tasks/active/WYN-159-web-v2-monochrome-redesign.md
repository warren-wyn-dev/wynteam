# Product/Design Task — WYN-159

Status: active — Design phase in progress
Owner: AI Design → AI Coding → AI QA & Security
Feature: WYNOS Consumer Web (wynos.online) full UX/UI redesign — "Monochrome v2"

## Founder Directive (2026-09-14)

Founder attached `wynos-feed.html` (a static HTML/CSS mockup) as the **new primary UX/UI master**
for the entire Consumer Web application, superseding the WYN-158 mobile-Flutter pixel-parity
mandate for this surface. This is an intentional visual redesign, not a patch. See
`.wyn/company/DECISIONS.md` entries dated 2026-09-14 for the full decision record.

Reference file: `wynos-feed.html` (uploaded by Founder; canonical bytes captured verbatim in
`.wyn/docs/design/reference/wynos-feed.html` for audit/reproducibility).

## Scope

All Consumer Web (`web/`) user-facing routes: Welcome/Auth, Home feed (3 tabs), Post Card,
Post Detail, Media/carousel, Bottom Navigation + App Shell, Profile (own/other/followers/
following/public slug), Search, Notifications, Chat (inbox + conversation), Create Post
composer, Clubs (discovery/detail/create/invite/post), Settings.

Out of scope: Admin dashboard (`admin/`), Seller dashboard, Mobile Flutter app (`app/`),
backend/database schema (unless strictly necessary), Supabase RLS/auth architecture.

## Non-negotiable constraints (from Founder brief + standing AGENTS.md rules)

1. Preserve all existing product behavior: auth, Supabase data flows, posting, images,
   comments, likes, reposts, shares, bookmarks, follows, profiles, notifications, chat,
   search, clubs, settings, moderation, routing, permissions, RLS, API contracts.
2. No database schema changes unless absolutely necessary (flag and ask first if needed).
3. No new legacy CSS layers (no `*-final.css`, `*-closure.css`, `!important` stacks, runtime
   DOM style patches). Build one canonical token/component layer and migrate onto it; delete
   or isolate the ~25 existing parity/golden/phase CSS files as each surface migrates.
4. New user-facing behavior (if any is introduced incidentally) must stay gated behind
   `DeveloperAccessService.isDeveloperAccount()` per WYN-125 staged rollout, unless it is a
   pure bug/accessibility fix.
5. Do not add Check-in, location, or other new product functionality.
6. Work and land in stages (tokens → shell → home → nav → post card → profile → post detail →
   search → notifications → chat → composer → clubs → settings → cleanup), lint/typecheck/
   build after each stage, stop and report on regression.
7. Branch: `feat/wyn-ux-ui-redesign`. No direct edits to `main`. No auto-merge.
8. Deterministic Playwright visual fixtures for each major screen (no live timestamps/data).
   WebKit/iPhone as primary mobile visual target, Chromium desktop secondary.

## Deliverables (per Founder brief)

1. Branch name + PR URL + commit SHAs
2. Design-system files created
3. Legacy CSS files deleted/deactivated (list)
4. Redesigned routes (list)
5. Screenshot artifacts for every major screen
6. Test results
7. Remaining visual differences, if any
8. Production migration risks

Founder will make the final visual-acceptance call — do not self-certify "100%" from
automated tests alone.

## Design Artifacts (AI Design phase)

- `.wyn/docs/design/wyn-159-web-v2-design-system.md` — canonical tokens, typography, spacing,
  component primitive inventory, CSS migration strategy
- `.wyn/docs/design/wyn-159-web-v2-app-shell-home-navigation.md` — App Shell, Header, Tabs,
  Bottom Nav, Home feed, Post Card
- `.wyn/docs/design/wyn-159-web-v2-profile-post-detail.md` — Profile, Post Detail
- `.wyn/docs/design/wyn-159-web-v2-search-notifications-chat.md` — Search, Notifications,
  Chat Inbox, Chat Conversation
- `.wyn/docs/design/wyn-159-web-v2-composer-clubs-settings.md` — Create Post, Clubs, Settings
- `.wyn/docs/design/wyn-159-web-v2-auth-welcome.md` — Welcome/Auth

## Progress Log

- 2026-09-14: Founder decision recorded. Codebase audit complete (25 legacy CSS files,
  ~5000 lines, confirmed `*-parity`/`*-golden`/`phase*` naming pattern across `web/app` and
  `web/components`). Design system + screen specs in progress.
- 2026-09-14: Design phase complete (~15% of overall WYN-159 scope). All 6 design docs written
  and committed: design system/tokens, App Shell+Home+Nav+Post Card, Profile+Post Detail,
  Search+Notifications+Chat, Composer+Clubs+Settings, Auth/Welcome+remaining screens. Three
  open questions flagged to Founder (dark mode, desktop nav pattern, action-row extensions) —
  documented with a stated default so Coding is not blocked while awaiting an answer. Next:
  hand off to AI Coding for Batch 1 (tokens/primitives) + Batch 2 (App Shell/Home/Nav/Post Card,
  the flagship screen) on branch `feat/wyn-ux-ui-redesign`.
- 2026-09-14: Batch 1+2 implementation complete (~25% of overall WYN-159 scope). Branch
  `feat/wyn-ux-ui-redesign` pushed with tokens, `WynosAppShell/Header/IconButton/Tabs/Avatar/
  PillButton/BottomNav` primitives, and Home/BottomNav/PostCard migrated to the v2 monochrome
  design. `npm run check` passes (lint/typecheck/build). Legacy `home.css`/`bottom-nav.css`
  deleted; `golden-drop-card.css` deliberately kept (still used by unmigrated Profile/Search/
  Bookmarks). Screenshots captured (Chromium mobile-emulation + desktop; WebKit unavailable in
  the build environment) and reviewed — visually matches the reference direction. Awaiting
  Founder go/no-go before Batch 3+ (Profile, Post Detail, Search, Notifications, Chat, Composer,
  Clubs, Settings, Auth) per the standing "visual check before continued rollout" rule. Known
  follow-up: several pre-existing Playwright visual-regression specs assert old WYN-158 parity
  class names/pixel values and now fail — expected fallout, needs a later batch to retire/rewrite.
- 2026-09-14: Founder supplied two more precise Home references (`wynos-home.html`, then
  `wynos-home-v2.html` with inline SVG + explicit semantic icon mapping) with a strict
  no-approximation mandate. Design docs corrected (centered tabs, `--danger-bg` token, exact
  post-block/post-head-row/post-media-wrap/post-footer DOM structure, failed-to-send state,
  definitive Lucide icon mapping table). Implementation correction pass complete on
  `feat/wyn-ux-ui-redesign` (commits `80c975bb`..`ff91291c`): single prop-driven `WynosPostCard`
  (variants: text-only/carousel/failed, via `media`/`sendStatus` props, not 3 hardcoded blocks),
  carousel+dots+footer now render as DOM siblings of the head row (matches reference structure),
  tabs centered, failed-state error box implemented. `npm run check` passes. Screenshots
  (including reference-file side-by-side and carousel/failed close-ups) captured and reviewed —
  structure and interaction states match; one open discrepancy found and not yet resolved:
  carousel images render large/full-bleed (existing WYN aspect-ratio product behavior) rather
  than the reference's fixed 220x270px thumbnails — flagged to Founder rather than silently
  picked. A coding-agent false-positive "prompt injection" flag on `web/AGENTS.md`/`web/CLAUDE.md`
  was investigated and confirmed to be genuine, harmless Next.js 16.3.2 tooling output (verified
  `node_modules/next/dist/server/lib/generate-agent-files.js` exists and matches verbatim) — no
  action needed. Still awaiting Founder sign-off before Batch 3+.
- 2026-09-14: Founder approved Home (keep existing full-width carousel behavior rather than the
  reference's fixed 220x270px thumbnails — real photos need to support real aspect ratios) and
  gave go-ahead for Batch 3+. Home/Nav/Post Card batch is now DONE (~30% of overall WYN-159
  scope). Starting Batch 3 (Profile, Post Detail) per the binding migration order.
- 2026-09-14: Batch 3 (Profile + Post Detail) complete (~40% of overall WYN-159 scope), after
  one resume following a session rate-limit interruption mid-batch (not a code issue — resumed
  cleanly, no rework needed). Branch `feat/wyn-ux-ui-redesign` commits `fe80aad6` (Profile),
  `22c79759` (Post Detail), `de443591` (legacy CSS retirement), `77596dd6` (docs). Reused
  Home-batch primitives (`WynosAvatar/IconButton/PillButton/Tabs/Header`); preserved WYN-141
  Founder-approved Profile layout metrics (170px cover, 92px avatar, -23px overlap) and all five
  required Post Detail behaviors (5-action row, 2-tab activity sheet, 46px/54px metrics,
  bright-blue caption links). `golden-drop-card.css` still required (Search/Bookmarks/Profile
  feed tabs still consume it) — deliberately not retired this batch. `npm run check` passes (22
  routes). Two self-caught bugs fixed before commit (DOM-nesting mistake in profile header;
  hydration-mismatch from minute-granularity fixture timestamps). Screenshots captured (own
  profile, other-user profile, post detail — mobile+desktop) but show a stray Next.js dev-mode
  indicator badge (bottom-left "N" circle) because this batch screenshotted against `next dev`
  rather than `next start` like the Home batch did — cosmetic screenshot-process issue only, not
  a production artifact, to fix before the next round of screenshots. Two open questions flagged:
  (1) Profile's larger 44px action-pill sizing intentionally differs from Home's compact Follow
  chip — keep or unify later? (2) Header icon sizing was simplified from old WYN-158 per-icon
  pixel values to the standard 22px/44px-box convention — keep simplified or restore exact old
  sizes? Awaiting Founder review before Batch 4 (Search, Notifications, Chat).
- 2026-09-14: Follow-up fix — the earlier Home correction agent (wynos-home.html round) guessed
  Lucide icon equivalents before the Founder's definitive semantic mapping table arrived
  (wynos-home-v2.html). Verified the gap directly against the pushed branch and found 3 real
  mismatches: Comment action used `MessageSquare` (table says `MessageCircle`), Repost/ReDrop
  used `Repeat2` (table says `Repeat`), Home header chat icon used `MessageSquare`. Fixed
  directly (small, low-risk change) across `post-actions.tsx`, `club-feed-post.tsx`,
  `home-header.tsx`, `home-post-card.tsx`, `home-screen.tsx` (ReDrop/Quote sheet rows),
  `post-detail-route.tsx`, `post-detail-fixture.tsx`, and updated the `tokens.ts` mapping
  table/docs to match — commit `3eed2552` on `feat/wyn-ux-ui-redesign`. `npm run check` (lint/
  typecheck/build) reverified clean after the fix. Deliberately left unmigrated screens (Chat,
  Search/Bookmarks/Profile-feed via `golden-drop-card.tsx`, Notifications, deep-link routes)
  untouched — they'll get correct icons when their own batches land, not before.
