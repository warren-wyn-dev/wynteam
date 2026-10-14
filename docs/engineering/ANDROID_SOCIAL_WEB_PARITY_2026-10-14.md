# WYNOS Social Android Beta 1 — Web parity acceptance

**Goal:** Match `wynos.online` Web mobile experience for the **same authorized account** as closely as feasible while remaining a real Kotlin/Jetpack Compose Android application. "100%" means no unexplained, user-visible discrepancy in agreed supported flows; **it is not yet achieved or certified.** Android native system bars, permissions, keyboard and Back navigation follow Android conventions rather than copying browser chrome.

Canonical reference: the current **Social** Web implementation in `web/`, especially `web/app/home.css`, `web/app/bottom-nav.css`, `web/app/threads-action-row.css`, `web/components/home/`, `web/components/profile-*`, and auth/chat/composer. Do not use `food.wynos.online` or `food-android/` as the Social design target.

## Changes on Draft PR #1157 (2026-10-14)
- Native Home verified post badges now reuse the same gold rosette `VerifiedBadge` as the native Profile (replacing the blue text check).
- Native Home post typography/spacing follows canonical Web Home CSS (15sp author, 16sp/21sp caption, 3dp caption gap).
- Native Home post at <=359dp viewport follows the Web 12px outer padding, 34px avatar, 8px gutter and compact time label.
- Native bottom navigation follows the Web 68px visual dock, 32px icon, 5px icon-to-label spacing, 11px text and #8e8e93 inactive tint; preserve Android's platform navigation-bar inset.
- Robolectric screenshot checks added for Thai verified Home at 411dp and for a 340dp narrow viewport with readable tab labels and dock.

Those changes **are code-level parity improvements**, not proof of pixel-perfect parity on physical hardware or of connected backend feature correctness. Verify the latest CI head, not old successful runs.

## Screenshot protocol (mandatory before any 100% claim)

1. **Same content:** Use a dedicated test account in the same Supabase project; compare Web `wynos.online` and the manual `connected-qa` Android APK. Never use fixture/mock or unconfigured APK screenshots as evidence of connected production parity.
2. **Same conditions:** 340dp, ~393dp (Pixel 5), 411dp; Thai + English, Light + Dark, font scale 100% plus enlarged accessibility font; same post IDs, images, language, appearance, network.
3. **Capture:** For Web, capture the current public UI / authorized dedicated QA login at matching **CSS viewport widths**. For Android, capture the installed native build with the same content. Store only redacted QA screenshots. CI Roborazzi snapshots are structural smoke checks, *not* a substitute for paired real-device screenshots.
4. **Compare per screen:** Home/For You, Following, My Clubs, bottom dock, Feed post header/caption/media/action row, post detail/comments, Profile own/other, follows, search, create-post/drafts, Clubs, Chat inbox/thread, Notifications, account/onboarding and Settings.
5. **Record discrepancy:** Web and Android screenshots, exact UI element, deviation in dp/px or behavior, reproduction steps, severity and owner. Fix and repeat on both 393dp and 340dp before closing.

## Functional parity gates (unverified until tested with real QA accounts)

| Feature | What must match Web | Current evidence/gate |
| --- | --- | --- |
| Accounts | Email registration/confirmation, sign-in, reset, saved accounts, sign-out, private session isolation | Native code/tests exist; paired connected-device QA required |
| Google sign-in | Same login as Web using approved Android OAuth client | **BLOCKED:** Android Google flow currently unavailable; needs external OAuth configuration + QA |
| Home/Feed | Ranking visibility, Following, Clubs, freshness, hide, like/save/repost, comments, media, shares | Native code exists; latest patches/screenshots/paired device QA pending |
| Post composer | Caption, 9 images, polling, drafts, audience, optimistic/safe publication retry | Native code exists; live cross-device QA pending |
| Profile | Header, avatar, Verified, following, bio, cover, settings and other-user views | Native code exists; paired screenshot QA pending |
| Search and Clubs | Search results, discovery, membership, posting and permissions | Native code exists; live RLS/role QA pending |
| Chat | Inbox, requests, message sending/read receipts, image attachments, account switch isolation | Native code exists; two-account/reconnect QA pending |
| Notifications | In-app, badge, deep links, FCM delivery and preference controls | FCM Android credentials/on-device QA still required |
| Navigation | Native Back, edge-to-edge, bottom nav, Home scroll immersive chrome | Home scroll-to-hide/chrome/FAB behavior **not yet verified/matched** |
| Data rights | Shared RLS, deleted content visibility, privacy/account deletion and user-generated-content obligations | End-to-end security, deletion and Play review incomplete |

## Do not release until
- Exact Android head passes `assembleDebug testDebugUnitTest lintDebug bundleRelease` and screenshot tests.
- Manually dispatched **connected QA** APK launches and passes on physical Pixel 5 / Android 12 plus Android 16, across network loss/reconnect.
- Every discrepancy in this matrix is resolved or explicitly scoped/approved by the Founder. No unverified "100%" or "Play ready" statements.
- Signing, Play requirements, OAuth/FCM, privacy/Data Safety and approvals are completed separately.

**Safety:** this PR must remain Draft; no merge to `main`, signed AAB, Play upload, production Web/DB edits, or real-user-content mutation merely to pursue parity.
