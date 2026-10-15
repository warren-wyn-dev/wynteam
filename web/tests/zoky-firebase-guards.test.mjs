import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (name) => readFileSync(new URL(name, import.meta.url), "utf8");

test("Zoky Android Firebase config matches the existing application id", () => {
  const config = JSON.parse(read("../../food-android/app/google-services.json"));
  assert.equal(config.project_info.project_id, "zoky-e84e7");
  assert.equal(config.client[0].client_info.android_client_info.package_name, "online.wynos.food");
  assert.ok(config.client[0].client_info.mobilesdk_app_id);
  assert.equal("private_key" in config, false);
});

test("FCM device preview has consent and cannot run in release or before opt-in", () => {
  const gradle = read("../../food-android/app/build.gradle.kts");
  const rootGradle = read("../../food-android/build.gradle.kts");
  const manifest = read("../../food-android/app/src/main/AndroidManifest.xml");
  const receiver = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFirebaseMessagingService.kt");
  const screen = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFcmDevicePreviewCard.kt");
  assert.match(rootGradle, /com\.google\.gms\.google-services/);
  assert.match(gradle, /firebase-messaging/);
  assert.match(gradle, /buildConfigField\("boolean", "FCM_DEVICE_PREVIEW_ALLOWED", "false"\)/);
  assert.match(manifest, /POST_NOTIFICATIONS/);
  assert.match(manifest, /firebase_messaging_auto_init_enabled" android:value="false"/);
  assert.match(manifest, /firebase_analytics_collection_enabled" android:value="false"/);
  assert.match(manifest, /android:enabled="\$\{zokyFcmPreviewServiceEnabled\}"/);
  assert.match(gradle, /manifestPlaceholders\["zokyFcmPreviewServiceEnabled"\] = "true"/);
  assert.match(gradle, /manifestPlaceholders\["zokyFcmPreviewServiceEnabled"\] = "false"/);
  assert.match(receiver, /BuildConfig\.FCM_DEVICE_PREVIEW_ALLOWED \|\| !ZokyPushConsent\.enabled\(this\)/);
  assert.match(screen, /RequestPermission\(\)/);
  assert.match(screen, /FirebaseMessaging\.getInstance\(\)/);
  assert.match(receiver, /Deliberately do not log\/store\/upload/);
  assert.match(screen, /รับ Token ทดสอบ/);
  assert.match(screen, /result\.isSuccessful/);
  assert.match(screen, /ยังลบ Token ไม่สำเร็จ/);
});

test("No server keys or live push claims in device preview", () => {
  const receiver = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFirebaseMessagingService.kt");
  const screen = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFcmDevicePreviewCard.kt");
  assert.doesNotMatch(receiver + screen, /service_role|sb_secret_|FCM_SERVER_KEY|firebase_admin_sdk/i);
  assert.match(screen, /ยังไม่มีระบบ Push ของออเดอร์จริง/);
});

test("debug notification diagnostic stays local-only and permission gated", () => {
  const local = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyLocalNotificationQa.kt");
  const screen = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFcmDevicePreviewCard.kt");
  assert.match(local, /BuildConfig\.FCM_DEVICE_PREVIEW_ALLOWED/);
  assert.match(local, /ZokyPushConsent\.enabled\(context\)/);
  assert.match(local, /POST_NOTIFICATIONS/);
  assert.match(local, /areNotificationsEnabled\(\)/);
  assert.match(local, /IMPORTANCE_NONE/);
  assert.match(local, /notify\(77001, notification\)/);
  assert.match(screen, /ZokyLocalNotificationQa\.post\(context\)/);
  assert.match(screen, /ทดสอบแจ้งเตือนในเครื่อง/);
  assert.doesNotMatch(local, /firebase\.messaging|service_role|sb_secret_|FCM_SERVER_KEY|firebase_admin_sdk/i);
});

test("debug FCM receipt counter records only callback counts and never message payloads", () => {
  const receiver = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFirebaseMessagingService.kt");
  const diagnostic = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFcmPreviewReceipts.kt");
  const screen = read("../../food-android/app/src/main/java/online/wynos/food/push/ZokyFcmDevicePreviewCard.kt");

  assert.match(receiver, /ZokyFcmPreviewReceipts\.record\(this\)/);
  assert.match(receiver, /BuildConfig\.FCM_DEVICE_PREVIEW_ALLOWED \|\| !ZokyPushConsent\.enabled\(this\)/);
  assert.match(diagnostic, /BuildConfig\.FCM_DEVICE_PREVIEW_ALLOWED/);
  assert.match(diagnostic, /ZokyPushConsent\.enabled\(context\)/);
  assert.match(diagnostic, /putInt\(KEY_COUNT/);
  assert.doesNotMatch(diagnostic, /getToken|message\.data|message\.notification|service_role|sb_secret_|firebase_admin_sdk/i);
  assert.match(screen, /ZokyFcmPreviewReceipts\.count\(context\)/);
  assert.match(screen, /ZokyFcmPreviewReceipts\.clear\(context\)/);
  assert.match(screen, /ตรวจผลการรับ FCM/);
  assert.match(screen, /เริ่มนับ FCM ใหม่/);
});

test("FCM manifest resolves MESSAGING_EVENT to one app receiver only", () => {
  const manifest = read("../../food-android/app/src/main/AndroidManifest.xml");
  assert.match(manifest, /xmlns:tools="http:\/\/schemas\.android\.com\/tools"/);
  assert.match(manifest, /<service android:name="com\.google\.firebase\.messaging\.FirebaseMessagingService"\s+tools:node="remove"\s*\/>/);
  assert.match(manifest, /<service android:name="\.push\.ZokyFirebaseMessagingService"/);
  assert.match(manifest, /com\.google\.firebase\.MESSAGING_EVENT/);
  // DEBUG resolves to Zoky opt-in; release remains disabled without the SDK fallback.
  const gradle = read("../../food-android/app/build.gradle.kts");
  assert.match(gradle, /manifestPlaceholders\["zokyFcmPreviewServiceEnabled"\] = "true"/);
  assert.match(gradle, /manifestPlaceholders\["zokyFcmPreviewServiceEnabled"\] = "false"/);
});
