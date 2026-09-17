# WYN-162 — Home Threads-like UI refresh

Status: implementation / staging QA
Owner: Founder
Priority: P1
Scope: `web/` Home surface only

## Founder-approved intent

Refresh the existing WYNOS Home UI to match the approved light, minimal, Threads-like WYNOS mockup while preserving every existing WYNOS feature, route, data flow and business action.

The visual artifact was iterated and approved directly by the Founder on 2026-09-17 before coding. This task implements that WYNOS mockup; it does not copy third-party assets, source code or branding.

## Requirements

1. Preserve Header actions: menu, WYNOS wordmark, search and notifications.
2. Preserve exactly three Home feed modes: `สำหรับคุณ`, `กำลังติดตาม`, `คลับของฉัน`, including existing tap/swipe behavior.
3. Replace the selected tab pill with bold text + a thin dark underline.
4. Preserve post avatar, display name, timestamp/location, caption, media, hashtag/link rendering, Like, Comment, Repost, Share and Save behavior.
5. Do not show an `@username` beside the display name in the Home feed. Repost attribution must also omit the `@` prefix.
6. Show a follow control for every non-self author:
   - not followed: `ติดตาม`, gray filled pill;
   - followed: `กำลังติดตาม`, white/light surface with gray border;
   - pending private request: `ขอติดตามแล้ว`, white/light surface with gray border.
   The control remains visible after follow so the state is explicit; tapping it continues to use the existing follow/unfollow/request behavior.
7. Preserve the five bottom destinations exactly: `หน้าหลัก`, `คลับ`, `โพสต์`, `แชท`, `โปรไฟล์`. Remove the decorative selected tile/floating-dock treatment only; do not change destinations or behavior.
8. Keep WYNOS design tokens, WYNOS logo/assets and system font stack. Do not add third-party UI assets or fonts.
9. Mobile-first responsive behavior must remain usable at 320/390/430px and centered/readable at 768/1024/1440px, including safe areas.
10. Preserve accessibility focus states, reduced-motion behavior and existing keyboard/touch semantics.

## Out of scope

- Backend/schema/RLS changes.
- New product features.
- Changes to Post Detail, Profile, Chat, Club, Search or other routes beyond shared bottom-navigation presentation.
- Version bump or automatic rollback.
- Production deployment before explicit Founder production approval after staging evidence.

## Acceptance criteria

- Home visually follows the approved WYNOS mockup: light/minimal chrome, underline tabs, compact continuous feed, gray follow button states and plain bottom bar.
- No Home feed author/repost `@` prefix remains.
- Existing Home actions and navigation contracts remain intact.
- Follow, following and requested states are covered by deterministic fixture/test evidence.
- Lint, typecheck, build and browser regression tests pass.
- WebKit iPhone-like, Chromium Android-like and desktop Chromium browser QA pass without horizontal overflow or navigation regression.
- Staging/preview is verified before requesting Founder production authorization.

## Recovery

Fix forward on this branch/PR if QA finds a regression. Do not rollback production automatically; the Web Beta1 rollback/version rule remains in force.
