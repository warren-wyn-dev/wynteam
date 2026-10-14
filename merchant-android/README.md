# WYNOS Merchant Android — native foundation (NOT production-ready)

This is a **real Android application**, built with Kotlin and Jetpack Compose. It is **not** a WebView, TWA or PWA wrapper.

Source of truth: \`merchant.wynos.online\` in \`web/app/merchant\`, \`web/components/merchant\` and \`web/lib/food-merchant.ts\`. Native Android uses the same Supabase Auth, RLS-protected tables and RPC functions, but a separate UX/UI.

**Important:** This branch implements an initial, reviewable native foundation. It does **not** yet provide 100% feature parity. Do not publish to Google Play or merge as a finished product until the parity and QA gates below are cleared.

## Setup

1. Open the \`merchant-android\` directory as a standalone project in Android Studio. Requires JDK 17 and Android SDK 36.
2. Set the following **build-time publishable configuration** in your private \`~/.gradle/gradle.properties\` (not the repository):

   \`\`\`properties
   WYNOS_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
   WYNOS_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   \`\`\`

   Use the same Supabase project configured for the merchant web. **Never** use a service-role or secret key in an Android APK.
3. Open and sync the Gradle project; Gradle plugin 8.13.2, Kotlin 2.2.21, Compose BOM 2026.09.00, Gradle 8.13.
4. The current repository includes \`gradle-wrapper.properties\` but **does not yet include the generated wrapper JAR/scripts**. Generate the wrapper with Gradle 8.13 on your development machine (or use Android Studio) before expecting \`./gradlew\` to work.
5. Build a debug app. Verify against a **test merchant account/test store first**, because order and menu actions call the actual backend.

## Implemented in this foundation

- Native sign-in, encrypted session storage using Android Keystore and refresh-token renewal.
- Active \`merchant_users\` identity check and \`food_has_merchant_access\` backend authorization.
- Store list/switcher from RLS-protected \`food_stores\`.
- Merchant home: server-calculated sales metrics, pending orders and menu count.
- Orders: correct four tab names/filters; 24-hour terminal orders; detail and order-item list; payment-gated accept action and prepare/dispatch transitions.
- Menu list, availability switch, basic add/edit with existing option JSON preserved.
- Sales reports from \`merchant_sales_report\`, finance month summary from \`merchant_finance_summary\`, read-only recent order history.
- Basic restaurant profile/phone/address/delivery-area/open-state editor.
- No schema migrations and no edits to deployed web routes.

## Not implemented yet

Delivery proof capture/upload/completion, payment-slip viewer/verification, order pagination and Realtime/Push; advanced menus/add-ons/reorder/media; full store settings/schedule/location/pickup/payment/publishing, receipt/address printing; finance periods/exports/refunds; advertising/top-ups, campaigns/promotions, feedback, help, notification preferences, and remaining controls. See [FEATURE_PARITY.md](FEATURE_PARITY.md).

## QA / release gates

- Run \`node merchant-android/tools/verify-contracts.mjs\` from repository root.
- Generate Gradle wrapper and run Android build, unit tests and connected tests in an Android SDK environment. **This has not been executed in this environment.**
- Verify login, store isolation, permissions, RLS, payment gating, background notification delivery, uploads and out-for-delivery proof on real devices.
- Compare every action and subpage with the current web release; no feature gets a "complete" mark without tests.
- Keep this PR **draft** until security review and explicit production approval.
