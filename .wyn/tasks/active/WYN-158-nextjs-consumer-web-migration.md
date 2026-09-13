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

Founder explicitly asked to start Phase 2 after Phase 1 merged. Phase 2 remains developer-gated and does not authorize public rollout.

Completed through PR #412 and squash-merged to `main` at `41ac064cc3e69cc75a2ea69c6f598f9a5540a373`:

- Existing ranked For You feed plus migrated Following and Trending sources.
- Bounded infinite feed reveal with stale-request protection when switching surfaces quickly.
- Like, Save and Standard Repost through the existing RLS-protected tables.
- Public Follow and Private-account Follow Request states through the existing `follows` / `follow_requests` contracts.
- Optimistic interaction UI with per-action in-flight serialization and rollback on write failure.
- Post detail sheet with paginated comments, comment creation and comment likes.
- Create Drop composer for text and up to nine images, using the existing `drop-images` storage bucket and atomic `publish_drop` RPC.
- Publication operation IDs and deterministic object paths are retained for ambiguous network outcomes; both thrown transport failures and PostgREST-returned network failures are reconciled through `drop_id_for_publication()` before cleanup/retry, so the browser does not knowingly create a duplicate Drop or delete committed publication assets.
- Home Trending keeps Flutter Home's 10-result contract while preserving the backend's authoritative ordering.
- Browser-native text and image rendering stays in place; no Apple/SF Pro font files are bundled.

### Phase 2 acceptance criteria — passed

- Consumer Web run `34759152044`: ESLint, TypeScript, Next.js production build and font-license guard all passed.
- Full repository CI run `34759152039`: Flutter analyze/tests, maintained PostgreSQL/RLS tests, Edge Functions, schema ordering and Admin checks all passed.
- Existing Supabase schema/RLS contracts are reused without weakening authorization.
- No service-role/management secret is introduced into browser code.
- For You, Following and Trending Drop surfaces load from the same backend contracts as Flutter.
- Like, Save, Standard Repost, Follow/Follow Request, Comment, Comment Like and Create Drop have explicit error handling and duplicate-write protection.
- Lost/ambiguous publication responses reuse the same operation id on retry.
- New Home behavior remains developer-only; `wynos.online` Flutter Production is unchanged.

## Still outside Phase 2

- Public production cutover.
- Replacing or deleting the Flutter app.
- Full route migration: Search, Profile, Notifications, Chat, Settings and deep-link routing follow in Phase 3.
- Pixel/interaction parity across every platform and physical-device stress QA follow in Phase 4.
- Staging-to-production domain cutover follows in Phase 5 and requires separate Founder approval.
- Any new WYNOS version number.
