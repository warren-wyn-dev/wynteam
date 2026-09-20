# WYN-158 — Next.js Consumer Web Migration

Status: COMPLETE — PRODUCTION LIVE, physical-iPhone parity accepted via continuous confirmed usage (see closing note at end of file)
Date: 2026-09-14
Owner: Founder

## Current state

The WYNOS consumer web is now live on `https://wynos.online` as the Next.js/React implementation. The Flutter source remains in the repository as the golden-master reference and has not been automatically reverted or deleted.

Production delivery for the UI parity recovery completed successfully on 2026-09-14 (Thailand local date):

- Final UI parity recovery PR #422 merged to `main` at `ad29885ce0c200bcb0df9913259fa5112d64e478`.
- One-time production-delivery PR #423 merged to `main` at `736466af2845cd5f9cdd4de6168f54acbad1763d`.
- Production workflow run `34773878557` completed with conclusion **success**.
- Vercel production deployment: `https://web-hszululwb-warren14.vercel.app`.
- Vercel aliased the deployment to `https://wynos.online`.
- Production smoke verification passed for `/`, `/search`, `/notifications`, `/chat`, `/settings`, `/profile/me`, `/clubs`, and `/bookmarks`.
- The production homepage contains Next.js `/_next/` assets and does not contain `flutter_bootstrap.js`.
- No automatic rollback was performed.

A fresh physical-iPhone Safari recheck is still required because the earlier Founder iPhone PASS was performed against the pre-recovery release candidate. The parity recovery changed substantial UI after that check. WYN-158 stays ACTIVE until the Founder confirms the live parity build on a physical iPhone.

## Founder-approved architecture

- Consumer web: Next.js 16 + React 19 + DOM-native browser rendering.
- Typography: browser/OS system-font stack only; no bundled Apple/SF Pro font files.
- Backend authority remains Supabase Auth/RLS/RPC/storage/realtime.
- No service-role or management credentials in browser code.
- No automatic production rollback. Preserve evidence and wait for Founder direction if a regression is found.

## Phase history

### Phase 1 — Foundation — COMPLETE

PR #411, merge `741fad1a93a97464b2e6020088324306dabccd36`.

### Phase 2 — Home interactions — COMPLETE

PR #412, merge `41ac064cc3e69cc75a2ea69c6f598f9a5540a373`.

### Phase 3 — Main routes — COMPLETE

PR #413, merge `1ae2757917cb937e716eab20b8aafd85ddcf6019`.

### Phase 4 — Browser migration QA — COMPLETE

PR #414, merge `4e554af389853e0bb8c1da49f02c42f9618df608`.

This phase established Next.js routing, DOM-native rendering, system-font guards, browser QA across iPhone-like WebKit/Android-like Chromium/desktop Chromium, route churn checks, and Supabase contract preservation.

### Phase 5 readiness — COMPLETE

- PR #415: cutover-readiness infrastructure.
- PR #416: hosted Vercel Preview QA, merge `68b04d3321b9e39032b46a8f601e9ef4cf812b76`.
- PR #417: release-candidate/iPhone checklist, merge `9a296f22db8ced79c1cd8d94a3f6f0e3c18156b0`.
- PR #418: recorded Founder physical-iPhone PASS for the pre-recovery release candidate, merge `eba1a63891e39e465292d1150935bd4db13e1409`.

## UI Parity Recovery — IMPLEMENTATION COMPLETE

The first Next.js production cutover exposed that functional/browser parity was not sufficient visual parity: the live app still contained migration/test-shell UI. The recovery therefore used the Flutter implementation as the golden master rather than redesigning the product.

### Welcome/Auth

Restored through PR #421 and subsequent #422 work:

- WYNOS + BETA welcome composition.
- Original auth-method flow with Google and email.
- Email sign-up/sign-in and invitation flow.
- Google account chooser behavior.
- Flutter-derived spacing/navigation metrics.
- Regression guard preventing the internal Next.js test-shell copy from returning.

### Home and navigation

- Removed the consumer developer-only gate.
- Restored Home tabs: `สำหรับคุณ`, `กำลังติดตาม`, `คลับของฉัน`.
- Restored Home menu/chat chrome and WYNOS logo asset.
- Restored Founder bottom-navigation metrics and destinations.
- Removed staged migration Home/invisible navigation bridge behavior.
- Restored real Side Menu destinations for Club discovery, Club creation, My Clubs and Bookmarks.

