# WYNOS Android v1.0.0 Beta 1 — real-device APK testing

**Purpose:** Give the Founder with a physical Android phone an installable debug APK for **technical checks**, before Google Play review. **No Play track upload or publication is authorized.**

## Build artifact on the current PR

- PR: https://github.com/warren-wyn-dev/wynteam/pull/1157
- On the latest PR head, GitHub Actions workflow **Android** executes `assembleDebug testDebugUnitTest lintDebug bundleRelease`.
- After all tasks pass, `Upload Beta 1 debug APK (device QA only)` publishes the artifact named **`wynos-android-beta1-debug-apk`**, containing `app-debug.apk`, retained for **7 days**.
- The artifact is an **APK zipped by GitHub Actions**. It is **not** the signed release **AAB**, and is **not** sent to Google Play.
- **Important:** CI PR builds intentionally have **no production Supabase/Firebase configuration**; the APK is useful for install/launch and compatibility verification, but the app may display “not configured” instead of allowing login/feed/chat. **Do not claim functioning live features or capture misleading Google Play screenshots from this build.**
- The APK is signed using Android's temporary debug signing key generated on the runner. Its certificate may differ between GitHub runners, so installing a later debug APK over it can fail with signature mismatch. Back up required test data before uninstall/reinstall, and **never uninstall an app containing data you need**.

## Download/install on an Android device

1. Sign in to GitHub and open **https://github.com/warren-wyn-dev/wynteam/pull/1157** → **Checks** → **Android** → most recent **successful** workflow run (ensure it matches the latest commit).
2. Find **Artifacts** → `wynos-android-beta1-debug-apk` and download it. GitHub downloads a **ZIP**.
3. Open the Android Files app → Downloads → extract the ZIP → find `app-debug.apk`. **Only use the file from the official WYNOS GitHub repository; do not install a reuploaded APK from anyone else.**
4. Tap `app-debug.apk`. If Android prompts, grant **Install unknown apps** to your chosen Files/browser app **temporarily**. After installing, disable that permission again. Google Play Protect may warn that a debug app wasn't sourced from Play; do not override a strong/high-risk security block.
5. Open WYNOS. Note Android version, phone model, whether the app starts without crash, UI insets/safe areas and whether configuration is missing. Record any error **without exposing account credentials or real users' data**.

## Real-account testing comes after protected configuration

A fully working signed/test build requires approved Supabase **public client** URL/key and Firebase Android configuration in an appropriate protected build workflow. The current GitHub PR/CI intentionally injects none. Do **not** put production or private keys in a public repository, PR text, screenshots or untrusted pull-request build. Google sign-in also requires an Android OAuth client and certificate fingerprints; the code currently displays `google_not_ready`. Do not treat the debug artifact as a Play-ready release.

For real feed/chat/post/club screenshots, obtain a **configured, verified Android build with Founder approval** and use the actual Android app on the phone. Only then capture authentic Android screenshots for Play listing. Do not substitute iPhone Web or mockup screens.

## Post-install QA checklist

- [ ] App starts on Android 8+; log device model/API and crash details
- [ ] Android 16 / gesture navigation / status and bottom bars do not cover app content
- [ ] Thai/English text layout and light/dark themes (if navigable) work
- [ ] No unsafe permissions or signing warnings
- [ ] If configured: signup/email sign-in, password reset, profile, feed and images, chat/club, notifications, report/block, account switching and account deletion
- [ ] App Links checked **only after** approved assetlinks fingerprint configuration
- [ ] Android phone screenshots captured only from verified, real feature screens; redact personal data

**Release gate:** APK QA is not AAB signing, Play Console submission, or approval to merge/release. Keep `main`, `wynos.online` and all Play tracks unchanged.
