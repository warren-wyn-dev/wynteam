# WYNOS Consumer Web — Phase 5 Production Gate

Status: PRODUCTION LIVE — POST-PARITY PHYSICAL IPHONE RECHECK PENDING
Date: 2026-09-14

## Production result

The WYN-158 Next.js consumer web parity build is live at `https://wynos.online`.

Production evidence:

- UI parity recovery PR #422 merged at `ad29885ce0c200bcb0df9913259fa5112d64e478`.
- One-time production delivery PR #423 merged at `736466af2845cd5f9cdd4de6168f54acbad1763d`.
- GitHub Actions production run `34773878557` completed successfully.
- Vercel production deployment: `https://web-hszululwb-warren14.vercel.app`.
- Vercel aliased the deployment to `https://wynos.online`.
- Production verification succeeded on `/`, `/search`, `/notifications`, `/chat`, `/settings`, `/profile/me`, `/clubs`, and `/bookmarks`.
- The production homepage exposes Next.js `/_next/` assets.
- The legacy `flutter_bootstrap.js` marker is absent.
- No automatic rollback was performed.

The temporary one-time production workflow is removed after successful delivery so it does not become a permanent automatic production path. The normal manual production workflow remains the controlled deployment mechanism for future cutovers.

## Why another physical iPhone check is required

The Founder previously confirmed a physical-iPhone Safari PASS on 2026-09-13, but that check covered the pre-recovery release candidate. After the first Next.js production cutover, the Founder identified that the UX/UI still differed from the Flutter WYNOS design. A substantial parity recovery was then implemented across Welcome/Auth, Home, Search, Profile, Notifications, Chat, Settings, navigation, Clubs/Bookmarks and Post Detail.

Because those visual changes happened after the earlier device PASS, the earlier PASS must not be treated as proof of the final live parity build. Automated WebKit is supplemental evidence, not a replacement for a fresh real-device visual check.

## Automated parity gates — PASS

The final parity head passed:

- Next.js lint, TypeScript and production build.
- Browser/OS system-font guard.
- iPhone-like WebKit browser QA.
- Android-like Chromium browser QA.
- Desktop Chromium browser QA.
- Route-churn/session survival checks.
- Horizontal-overflow and fatal-page-error guards.
- Full repository CI: Flutter, PostgreSQL/RLS, Admin, Supabase Edge Functions and schema ordering.
- Source-contract guards for Home, Search, Profile, Chat, Notifications, Settings, Side Menu and Post Detail.

The final Post Detail contract includes:

- Five actions: Like, Comment, Repost, Share and Save.
- Multi-image gallery.
- Threaded comments/replies and pagination.
- 46px comment composer.
- 54px `ดูกิจกรรม` row.
- `กิจกรรมโพสต์` sheet with exactly `ถูกใจ` and `รีโพสต์` tabs only.

## Fresh live-iPhone checklist

Use a physical iPhone with Safari and open `https://wynos.online` directly.

### 1. Welcome and authentication

- Welcome screen visually matches the original WYNOS Flutter flow.
- `WYNOS`, `BETA`, supporting copy and `เริ่มต้นใช้งาน` spacing look correct.
- Google and email sign-in choices appear in the expected flow.
- Sign-in returns to WYNOS without a protection loop or blank page.

### 2. Home and root navigation

- Home has exactly `สำหรับคุณ / กำลังติดตาม / คลับของฉัน`.
- Header, WYNOS logo, menu and Chat control align like the original.
- Post header/caption/action spacing is compact like the Flutter golden master.
- Links and hashtags use the expected bright blue.
- Bottom navigation does not collide with the Safari toolbar/home indicator.
- Like, Save, Repost and Follow interactions remain tappable and stable.

### 3. Search and Profile

- Search starts with the search field rather than a duplicate title header.
- Trending/suggested content spacing matches the original structure.
- Profile cover/header overlay, avatar, identity, actions and tabs align correctly.
- Profile tabs are `โพสต์ / รีโพสต์ / ถูกใจ` (no separate media tab; the Posts feed already includes text and media posts).
- Other-user profiles can show `แนะนำสำหรับคุณ` without breaking scroll/header behavior.

### 4. Notifications, Chat and Settings

- Notifications root chrome and tabs are aligned and usable.
- Chat uses `ทั้งหมด / ยังไม่อ่าน`; message requests are separate.
- Inbox/thread scrolling and keyboard/composer behavior remain stable.
- Settings sections and `V1.0.0 Beta4` footer display correctly.

### 5. Post Detail

- Open a real Drop from Home.
- Confirm the focused action row shows Like, Comment, Repost, Share and Save.
- Confirm image/media corners and gallery behavior match the Flutter screen.
- Confirm comments and replies render correctly and the composer stays clear of the home indicator.
- Tap `ดูกิจกรรม` and confirm the sheet heading is `กิจกรรมโพสต์`.
- Confirm it contains only `ถูกใจ` and `รีโพสต์`; there must be no `ทั้งหมด` tab.

### 6. Safari stability

- No unintended horizontal scrolling.
- No content hidden behind notch/Dynamic Island/status bar/home indicator.
- Rotate portrait → landscape → portrait and confirm the layout remains usable.
- Rapidly move Home → Search → Notifications → Chat → Profile → Home for at least 3 cycles.
- Reload several routes and background/restore Safari without crash, blank screen or forced sign-out.

## Completion rule

Phase 5 production deployment and automated verification are complete. WYN-158 remains ACTIVE only for the fresh physical-iPhone Safari parity confirmation of the live build.

When the Founder confirms that the live production UI/UX matches the original WYNOS experience and no device blocker is present, the task can be marked COMPLETE. Do not automatically rollback if a blocker is found; preserve evidence and apply a Founder-directed fix.