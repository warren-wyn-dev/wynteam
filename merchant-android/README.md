# WYNOS Merchant Android — native foundation (NOT production-ready)

This is a **real Android application**, built with Kotlin and Jetpack Compose. It is **not** a WebView, TWA or PWA wrapper.

Source of truth: `merchant.wynos.online` in `web/app/merchant`, `web/components/merchant` and `web/lib/food-merchant.ts`. Native Android uses the same Supabase Auth, RLS-protected tables and RPC functions, but a separate UX/UI.

**Important:** This branch implements an initial, reviewable native foundation. It does **not** yet provide 100% feature parity. Do not publish to Google Play or merge as a finished product until the parity and QA gates below are cleared.

## Setup

1. Open the `merchant-android` directory as a standalone project in Android Studio. Requires JDK 17 and Android SDK 36.
2. Set the following **build-time publishable configuration** in your private `~/.gradle/gradle.properties` (not the repository):

   ```properties
   WYNOS_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   WYNOS_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   ```

   Use the same Supabase project configured for the merchant web. **Never** use a service-role or secret key in an Android APK.
3. **Optional Android FCM:** after registering `online.wynos.merchant` as an Android app in the *existing approved WYNOS Firebase project*, set the following PUBLIC identifiers in private `~/.gradle/gradle.properties` (never service-account credentials):
   ```properties
   WYNOS_FIREBASE_APP_ID=1:000000000000:android:your-app-id
   WYNOS_FIREBASE_PROJECT_ID=your-project-id
   WYNOS_FIREBASE_SENDER_ID=000000000000
   WYNOS_FIREBASE_API_KEY=your-public-firebase-client-api-key
   ```
   On a device with Google Play services, sign in, open **การแจ้งเตือน** and explicitly opt in; Android 13+ requests notification permission. The app registers `push_tokens` as `platform=android, app=merchant` scoped to the current user. **This is not fully tested yet** and requires the backend push app-routing migration, Firebase credentials/configuration and authenticated device testing. Without these four values the Push toggle is disabled. Do not add `google-services.json` containing credentials to the repo.
4. Open and sync the Gradle project; Gradle plugin 8.13.2, Kotlin 2.2.21, Compose BOM 2025.10.00, Gradle 8.13.
5. The current repository includes `gradle-wrapper.properties` but **does not yet include the generated wrapper JAR/scripts**. Generate the wrapper with Gradle 8.13 on your development machine (or use Android Studio) before expecting `./gradlew` to work.
6. Build a debug app. Verify against a **test merchant account/test store first**, because order and menu actions call the actual backend.

## Current native feature coverage (all require real-device/backend QA)

- Native sign-in and password recovery email, encrypted session storage using Android Keystore, refresh-token renewal and active merchant identity/access checks.
- Store switching, home metrics, four order status tabs, human-reviewed private payment slips, delivery photo upload and completion RPC.
- Order history search/date/status filters, paging, receipt and address-label Android Print Framework.
- Menu CRUD, availability/sold-out, daily stock, image upload and preview, option groups/add-ons and full-row touch reorder.
- Category add/rename/reorder, touch drag and save/cancel.
- Detailed store profile, brand logo/cover, payment QR, bank details, tax/scheduled orders, 7-day schedule, temporary closures, special closed dates, readiness/controlled publishing, native GPS coordinate editing and store-scoped saved delivery places (external map viewer; interactive in-app map not yet implemented).
- Feedback and merchant replies, staff and permissions, store-created promotions, WYNOS campaign participation, advertising account and private slip top-up, in-app notification center and help. Optional opt-in native Android FCM token registration and privacy-safe notification handling are coded, **not live tested**.
- Sales report, finance date ranges, payout balances from Stripe status RPC, CSV export.
- Shared Supabase Auth / RLS / RPC contracts; no schema migrations and no changes to deployed web routes.

## Not yet at 100% feature parity

Still outstanding: real-device FCM delivery/OS permission QA and Firebase configuration, Realtime order subscription and quiet hours/deep link routing, full Google Play/signed release workflow, in-app interactive map/pin picker and delivery-zone visualization, Stripe Connect onboarding/account management and refund workflow, granular financial reporting/chart parity, premium UX polish, full end-to-end device QA and network/offline retries. Android coordinate inputs, saved places and token opt-in are now coded but do NOT count as complete without device/backend tests.

**All current code paths are development implementations until tested with authorized test merchant accounts and actual Android devices.** Compiling a debug APK is not proof that transactions, storage RLS or server-side privileges work correctly. See [FEATURE_PARITY.md](FEATURE_PARITY.md).

## Internal APK artifact

Successful Android CI attaches a short-lived `wynos-merchant-android-dev-debug` artifact to its workflow run. This is a **development build only** and is compiled without Supabase configuration in public CI; it will show a setup warning until built locally with the publishable project URL and key. It is not suitable for live merchant usage or Google Play.

## QA / release gates

- Run `node merchant-android/tools/verify-contracts.mjs` from repository root.
- Generate Gradle wrapper and run Android build, unit tests and connected tests in an Android SDK environment. **This has not been executed in this environment.**
- Verify login, store isolation, permissions, RLS, payment gating, background notification delivery, uploads and out-for-delivery proof on real devices.
- Compare every action and subpage with the current web release; no feature gets a "complete" mark without tests.
- Keep this PR **draft** until security review and explicit production approval.
