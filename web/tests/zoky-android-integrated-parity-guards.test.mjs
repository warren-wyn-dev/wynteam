import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const read = (path) =>
  readFileSync(new URL(`../../food-android/${path}`, import.meta.url), "utf8");

test("all buyer action and notification entry points survive the stacked integration", () => {
  const app = read("app/src/main/java/online/wynos/food/ui/FoodApp.kt");
  const messages = read("app/src/main/java/online/wynos/food/ui/ZokyMessageCenter.kt");
  const activity = read("app/src/main/java/online/wynos/food/MainActivity.kt");

  assert.match(app, /fun FoodApp\(notificationNavigationSequence: Int = 0/);
  assert.match(app, /notificationNavigationSequence = notificationNavigationSequence/);
  assert.match(app, /onOpenOrder = vm::openOrderDetails/);
  assert.match(app, /onCancelStaging = vm::cancelStagingOrder/);
  assert.match(app, /onBrowse = \{ tab = 0; foodServiceOpen = true \}/);
  assert.match(messages, /ZokyFcmDevicePreviewCard\(\)/);
  assert.match(messages, /onOpenOrder\(order\.id\)/);
  assert.match(messages, /promo_inbox_copy_code/);
  assert.match(messages, /LaunchedEffect\(notificationNavigationSequence\)/);
  assert.match(activity, /handleNotificationNavigation\(intent\)/);
});

test("release builds never activate FCM device tests or order cancellation", () => {
  const gradle = read("app/build.gradle.kts");
  const main = read("app/src/main/AndroidManifest.xml");
  const debug = read("app/src/debug/AndroidManifest.xml");
  assert.match(gradle, /FCM_DEVICE_PREVIEW_ALLOWED", "false"/);
  assert.match(gradle, /STAGING_ORDER_CANCEL_ALLOWED", "false"/);
  assert.match(gradle, /manifestPlaceholders\["zokyFcmPreviewServiceEnabled"\] = "false"/);
  assert.match(gradle, /WYNOS_FOOD_ORDER_CANCEL_STAGING/);
  assert.match(debug, /default_notification_channel_id/);
  assert.doesNotMatch(main, /default_notification_channel_id/);
  assert.match(main, /android:enabled="\$\{zokyFcmPreviewServiceEnabled\}"/);
});

test("integrated debug FCM notifications remain private and opt-in only", () => {
  const receiver = read("app/src/main/java/online/wynos/food/push/ZokyFirebaseMessagingService.kt");
  const routing = read("app/src/main/java/online/wynos/food/ZokyNotificationTapRouting.kt");
  assert.match(receiver, /FCM_DEVICE_PREVIEW_ALLOWED \|\| !ZokyPushConsent\.enabled\(this\)/);
  assert.match(routing, /return debugPreviewAllowed && optedIn &&/);
  assert.doesNotMatch(receiver + routing, /service_role|sb_secret_|FCM_SERVER_KEY/i);
});
