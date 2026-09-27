# Coding Task — WYN-190

Status: active — build verified; waiting on Founder (Google Play account, upload key, Vercel env) and QA on a physical Android device
Owner: AI Coding
Feature: WYNOS Android app for Google Play (Web Beta1 as a Trusted Web Activity)
Branch: claude/wynos-android-version-m3nf1e

## Founder request (2026-09-27)

"Wynos.Online Web Beta1 ทำเวอชั่นแอนดรอยให้หน่อย" — asked for a real Android
app ("อยากให้เป็นแอปจริงๆ เวอชั่น แอนดรอย") and chose to prepare it for Google
Play ("เตรียมขึ้น Google Play").

## Approach

Trusted Web Activity (`android/`) around `https://wynos.online`, built with
Google's `androidbrowserhelper`. Chosen over a WebView shell (Capacitor) or the
old Flutter client (`app/`) because:

- Google refuses OAuth sign-in in WebViews; a TWA runs in Chrome, so the
  existing Google sign-in keeps working unchanged.
- Zero duplicated product code: the app is Web Beta1 itself; every web deploy
  updates the app.
- Web Push is delegated to the app's own notifications (Android 13+ permission).
- `app/` (Flutter) only covers early auth/onboarding and is far behind Beta1.

## Changes

- `android/` — Gradle project (AGP 8.13, compile/target SDK 36, minSdk 23),
  package `online.wynos.app`, launcher/adaptive/themed icons and splash from
  the existing web brand assets, `wynos.online` App Links, notification
  delegation, Custom Tab fallback (never WebView), no backup of app data,
  release signing only from git-ignored `keystore.properties` or CI secrets.
- `web/app/.well-known/assetlinks.json/route.ts` + `web/lib/android-asset-links.ts`
  — Digital Asset Links from `ANDROID_TWA_SHA256_FINGERPRINTS` (validated,
  `[]` when unset, so production is unchanged until configured).
- `web/tests/android-asset-links.test.mjs` (in `npm run check`).
- `.github/workflows/android-ci.yml` — lint + debug APK on PRs; manual run
  adds the release AAB (signed when secrets exist). No Play upload from CI.

## Verification

- `./gradlew lintRelease assembleDebug bundleRelease` — pass (debug APK,
  unsigned release AAB). `aapt2 dump badging`: `online.wynos.app`,
  versionName `1.0.0-beta1`, targetSdk 36, `POST_NOTIFICATIONS`.
- `web`: lint, typecheck, `npm run test:android-asset-links` (4/4), production
  build; `next start` smoke: `/.well-known/assetlinks.json` → 200
  `application/json`, not redirected for LINE user agents, malformed
  fingerprints dropped.
- Not yet done: install on a physical Android device (needs QA), Play upload.

## Founder decisions / actions needed

1. Confirm package name `online.wynos.app` (permanent after first Play upload).
2. Google Play Developer account; create the upload key (see `android/README.md`).
3. Set `ANDROID_TWA_SHA256_FINGERPRINTS` on Vercel production + redeploy web
   (this is a production change — Founder approval).
4. Store listing assets, privacy policy URL, Data safety form.
