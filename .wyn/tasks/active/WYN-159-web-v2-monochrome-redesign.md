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
