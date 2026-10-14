# WYNOS Food Android — Google Play readiness audit (14 Oct 2026)

**Current state: QA preview; NOT releasable.** This is a continuation of
`food-android/`, not a new Android application. Do not merge, deploy any
Production backend, process real payments or publish without explicit approval.

## Verified in connected GitHub

- App ID is provisionally `online.wynos.food`; confirm Play Console ownership.
- Native Kotlin + Jetpack Compose, no WebView/PWA/TWA checkout wrapper.
- `compileSdk = 36`, `targetSdk = 36`, `minSdk = 26`.
- Thai and English strings, Anuphan font, shared Food catalog/imagery.
- Guest Home QA screenshots have actual rendered restaurant content at
  360, 390 and 430 px in Thai and English. Prior emulator Pixel Launcher
  ANR screenshots were rejected and replaced by validated screenshots.
- CI builds `assembleDebug testDebugUnitTest lintDebug bundleRelease`.
  `bundleRelease` is **unsigned** and is not distributable through Play.
- Staging-gated Native account signup, saved-address editing and
  double-confirmed shared WYNOS Account deletion are not live production
  features. All order creation/payment actions remain disabled.
- Order activity is read-only; current foreground Orders polling/notice
  is NOT push notifications.

## Actual blockers and required verification

1. **Staging data parity.** Need a disposable Food staging project with the
   matching catalog, address, quote, order, merchant and Stripe-test
   contracts. Existing Stripe Sandbox is not complete enough for
   full end-to-end Food tests.
2. **Native checkout/payment.** Need approved mobile-authenticated payment
   endpoint/contract with server-side idempotency and server-verified
   amounts, PaymentSheet integration, webhook reconciliation, refund/failure
   scenarios and no embedded secret keys. Current browser Origin-based
   live checkout cannot be impersonated by Android.
3. **Auth and data rights.** Test signup and email confirmation, OAuth if
   specified, reset/deep links, auth session refresh, address RLS, account
   deletion (including session clearance after RPC), and external account
   deletion request URL. Account deletion in release is deliberately off.
4. **Privacy.** Publish a valid Privacy Policy URL, provide in-app legal
   entry, inventory use/storage/sharing/retention of email, personal data,
   recipient phone/address, precise or approximate location, order and
   transaction data, device/network diagnostics and push tokens (once used).
   Complete the Play Data Safety and Account Deletion forms accurately.
5. **Android release.** Confirm package name, versioning, app icon/adaptive
   icon, display name, locales, accessibility at larger font scales,
   UI testing across device classes, app signing/upload key, Play Integrity
   if required, release R8 rules, 64-bit/16KB native library compatibility
   if dependencies bring native binaries.
6. **Store listing.** Prepare actual-app screenshots (not fake purchase
   screens), feature graphic, app descriptions in Thai and English,
   category/contact details, content rating, and required Play testing.
7. **Merchant operations.** Confirm self-delivery acceptance and state
   transitions, cancellation/timeout/refunds, notifications and audit
   logs with staging Merchant UI and disposable orders.

## Google Play policy checked 2026-10-14

- Since **31 Aug 2026**, new standard mobile apps and updates require
  Android 16 **API level 36**:
  https://support.google.com/googleplay/android-developer/answer/11926878
- Apps that permit account creation must provide an in-app account
  deletion path AND external web deletion-request resource (submitted in
  Play Console):
  https://support.google.com/googleplay/android-developer/answer/13327111
- Android 13+ system per-app language settings can use a manually supplied
  `android:localeConfig` resource:
  https://developer.android.com/guide/topics/resources/app-languages

This file is a release gate checklist, not a declaration of compliance.
