# WYNOS Consumer Web — Phase 5 iPhone Safari Gate

Status: PHYSICAL IPHONE PASS — PRODUCTION CUTOVER PENDING
Date: 2026-09-13

The Founder confirmed on 2026-09-13 that the final physical-iPhone Safari release-candidate check passed. Automated WebKit emulation remains supplemental evidence and did not replace the real-device check.

## Safety boundary

- The real-device gate was performed against the Vercel Preview deployment produced by the Phase 5 preview workflow.
- Keep Vercel Preview Deployment Protection enabled outside automation-only bypass windows.
- Do not weaken Supabase Auth/RLS or expose management/service-role credentials for testing.
- Do not perform an automatic rollback. Preserve evidence and wait for Founder-directed recovery if a blocker appears.

## Required device check

A physical iPhone with current Safari was used for the final Founder-reported release-candidate check.

### 1. Launch, viewport and safe areas

- Open the Phase 5 Vercel Preview directly in Safari.
- Confirm the page loads without a blank screen, crash, continuous reload or Vercel protection loop after authentication.
- Confirm content is not hidden behind the Dynamic Island/notch, status bar, browser toolbar or home indicator.
- Confirm no unintended horizontal scrolling on Home, Search, Notifications, Chat, Settings and Profile.
- Rotate portrait → landscape → portrait and confirm the layout remains usable.

### 2. Typography and rendering

- Confirm Thai and Latin text render cleanly with the iPhone/browser system font.
- Confirm there is no visibly substituted webfont, broken glyph, clipping or text overlap.
- Confirm icons, avatars, cards, separators and action rows remain aligned after scrolling and rotation.

### 3. Authentication and session stability

- Sign in through the normal Google/Supabase flow using an authorized developer account.
- Confirm the OAuth return lands back on the preview and the developer gate opens normally.
- Reload the page at least 5 times across different routes and confirm the session survives.
- Background Safari, return to it, and confirm the page remains usable without a crash or forced sign-out.

### 4. Core routes

Open and interact with each route from in-app navigation rather than only pasting URLs:

- Home `/`
- Search `/search`
- Notifications `/notifications`
- Chat `/chat`
- Settings `/settings`
- Own profile `/profile/me`

For each route, confirm normal scrolling, no fatal error screen, no horizontal overflow, and no full-page navigation regression for app-local links.

### 5. Media and long-content stress

- Scroll a media-heavy Home feed repeatedly from top to lower content and back.
- Open image/media content and return to the feed several times.
- Rapidly switch between Home → Search → Notifications → Chat → Profile → Home for at least 3 cycles.
- Confirm images do not leave permanent blank blocks and Safari does not reload/crash the tab.

### 6. Interaction sanity

Using the developer account, verify representative signed-in flows that are safe to exercise:

- Like/save/repost and undo where applicable.
- Open a post detail and comments.
- Search and open a profile.
- Open Notifications and navigate to referenced content/profile/chat where data is available.
- Open Chat and confirm inbox/thread rendering; send a test text only if an appropriate test conversation exists.
- Open Settings and confirm controls render and remain tappable without accidental layout shifts.

Avoid destructive account actions during release-candidate QA unless they are being tested intentionally with disposable data.

## Gate result

Physical-iPhone Safari gate: **PASS** — Founder confirmed on 2026-09-13.

The production workflow is now eligible to be run from `main` only with both exact confirmations:

- `CUTOVER-WYNOS-ONLINE`
- `IPHONE-PASS`

After production deployment, verify `wynos.online` core routes and signed-in flows again before Phase 5 is marked complete.
