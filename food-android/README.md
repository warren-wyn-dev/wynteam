# WYNOS Food Android (Native) — Step 1 foundation

**Status: developer demo only. Not production, not merged, not published.**

Separate Kotlin + Jetpack Compose Android application at `food-android/`.
This is **not** a WebView, PWA, or TWA, and deliberately does **not** talk to
production Supabase or create orders/charge money.

## What Step 1 includes

- Independent Gradle/Android Studio project and package `online.wynos.food` (proposed).
- Native Material 3 UI: home, sample restaurants, menu, orders/account placeholders.
- Thai and English string resources, system light/dark theme, Android back arrow.
- Synthetic offline catalog; visibly labeled demo, real checkout disabled.
- No `INTERNET` permission and no credentials.
- Basic JVM unit tests, PR-only build workflow.
- Uses Android 16 API 36 target and JDK 17.

## Open

1. Install **Android Studio**, JDK 17 and Android SDK Platform 36.
2. Open **the `food-android` folder** as a project, not the repository root.
3. Allow Gradle sync (downloads Gradle 8.13 via the supplied wrapper).
4. Run the `app` configuration on an emulator/device.

From the repository root:

```sh
cd food-android
./gradlew assembleDebug testDebugUnitTest lintDebug
```

The unsigned debug APK is for local developer testing only.
No signed release AAB or Play Console upload is included.

## Next step (not implemented)

Read `API_INTEGRATION.md` and verify Supabase authentication, PostgREST/RPC
contracts and RLS before fetching real store/menu data. Reuse the same
WYNOS Food backend as `food.wynos.online`; do not create a second
database or put privileged keys in an Android build.

## Safety and scope

- Existing `android/` = WYNOS Social Native; **do not change it**.
- Existing `web/`, `admin/`, `supabase/` = unchanged.
- Not even a test order is sent. Checkout has no network/side effects.
- Never merge/deploy automatically. Production needs separate QA and Founder approval.
