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
