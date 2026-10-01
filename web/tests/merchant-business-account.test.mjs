import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const auth = fs.readFileSync(new URL("../components/merchant/merchant-auth.tsx", import.meta.url), "utf8");
const app = fs.readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");

test("Merchant reuses the normal WYNOS auth session", () => {
  assert.match(auth, /getSupabaseBrowserClient/);
  assert.match(auth, /signInWithEmail/);
  assert.match(app, /DeveloperRouteGate/);
  assert.match(app, /signedOutPath="\/merchant\/login"/);
  assert.doesNotMatch(app, /MerchantRouteGate/);
});

test("Merchant keeps store tenancy separate from the shared WYNOS identity", () => {
  assert.match(auth, /ใช้บัญชี WYNOS เดิมได้/);
  assert.match(auth, /ร้านมี Merchant Account ของตัวเอง/);
  assert.match(auth, /รองรับ Owner และ Staff หลายคน/);
  assert.doesNotMatch(auth, /signUpMerchantWithEmail/);
  assert.doesNotMatch(auth, /บัญชี WYNOS Merchant แยกจากบัญชี WYNOS Social/);
});


const core = fs.readFileSync(new URL("../components/merchant/merchant-core-panels.tsx", import.meta.url), "utf8");
const coreData = fs.readFileSync(new URL("../lib/merchant-core.ts", import.meta.url), "utf8");
const migration = fs.readFileSync(new URL("../../supabase/migrations_wynos_merchant_core_completion_v1.sql", import.meta.url), "utf8");

test("Merchant core completion adds staff roles, refunds, readiness, notifications and activity", () => {
  assert.match(core, /MerchantStoreTools/);
  assert.match(core, /RefundControls/);
  assert.match(core, /Activity Log/);
  assert.match(core, /การแจ้งเตือน Merchant/);
  assert.match(coreData, /merchant_staff_members/);
  assert.match(coreData, /merchant_set_refund_status/);
  assert.match(coreData, /merchant_store_readiness/);
  assert.match(migration, /merchant_activity_log/);
  assert.match(migration, /refund_status/);
  assert.match(migration, /trg_food_store_publish_guard/);
});

test("Merchant orders expose search plus payment and date filters", () => {
  assert.match(app, /wm-order-search-tools/);
  assert.match(app, /paymentFilter/);
  assert.match(app, /dateFilter/);
  assert.match(app, /recipient_phone/);
});


const notificationTest = fs.readFileSync(new URL("../components/merchant/merchant-notification-test.tsx", import.meta.url), "utf8");
const notificationTestMigration = fs.readFileSync(new URL("../../supabase/migrations_wynos_merchant_notification_test_center_v1.sql", import.meta.url), "utf8");
const worker = fs.readFileSync(new URL("../public/sw.js", import.meta.url), "utf8");
const pushLib = fs.readFileSync(new URL("../../supabase/functions/send-push-notification/_lib.ts", import.meta.url), "utf8");

test("Merchant notification test center exercises In-App, Realtime, Web Push and Deep Link", () => {
  assert.match(notificationTest, /sendMerchantTestNotification/);
  assert.match(coreData, /merchant_send_test_notification/);
  assert.match(notificationTest, /postgres_changes/);
  assert.match(notificationTest, /subscribeToPushNotifications/);
  assert.match(coreData, /notification_push_deliveries/);
  assert.match(notificationTest, /Deep Link/);
  assert.match(notificationTestMigration, /supabase_realtime/);
  assert.match(notificationTestMigration, /merchant_send_test_notification/);
  assert.match(notificationTestMigration, /notification_push_deliveries/);
  assert.match(notificationTestMigration, /notification_test_rate_limited/);
  assert.match(worker, /merchant_test/);
  assert.match(worker, /\/merchant\?notification-test=1/);
  assert.match(pushLib, /merchant_test/);
});

test("Merchant notification test is self-only and never creates a Food order", () => {
  assert.match(notificationTestMigration, /v_user uuid := auth\.uid\(\)/);
  assert.match(notificationTestMigration, /mm\.user_id = v_user/);
  assert.match(notificationTestMigration, /recipient_user_id[\s\S]*v_user/);
  assert.match(notificationTestMigration, /recipient_id[\s\S]*v_user/);
  assert.doesNotMatch(notificationTestMigration, /insert into public\.food_orders/);
});
