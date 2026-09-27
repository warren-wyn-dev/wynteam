# Wynos Android — native app plan (Kotlin + Jetpack Compose)

Status: **approved; M0 done, M1 done except Google sign-in (see M1 status).**

## Founder decision (2026-09-27)

> ต้องการพัฒนา WYNOS Android เป็นแอป Android จริง 100% (Native Android ด้วย Kotlin + Jetpack Compose)
> ไม่ใช้ TWA, PWA หรือ WebView โดยให้ WYNOS Web, Android และ iOS ใช้ Backend/API และฐานข้อมูลร่วมกัน
> มีฟีเจอร์หลักและการทำงานเหมือนกัน รวมถึงข้อมูลที่ซิงก์กันทุกแพลตฟอร์ม แต่ UX/UI ของแต่ละแพลตฟอร์มสามารถแตกต่างกันได้
> ให้ใช้ WYNOS Web Beta 1 เป็นระบบอ้างอิงหลักสำหรับฟีเจอร์และโครงสร้างข้อมูล โดยพัฒนา Android แยกเป็น Native App
> และวางแผนรองรับ iOS ในอนาคต

Platform names (same day): **Wynos Web Beta 1**, **Wynos Android v1.0.0 Beta 1**, **Wynos iOS v1.0.0 Beta 1**.

## Goals

- A native Android app with the same features and behaviour as Wynos Web Beta 1, reading and writing the same Supabase
  database through the same RLS policies and RPCs, so data is identical on every platform.
- Android-appropriate UX (Material 3, system back, system share sheet, notification channels), following the WYN visual
  direction: 80–90% white, 10–20% rainbow accents, dark theme, Thai and English.

## Non-goals (this plan)

- No backend rewrite. The web's Supabase schema, RLS and RPCs are the contract. Any server change needed by Android goes
  through the normal migration approval.
