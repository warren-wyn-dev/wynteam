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


const campaignUi = fs.readFileSync(new URL("../components/merchant/merchant-campaign-center.tsx", import.meta.url), "utf8");
const campaignData = fs.readFileSync(new URL("../lib/merchant-campaigns.ts", import.meta.url), "utf8");
const foodCustomer = fs.readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8");
const foodCustomerApp = fs.readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
const campaignMigration = fs.readFileSync(new URL("../../supabase/migrations_wynos_merchant_campaign_center_v1.sql", import.meta.url), "utf8");

test("Merchant Campaign Center manages scheduled percentage, fixed and free-delivery promotions", () => {
  assert.match(app, /MerchantCampaignCenter/);
  assert.match(campaignUi, /Campaign Center/);
  assert.match(campaignUi, /percentage/);
  assert.match(campaignUi, /fixed/);
  assert.match(campaignUi, /free_delivery/);
  assert.match(campaignUi, /minSubtotal/);
  assert.match(campaignUi, /maxDiscount/);
  assert.match(campaignUi, /usageLimit/);
  assert.match(campaignUi, /itemIds/);
  assert.match(campaignUi, /ยอดขายจากโปร/);
  assert.match(campaignData, /merchant_food_campaigns/);
  assert.match(campaignData, /merchant_upsert_food_campaign/);
  assert.match(campaignData, /merchant_set_food_campaign_active/);
  assert.match(campaignData, /merchant_delete_food_campaign/);
});

test("Campaign pricing is server-authoritative, picks one best campaign and releases cancelled usage", () => {
  assert.match(campaignMigration, /internal\.food_campaign_candidates/);
  assert.match(campaignMigration, /order by saving desc/);
  assert.match(campaignMigration, /food_quote_order/);
  assert.match(campaignMigration, /create or replace function public\.food_create_order/);
  assert.match(campaignMigration, /campaign_discount/);
  assert.match(campaignMigration, /delivery_discount/);
  assert.match(campaignMigration, /for update/);
  assert.match(campaignMigration, /usage_count=usage_count\+1/);
  assert.match(campaignMigration, /food_campaign_release_on_cancel/);
  assert.match(campaignMigration, /usage_count=greatest\(usage_count-1,0\)/);
  assert.match(campaignMigration, /food_order_campaigns/);
  assert.doesNotMatch(campaignMigration, /food_create_manual_order/);

  assert.match(foodCustomer, /food_quote_order/);
  assert.match(foodCustomerApp, /WYNOS เลือกโปรที่ประหยัดที่สุดให้อัตโนมัติ/);
  assert.match(foodCustomerApp, /ส่วนลดจะยืนยันอีกครั้งโดยระบบก่อนสร้างออเดอร์/);
});

test("Campaign tables are not directly exposed to browser roles", () => {
  for (const table of ["food_campaigns", "food_campaign_items", "food_order_campaigns"]) {
    assert.match(campaignMigration, new RegExp("alter table public\\." + table + " enable row level security"));
    assert.match(campaignMigration, new RegExp("revoke all on table public\\." + table + " from public, anon, authenticated"));
  }
  assert.match(campaignMigration, /merchant_has_store_role\(p_store_id,array\['owner','admin','manager'\]\)/);
});
