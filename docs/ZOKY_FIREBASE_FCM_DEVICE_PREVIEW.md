# Zoky Android Firebase Cloud Messaging — device preview

Status: **Firebase Android SDK wired for manual device-only QA; NOT production push**.
The uploaded `google-services.json` matches package `online.wynos.food`, Firebase project `zoky-e84e7`. This Firebase Android client configuration contains publishable project identifiers, not a service-account key. Do not place Admin SDK/private keys into the client app or repository.

## What this draft does
- Integrates official Firebase Google Services plugin and Firebase Messaging SDK in **native Kotlin + Jetpack Compose**.
- Registers a `FirebaseMessagingService` and displays a generic Zoky test notification when the app is foregrounded or receives a data message.
- Enables an explicit preview opt-in control only in **debug** under **ข้อความ → การแจ้งเตือน**.
- Android 13+ notification permission requested only after a user tap.
- Firebase auto-initialization and Analytics collection default to off. On opt-in, the SDK can acquire a device token. Token is **not** sent to Supabase, logged, uploaded, or included in analytics. Only a deliberate debug clipboard action reveals it for manual test.
- Test notifications do not show user data, order/payment status, marketing promises or unverified deep links.
- Turning preview off immediately stops app-side displaying, disables FCM auto-init and requests token deletion.
- BuildConfig prevents test UI and service delivery from running in **release**. The actual server-side send flow is not enabled.

## Device test (Android device with Google Play services)
1. Install a fresh **debug** APK on Android/Redfinger with Google Play services and Internet.
2. Open **ข้อความ → การแจ้งเตือน → เปิดรับข้อความทดสอบ** and accept Android notification permission.
3. Wait until status says Firebase connected, tap **คัดลอก Token ทดสอบ**. Keep this token private; do not post it to a public chat or repository.
4. In Firebase Console → Messaging, compose a test notification and use the **Send test message** flow with that Android token (console UI may change). Start app in foreground to verify the custom native Zoky test notification; background notification handling may be performed automatically by Firebase SDK and may display the Console-supplied content instead.
5. Use **ปิดการทดสอบ** after QA. Repeat with permission denied, offline, Google Play services unavailable, app foreground/background, token invalidation and reinstall.

## Redfinger troubleshooting — debug-only local notification

When the phone has Google Play services, Android notifications are allowed, and FCM
returns a token but Firebase Console test messages never appear:

1. Install a debug APK built from the latest PR #1221 commit.
2. In **ข้อความ → การแจ้งเตือน**, enable the device preview.
3. Tap **ทดสอบแจ้งเตือนในเครื่อง**, then pull down the **Android notification shade**.
   This creates a generic notification directly on-device with no Firebase or backend traffic.
4. **Local notification appears:** Android app posting/permission/channel likely works.
   Next verify the same project's fresh FCM token, console test-send target, Play
   services connectivity, Wi-Fi restrictions, and foreground/background delivery.
5. **Local notification does not appear:** check system permission, the notification
   channel, Android app settings and device notification suppression before blaming FCM.
6. This button does **not** prove that FCM delivery works. It is excluded from
   Release by the existing `FCM_DEVICE_PREVIEW_ALLOWED` build flag and opt-in checks.

Never paste FCM device tokens, service account credentials or customer information into
public chats, issue comments, CI logs or APK build arguments.

## Release / security gates not yet completed
- Design the recipient-scoped device-token table and token registration/deletion authenticated by WYNOS Account; use server RLS and authorization. No customer token stored in the draft app backend.
- Implement the server-only Firebase Admin/FCM HTTP v1 dispatcher with Google IAM credentials stored **only on a trusted server**, never in the Android APK.
- Route verified order/payment/security/marketing events, quiet hours, opt-ins, anti-spam, deep-link validation, error callbacks, delivery metrics and logout/account isolation.
- Staging has to be a separate Food environment with synthetic data and vetted credential scope. No Production migration or live customer push without separate approval.
- For Google Play signing, record the correct SHA certificates, ensure restricted API keys when needed, and verify Play integrity/release signing separately.

## Firebase Android project
- Project ID: `zoky-e84e7`
- Android package: `online.wynos.food`
- JSON: `food-android/app/google-services.json`
- Never copy service-account JSON or FCM server private keys into this location.