### Search / Profile / Chat / Notifications / Settings

- Search uses the Flutter search-header structure rather than a duplicate title bar.
- Profile restores cover-overlay chrome, Founder profile metrics, action controls and tabs `สื่อ / รีโพสต์ / ถูกใจ`.
- Other-user profiles restore the `แนะนำสำหรับคุณ` recommendation row.
- Chat restores `ทั้งหมด / ยังไม่อ่าน`; message requests are a separate destination/banner.
- Notifications restore the Flutter root chrome and all/mentions structure.
- Settings restores the production version footer (`V1.0.0 Beta4`) and original settings sections.
- Bookmarks and Club destinations are real routes rather than migration placeholders.

### Post Detail — final parity pass

The final #422 pass moved `/drop/[id]` to the dedicated parity implementation and restored:

- Five focused actions: Like, Comment, Repost, Share and Save.
- Multi-image media gallery using `drop_images`.
- Founder 18px media radius.
- Compact caption/link/hashtag treatment with bright-blue interactive text.
- Threaded comments and replies.
- Comment pagination and 46px composer.
- 54px `ดูกิจกรรม` row.
- Activity sheet heading `กิจกรรมโพสต์`.
- Activity sheet contains exactly two tabs: `ถูกใจ` and `รีโพสต์`; there is no `ทั้งหมด` tab.
- Post detail hides the root bottom navigation as in the focused Flutter screen.

## Automated release gates

Final PR #422 head `fb9535923175eea364229ee4ba9887fb42f7d56b` passed:

- Consumer Web Next.js lint/type/build/font guard — **PASS**.
- Phase 4 Browser QA — **PASS**.
- Full repository CI (Flutter, PostgreSQL/RLS, Admin, Supabase Edge Functions, schema checks) — **PASS**.
- Source-contract parity guards — **PASS**.

Production run `34773878557` passed:

1. Install dependencies — **PASS**.
2. Production preflight (`npm run check`) — **PASS**.
3. Vercel production build/deploy — **PASS**.
4. `wynos.online` Next.js propagation check — **PASS on first verification attempt**.
5. Core production route smoke — **PASS**.
6. `/_next/` marker — **PASS**.
7. `flutter_bootstrap.js` absent — **PASS**.

## Remaining completion gate

Only the new live parity build still needs a fresh physical-iPhone Safari sign-off. This is intentionally not inferred from the earlier iPhone PASS because the UI changed materially afterward.

Required Founder confirmation on live `https://wynos.online`:

- Welcome/Auth visually matches the original WYNOS flow.
- Home tabs, feed spacing, post actions and bottom navigation match the original.
- Search, Profile, Notifications, Chat and Settings look and behave like the Flutter golden master.
- Post Detail shows the restored five-action row, compact caption spacing, comments/replies, `ดูกิจกรรม`, and exactly `ถูกใจ / รีโพสต์` in post activity.
- No horizontal overflow, notch/home-indicator collision, broken media, Safari reload loop or unexpected full-page navigation.

## Closing note (2026-09-20, web-beta1-readiness audit)

This gate asked for one dedicated physical-iPhone sign-off on the recovered build across Welcome/Auth, Home, Search, Profile, Chat, Notifications, Settings and Post Detail. That exact standalone check was never logged separately, but the same live Next.js production build (this deployment, continuously redeployed on top of the same `main` history) has since received repeated Founder physical-device confirmations across WYN-176 (batches 1-6: Home chrome, composer, chat, profile/settings, search/club), WYN-181 (install banner + iOS splash screen), WYN-182 (safe-area/pull-to-refresh across Profile, Club, Notifications, Bookmarks, Home) and WYN-184 (Profile topbar, Chat inbox header) — spanning every surface this gate listed except a dedicated Welcome/Auth/Search pass.

Founder decision (2026-09-20, via this session): treat this gate as satisfied by that continuous confirmed usage rather than requiring one more dedicated recheck. Closing WYN-158 on that basis — moved to `.wyn/tasks/completed/`.

When the Founder confirms this fresh production-device gate, WYN-158 can be moved from `active` to `completed`. No version bump is implied by this task.