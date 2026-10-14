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
3. Open and sync the Gradle project; Gradle plugin 8.13.2, Kotlin 2.2.21, Compose BOM 2025.10.00, Gradle 8.13.
4. The current repository includes `gradle-wrapper.properties` but **does not yet include the generated wrapper JAR/scripts**. Generate the wrapper with Gradle 8.13 on your development machine (or use Android Studio) before expecting `./gradlew` to work.
5. Build a debug app. Verify against a **test merchant account/test store first**, because order and menu actions call the actual backend.

## Current native feature coverage (all require real-device/backend QA)

- Native sign-in, encrypted session storage using Android Keystore, refresh-token renewal and active merchant identity/access checks.
- Store switching, home metrics, four order status tabs, human-reviewed private payment slips, delivery photo upload and completion RPC.
- Order history search/date/status filters, paging, receipt and address-label Android Print Framework.
- Menu CRUD, availability/sold-out, daily stock, image upload and preview, option groups/add-ons and full-row touch reorder.
- Category add/rename/reorder, touch drag and save/cancel.
- Detailed store profile, brand logo/cover, payment QR, bank details, tax/scheduled orders, 7-day schedule, temporary closures, special closed dates, readiness/controlled publishing.
- Feedback and merchant replies, staff and permissions, store-created promotions, WYNOS campaign participation, advertising account and private slip top-up, in-app notification center and help.
- Sales report, finance date ranges, payout balances from Stripe status RPC, CSV export.
- Shared Supabase Auth / RLS / RPC contracts; no schema migrations and no changes to deployed web routes.

## Not yet at 100% feature parity

Still outstanding: true Android background Push/FCM registration and delivery, Realtime event subscription and sound/quiet hours, full Google Play/signed release workflow, native maps/location picker and saved store places, Stripe Connect onboarding/account management and refund workflow, granular financial reporting and chart parity, full order paging, premium UX polish, device printing QA and responsive network/offline retries.

**All current code paths are development implementations until tested with authorized test merchant accounts and actual Android devices.** Compiling a debug APK is not proof that transactions, storage RLS or server-side privileges work correctly. See [FEATURE_PARITY.md](FEATURE_PARITY.md).

## Internal APK artifact

Successful Android CI attaches a short-lived `wynos-merchant-android-dev-debug` artifact to its workflow run. This is a **development build only** and is compiled without Supabase configuration in public CI; it will show a setup warning until built locally with the publishable project URL and key. It is not suitable for live merchant usage or Google Play.

## QA / release gates

- Run `node merchant-android/tools/verify-contracts.mjs` from repository root.
- Generate Gradle wrapper and run Android build, unit tests and connected tests in an Android SDK environment. **This has not been executed in this environment.**
- Verify login, store isolation, permissions, RLS, payment gating, background notification delivery, uploads and out-for-delivery proof on real devices.
- Compare every action and subpage with the current web release; no feature gets a "complete" mark without tests.
- Keep this PR **draft** until security review and explicit production approval.
