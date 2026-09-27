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
- The photo crop is automatic (centre square); the web's interactive cropper comes with M3 (edit profile).
- The signed-in screen is a temporary account screen until the M2 feed.

## Risks

- Scope: ~40 web screens and months of web work. Mitigation: milestones, each usable on its own.
- Drift from the web: new web features must be added to Android too. Mitigation: every web feature PR notes its Android
  status; this document tracks parity.
- Behaviour mismatches (push, account switching, drafts). Mitigation: port the web's rules and tests, not just the UI.
