# Wynos Android — Play Store release (M8)

Founder approved starting M8 on 2026-09-28. Each Play track still needs its own Founder approval:
**internal testing → closed testing → production**. Staging or internal approval is not production approval.

## What the repository now has

| Item | Where |
| --- | --- |
| Release build: R8 minify, signed with the upload key when it is configured, unsigned otherwise | `android/app/build.gradle.kts` |
| App Links: `https://wynos.online/drop/…`, `/quote/…`, `/club/…`, `/club-post/…`, `/club-invite/…` open in the app | `AndroidManifest.xml`, `core/link/AppLink.kt` |
| Digital Asset Links file served at `https://wynos.online/.well-known/assetlinks.json` | `web/app/.well-known/assetlinks.json/route.ts`, `web/lib/android-asset-links.ts` |
| Version | `versionCode = 1`, `versionName = "1.0.0-beta1"` (raise `versionCode` for every upload) |

Only links with a valid id (UUID) or invite code open a screen; any other link just opens the app. Links that must
stay on the web (sign-up confirmation, password reset, `/auth/…`) are not claimed. If the person is signed out, the
link opens after they sign in.

## Founder / infra steps (nothing secret goes into git)

1. **Upload key.** Create it once on a trusted machine and keep a backup outside the repository:
   `keytool -genkeypair -keystore wynos-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`
2. **Build settings** in `android/local.properties` (git-ignored) or the environment:
   - `WYNOS_SUPABASE_URL`, `WYNOS_SUPABASE_PUBLISHABLE_KEY` (the web's public values)
   - `WYNOS_FIREBASE_ANDROID_APP_ID`, `WYNOS_FIREBASE_ANDROID_API_KEY`, `WYNOS_FIREBASE_PROJECT_ID`,
     `WYNOS_FIREBASE_SENDER_ID` (Firebase Android app `io.wyn.wyn`)
   - `WYNOS_UPLOAD_STORE_FILE`, `WYNOS_UPLOAD_STORE_PASSWORD`, `WYNOS_UPLOAD_KEY_ALIAS`, `WYNOS_UPLOAD_KEY_PASSWORD`
3. **Build:** `cd android && ./gradlew bundleRelease`, which writes `app/build/outputs/bundle/release/app-release.aab`.
4. **Play Console:** create the app `io.wyn.wyn` and turn on Play App Signing. Then upload the `.aab` to **internal testing**.
5. **App Links:** copy the SHA-256 fingerprints from Play Console → App integrity (the app signing key, and the upload
   key). Set them in Vercel as `ANDROID_APP_SHA256_FINGERPRINTS=AA:BB:…,CC:DD:…`, then deploy the web. That deploy is a
   production web deploy and needs Founder approval.
   - Check: `curl https://wynos.online/.well-known/assetlinks.json`.
   - Check on a phone: `adb shell pm get-app-links io.wyn.wyn` should show `wynos.online: verified`.
   - Until then, links still open the web.
6. **Google sign-in:** add an Android OAuth client in Google Cloud for package `io.wyn.wyn` and the same SHA-1s. Until
   then the button explains that Google sign-in is not available yet.
7. **Store listing and policies:** see the draft below.
   - Play requires a **public privacy policy URL** and a **web page or link for account deletion requests**. Today the
     privacy policy and terms exist only inside the app (Settings → legal documents); the web has no public page for
     them yet. The Founder must decide where they are published.
8. **Internal testing QA** on real phones before asking for closed testing. Use the checklist below.

## Internal testing checklist (real devices, release build)

R8 only runs on the release build, and no emulator is available in CI, so these must be checked on the internal
testing build:

- Sign up with an invite code, sign in, sign out, add and switch accounts.
- Home feed, like, save, repost, quote, post detail, comments. Compose with photos, a poll, and drafts.
- Profile, edit profile (avatar crop), follow and unfollow, private account requests.
- Notifications list, and a push arriving and opening the right screen (Android 13+ permission prompt).
- Chat: inbox, requests, sending text and photos, Wynii.
- Clubs: explore, join, leave, club post, club chat. Also an invite link opened from another app (after step 5).
- Search, trending, saved, settings (privacy, password, theme, language, export, legal documents).
- Thai and English, light and dark, and a small phone with Android 8.0.

## Store listing draft (for the Founder to edit)

- **App name:** WYNOS
- **Short description (TH):** WYNOS — chat, profile และ feed ในที่เดียว
- **Short description (EN):** WYNOS — chat, profile and feed in one place
- **Category:** Social
- **Icon:** `web/public/icons/icon-512.png` (512×512)
- **Screenshots:** from the internal testing build on a phone (Thai first)
- **Content rating / target audience:** Founder answers the questionnaires
- **Data safety (from what the app does):**
  - Collects account details (email), profile details (name, username, photo, bio), posts, photos, messages and
    Club content you create.
  - Collects the push token for notifications.
  - Data is sent over HTTPS and is not sold.
  - The account can be deleted in the app (Settings → Account), and data can be exported there.
  - Location is not collected by the app.
  - GPS data is removed from JPEG photos before upload.
  - HEIC, PNG and WebP photos are uploaded as they are, as on the web.
  - Answer the Data safety form with this in mind, or approve extending GPS removal to those types first.
