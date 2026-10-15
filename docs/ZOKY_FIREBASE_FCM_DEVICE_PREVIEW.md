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

## Firebase Console test without guessing from notification sounds

The DEBUG preview now has an on-device, opt-in **FCM callback counter**.
It stores only a local integer; it never stores payloads, account data or FCM tokens.
This is independent of the Android local-notification test.

1. Leave Zoky's Firebase Device Preview enabled. Do **not** disable it (that attempts to delete the token).
2. Tap **เริ่มนับ FCM ใหม่** and verify the counter displays zero.
3. Leave Zoky open in the foreground at **ข้อความ → การแจ้งเตือน**.
4. From Firebase Console on another device, target this install's latest FCM registration token with **Send test message → Test**. Never Publish.
5. Return to Zoky and tap **ตรวจผลการรับ FCM**:
   - Count becomes 1 or more: `onMessageReceived` was called, confirming device-level Firebase delivery in the test.
     If no system notification appears, inspect the Android notification channel or delivery display.
   - Count remains 0: no foreground callback was recorded. Verify the target token/project,
     whether Zoky actually remained foreground, Google Play services and device network.
6. Note: For a **background notification message**, Firebase can display it through Android
   directly without calling `onMessageReceived`. A zero callback count **cannot** rule out
   that type of background delivery.

Never share FCM tokens, test messages with customer data, or Firebase credentials in tickets,
logs, public chats or screenshots. This diagnostic is DEBUG-only and does not transmit results.


## QA notification tap destination (DEBUG only)

Expected behavior: a tapped Zoky DEBUG FCM notification opens **ข้อความ → การแจ้งเตือน**, not Home.
The DEBUG app handles both:

- Foreground notifications posted by `ZokyFirebaseMessagingService` with the Boolean
  `zoky_open_messages=true` extra in its local PendingIntent.
- Background notification messages automatically posted by Firebase on Android. The
  launcher Activity recognizes Firebase `google.message_id` only when DEBUG device
  preview is allowed **and opted in**. To make the destination explicit during
  Firebase Console QA, include this entry in **Additional options → Custom data**:
  **Key:** `zoky_open_messages`, **Value:** `true`. Firebase delivers custom data
  as String extras to the launcher when a background notification is tapped.

Verification scenarios (manual Redfinger):

1. Regular Home launcher tap still opens Home.
2. Zoky in foreground → Firebase Console **Send test message**, tap Android notification
   → Messages, Notifications segment.
3. Zoky backgrounded → Firebase Console test with explicit Custom data above,
   tap Android notification → Messages, Notifications segment.
4. From a prior Chats selection, a tapped QA notification returns to Notifications.
5. If an Android task/process was killed, inspect behavior separately; Android/Firebase
   may not always preserve tap extras across task reconstruction.

Never Publish a Firebase Console campaign. Use only the user's device token and
**Send test message**. Do not share registration tokens or insert live order payloads.
Real production order deep-link routing remains out of scope and is disabled.


## Background Firebase Console notification channel (DEBUG-only fix)

Firebase Console notification payloads are posted to Android's system tray
by the Firebase SDK when the app is in the **background**. They typically do
not invoke the app's `onMessageReceived` callback or increment the on-device
foreground callback counter.

The debug build now declares
`com.google.firebase.messaging.default_notification_channel_id=zoky_device_preview`
in `src/debug/AndroidManifest.xml`. When the tester explicitly opts in, the
app creates this exact channel **before** it can receive a background test.
The app also shows the local Android notification permission/channel state
without uploading identifiers. The release manifest has no channel override,
the receiver remains disabled, and Firebase token auto-init defaults off.

After a verified debug build, check the local channel status in
**ข้อความ → การแจ้งเตือน** before a background test. For a single-device
manual verification, keep Zoky in the background, use Firebase Console
**Send test message** to this install's latest FCM token, then tap the
system-tray notification to verify Messages → Notifications routing.

This change makes SDK channel routing explicit; it does **not** prove
delivery on a particular Redfinger device or establish production push readiness.
A background notification can still be absent due to FCM targeting,
device policies, runtime notification permission, or other delivery conditions.
Do not Publish a campaign for device QA; never screenshot or share FCM tokens.


## Follow-up hardening — QA only

After receipt was confirmed on Redfinger but a background Firebase Console test did
not appear in the Android shade, this draft was hardened in several ways:

- Ensure the opted-in channel after app/process recreation, not just when the token
  is first fetched. Keep Firebase's default channel override **DEBUG-only**.
- Record the last notification posting outcome from `onMessageReceived` as a
  device-local enum (permission denied, app disabled, channel disabled, request
  posted, or posting failed). No token, message body, sender ID or order data is
  recorded. **Posted is not displayed/delivered acknowledgment**.
- Show that outcome separately from the FCM callback count and the Android
  channel state. Background Console notification messages normally bypass this
  callback; a zero foreground count or empty foreground post-status is not
  proof that background delivery failed.
- Provide a direct button to the Android notification-channel settings,
  falling back to app notification settings when a device does not support
  the channel settings screen.
- Guard **all** test-notification deep-link routing on both DEBUG and
  the user's current opt-in, including foreground PendingIntent extras.
  Ordinary launcher actions still open Home.
- Label the console workflow as **Send test message → Test only**.
  Never click Review/Publish for a single-device test.

This is a code/CI mitigation and better diagnostics, **not confirmation of a
new successful Redfinger background delivery**. An Android emulator cannot
validate Firebase Console-to-Redfinger delivery, token freshness, Play services
connectivity or a user-modified OS alert presentation.

Unrelated features, live order Push, real notification payloads, release
routing, database schema and production deployments are outside this QA fix.

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
