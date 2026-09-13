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

## Phase 1 scope

- Next.js 16 + React 19 + TypeScript foundation.
- Browser system-font CSS stack; no font assets and no `@font-face`.
- Existing Supabase publishable-client configuration only; no service-role key in the browser.
- Existing `is_developer_account()` RPC used as a fail-closed internal preview gate.
- Existing `get_wynos_ranked_feed()` RPC used for the first read-only Home feed migration slice.
- Mobile-first WYNOS Home shell matching current palette, spacing direction, tabs, post cards and bottom navigation.
- Native browser `<img>` for feed/avatar images.
- CI for lint, TypeScript and production build.

## Out of scope for Phase 1

- Production cutover.
- Database/schema changes.
- Replacing or deleting the Flutter app.
- Write actions such as Like, Repost, Comment, Create Drop, Follow or Save.
- Full route migration (Profile/Search/Notifications/Chat follow in later slices).
- Any new WYNOS version number.

## Acceptance criteria

- `web/` builds with no secrets committed.
- No Apple/SF Pro font files are bundled.
- CSS uses browser system fonts.
- Signed-out preview offers the existing Supabase Google OAuth path.
- Signed-in non-developer accounts fail closed and cannot see the migrated preview.
- Developer accounts can load ranked Drop rows using existing Supabase/RLS.
- Home layout is responsive and optimized for iPhone width/safe areas.
- Existing Flutter production behavior is untouched.
- CI passes before merge.