- No iOS code yet. iOS is planned for later (see open decision 5).
- No new product features beyond Web Beta 1 (Beta2 features follow the web's Beta2 gate).

## Architecture

| Area | Choice | Why |
|---|---|---|
| Language / UI | Kotlin, Jetpack Compose, Material 3 | Founder decision; current Android standard |
| Structure | Single `:app` module to start, packages by feature (`feature/home`, `feature/chat`, …) plus `core/` (data, design system, i18n) | Simple first; split modules only when build time needs it |
| Backend client | `supabase-kt` (Auth, Postgrest, Realtime, Storage) over Ktor | Same Supabase API the web uses; publishable key only |
| State | ViewModel + Kotlin Flow, unidirectional state per screen | Standard, testable |
| DI | Manual constructor injection (an `AppContainer`) | Avoids a framework until it is needed |
| Images | Coil 3 | Compose-native, caching |
| Navigation | Navigation Compose, deep links matching web URLs (`/drop/<id>`, `/club/<id>`, `/chat/<id>`, …) | Links and push open the same places as on the web |
| Push | Firebase Cloud Messaging, tokens in the existing `push_tokens` table (`platform = 'android'`), sent by the existing `send-push-notification` Edge Function | No new push backend |
| Auth | Supabase email/password and Google (Credential Manager), session in encrypted storage | Same accounts as the web |
| i18n | Android string resources, Thai (default) and English, following the account's `user_preferences.language_preference` | Same setting as the web |
| Theme | Light/dark/system from `user_preferences.theme_preference` | Same setting as the web |
| Tests | JUnit + Compose UI tests; CI job builds, lints and tests on every PR | Same gates as the web |

Security: publishable key only (never a service key); every permission is enforced by the existing RLS/RPCs; tokens
stored with Android Keystore; no secrets in the repository. See `docs/engineering/SECURITY_RULES.md`.

Location: a new top-level `android/` project. The Flutter `app/` stays untouched until the Founder decides its future
(open decision 4).

## Feature inventory → milestones

Each milestone ships to internal testing only after CI is green and the Founder has seen screenshots.

| Milestone | Web Beta 1 features covered |
|---|---|
| **M0 Foundation** | Project, CI build, design system (colors, type, icons), dark theme, Thai/English, Supabase client, crash-free startup |
| **M1 Account** | Welcome, sign up (2 steps + onboarding profile), login, Google sign-in, forgot/reset password, sign out, account switching (`account/add`) |
| **M2 Feed** | Home feed (for you / following), post detail, like, comment, repost, quote, bookmark, share, compose post (text, images ≤ 9, poll), drafts |
| **M3 Profile** | Own/other profile, edit profile + photo crop, followers/following, follow requests, private accounts, block, report |
| **M4 Notifications** | Notification list and tabs, unread badge, FCM push (keep-on, re-register, account switching rules as on the web), notification settings |
| **M5 Chat** | Conversation list, 1:1 chat, images, view-once, message requests, unread counts, realtime |
| **M6 Clubs** | Explore/join clubs, club page (posts/chat/about), create club, invites, club posts, club chat channels, moderation roles, insights |
| **M7 Discover & settings** | Search, trending top 100, settings (privacy, notifications, theme, language, legal), Wynii, share links / deep links |
| **M8 Release** | Play Store internal testing → closed testing → production (each step needs Founder approval) |

## Founder answers (2026-09-27)

1. **Package name:** the Flutter app was never published, so the native app uses `io.wyn.wyn` (keeps the existing
   Firebase registration). It can still change before the first Play Store upload.
2. **Play Store:** not published yet; the store listing comes at M8.
3. **Minimum Android version:** Android 8.0 (API 26).
4. **Flutter app:** retired on Android once native Android ships; kept for iOS for now (code not deleted).
5. **iOS approach:** decided later.
6. **Order:** start M0 + M1 now, with screenshots to the Founder each milestone.

## M1 status

Done (unit tests + screenshots in `android/app/src/test`):

- Welcome with the invite-code gate, login, sign-up step 1/2, check-your-email, onboarding (photo + bio, skip),
  forgot password, sign out, add account and account switching. The same validation, error wording and database
  writes as the web (`AuthRules`, `AccountFlowViewModel`, `SupabaseAuthRepository`).
- Email links (confirm sign-up, reset password) open the web pages the web already uses (`wynos.online/auth/callback`,
  `wynos.online/reset-password`); the user then signs in to the app.
- Inactive accounts keep their own session in app-private storage (`allowBackup="false"`), like the web's account
  registry; adding an account clears the local session without revoking it.

Still open in M1:

- **Google sign-in** needs an Android OAuth client (package `io.wyn.wyn` + signing SHA-1) in Google Cloud and the
  Supabase Google provider — a Founder/infra step. Until then the button explains it is not available yet.
- Onboarding's photo crop is automatic (centre square); Edit profile has the web's interactive cropper (M3).
- The signed-in screen is a temporary account screen until the M2 feed.

## M2 status

- **M2a Home feed** (#742): For You / Following, post cards, like, save, repost, follow, hide, report.
- **M2b Post detail** (#742): comments and replies, activity, edit (30 min) / delete, report; likes stay in step with Home.
- **M2c Composer + drafts** (#743): text, up to 9 photos with aspect choice (gallery or camera), poll (2-4 options), audience
  (public / friends / only me), 800ms autosave into `drop_drafts`, the drafts list, and publishing through
  `publish_drop` with the web's operation id so a retry after an unclear result never creates a duplicate post.
  Photo rules follow `web/lib/upload-image.ts` (types, 20MB). **Android also removes GPS location from JPEG metadata
  before upload; the web uploads the original file** (recommended follow-up for the web).
- **M2d Quote posts** (#744): Quote card with its own likes/comments/reposts/saves (never the original Drop's),
  menu (share, report, delete own), Quote composer (public posts only, discard prompt), Quote detail page
  with its own comments, and Quotes reposted by people you follow in Following.

## M3 status

- **M3 Profile**: own and other profiles (cover, avatar, bio, website, counts), Posts / Reposts / Likes
  (Likes respect `can_view_likes`), follow / cancel request (asks first) / unfollow, mute, block (asks first),
  report user, suggestions (follow, hide), share `/@username`, followers / following lists.
- **Edit profile**: name, username (taken check), bio, website (http(s) only, like `normalizeExternalUrl`),
  cover (type/size checked, GPS removed) and avatar through an interactive cropper (512×512 JPEG, as the web).
- **Account switcher** moved to Profile → ⋯ → สลับบัญชี (switch, add, remove; up to 9 accounts, as the web).
- "ส่งข้อความ" opens a notice until Chat (M5); ตั้งค่า shows the account screen until Settings (M7).

## M4 status

- **Notifications** (`/notifications` on the web): today / yesterday / earlier sections, likes, comments, reposts and
  follows on the same post grouped per day ("และอีก N คน"), unread dots captured when the screen opens, marking read
  only what was shown (`created_at <= newest`), "see more", pull to refresh, and each row opens its post / profile.
  The web hides the All / Mentions tabs; Android does too.
- **Unread badge** on the Home bell: the server count (DM events excluded), refreshed on open/resume, by pushes and
  every 12 seconds while open; cleared right away when the list is opened.
- **Push (FCM)**: tokens in `push_tokens` with `platform = 'android'`, sent by the existing `send-push-notification`
  function. Same rules as the web: asked once on the main screens (Allow opens Android's question; "not now" waits a
  week), the old account's token is removed before switching / adding / signing out (a failed removal blocks the
  switch), Push comes back for accounts that had it on, never for one that turned it off. Taps open the post or
  profile for the account they were sent to; IDs are checked to be UUIDs.
- **Notification settings** (Settings → การแจ้งเตือน): this phone's Push switch and the seven categories
  (`notification_settings`).
- Firebase is configured from `local.properties` / the environment (not committed): `WYNOS_FIREBASE_ANDROID_APP_ID`,
  `WYNOS_FIREBASE_ANDROID_API_KEY`, `WYNOS_FIREBASE_PROJECT_ID`, `WYNOS_FIREBASE_SENDER_ID`. Without them Push shows
  "not configured" and everything else works.
- The web has no follow-request approval screen in Beta 1, so Android has none either.

## M5 status

- **Chat tab** (web chat-inbox-parity): conversations newest first with unread dots and the unread count on the tab,
  search by name / username / last message, message requests from the ⋯ menu (accept, or delete after confirming),
  and the "chat closed" state when `chat_lockdown_status` says so.
- **Conversation** (Web Beta 1 layout, `threads` off): date separators, bubbles, sent / read ticks from the other
  person's last read, "see earlier messages", sending text and one photo (type/size checked, GPS removed; private
  `chat-media` bucket, shown through 1-hour signed links; a failed send deletes the uploaded photo and restores the
  text), tapping your own message to delete it (after confirming), accept / delete for a received request and
  "waiting" for a sent one, and the profile card with View profile / Follow in an empty conversation.
- **New conversation** from a profile's "ส่งข้อความ": checks `chat_lockdown_status` for that person, opens the
  existing conversation when there is one, and creates it (`get_or_create_conversation`) only at the first send.
  A person you cannot message cannot be sent to.
- Updates arrive through pushes, when the screen comes back, and a check every 5 s (conversation) / 24 s (inbox)
  while the app is on screen. Realtime (Supabase channels) and online dots are not in this milestone.
- Beta 2 chat features (reactions, pins, forward, edit, reply, hide, report message) stay off, as on the web
  (`BETA2_RELEASED.chatThreads = false`). Wynii (the chat pet) comes with M7.

## M6 status

- **Clubs tab** (web ExploreClubs): the "find your community" card with "สร้าง Club", a name search, and
  "กำลังนิยม" (most members) / "ใหม่ล่าสุด" (newest, never repeating a popular Club), without Clubs you have
  joined; join straight from the list (a private Club shows "รออนุมัติ").
- **Create Club**: name (50), description (500), category (50), public / private and an optional photo (type/size
  checked, GPS removed) uploaded to the private `club-media` bucket; the new Club then opens in place of the form.
- **Club page** (web club-detail-golden): banner, photo, members, category, lock, membership button (join, leave or
  cancel a request after confirming; optimistic with rollback), share, and the menu (mute notifications, manage →
  About, leave, cancel request, report). Tabs:
  - **Posts** (pinned first; hidden in a private Club until approved): like, save with undo, share, delete (own or
    moderator, after confirming), pin (moderators, not their own), report, poll voting with results, links, photos.
  - **Chat** (Beta 1, approved members only): channels, the latest 150 messages, text and one photo, delete (own or
    moderator, after confirming) or report others, read marks; refreshed every 5 s while on screen.
  - **About**: details and rules, members, events (members) and 30-day Insights (owner / admin).
- **Home "คลับของฉัน"**: posts from your Clubs, like and open; likes stay in step with the Club page.
- **Club post** page (web ClubPostRoute), **My Clubs** list and the **invite link** screen are built; My Clubs is
  reached from the Home menu (M7), and opening `/club-invite/…` links in the app needs Android App Links, which in
  turn need `assetlinks.json` on wynos.online (a web deploy for the Founder to approve, planned with M8).
- Notifications and pushes about a Club or Club post now open it.
- Beta 2 Club features (announcements, chat edit / pin / search) stay off, as on the web. The web has no way to
  write a Club post in Beta 1, so Android has none either.
- **Next: M7 Search, Settings, Wynii.**

## Risks

- Scope: ~40 web screens and months of web work. Mitigation: milestones, each usable on its own.
- Drift from the web: new web features must be added to Android too. Mitigation: every web feature PR notes its Android
  status; this document tracks parity.
- Behaviour mismatches (push, account switching, drafts). Mitigation: port the web's rules and tests, not just the UI.
