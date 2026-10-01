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
