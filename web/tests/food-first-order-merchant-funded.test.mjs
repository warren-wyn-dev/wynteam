import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const source = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const migration = source("../../supabase/migrations/20261009120000_food_first_order_merchant_funded.sql");
const food = source("../components/food/wynos-food-developer-app.tsx");
const merchant = source("../components/merchant/merchant-platform-campaigns.tsx");
const adminPage = source("../../admin/app/(admin)/food/campaigns/page.tsx");
const adminAction = source("../../admin/lib/admin-food-actions.ts");
const adminControl = source("../../admin/components/admin/platform-campaign-actions.tsx");

test("first-order preset is 120/20 merchant funded and never pre-enabled", () => {
  assert.match(migration, /first_order_only boolean not null default false/);
  assert.match(migration, /campaign_type = 'fixed' and discount_value = 20/);
  assert.match(migration, /min_subtotal = 120 and max_discount is null/);
  assert.match(migration, /platform_share_percent = 0/);
  assert.match(migration, /'fixed',20,120,null,0,true,false,true,auth\.uid\(\)/);
  assert.match(migration, /first_order_only\s+for update/);
  assert.match(migration, /Only admins can manage WYNOS first-order promotions/);
  assert.match(migration, /join_open = coalesce\(p_active,false\)/);
});

test("first-order eligibility is global across Food, not per merchant", () => {
  assert.match(migration, /pc\.first_order_only is distinct from true/);
  assert.match(migration, /prior\.buyer_id = auth\.uid\(\)/);
  assert.match(migration, /prior\.buyer_id = v_buyer/);
  assert.match(migration, /prior\.status <> 'cancelled'/);
  assert.match(migration, /prior\.payment_status in \('paid','submitted','refunded'\)/);
  assert.doesNotMatch(migration, /prior\.store_id\s*=/);
  assert.match(migration, /food_first_order_validate_redemption/);
  assert.match(migration, /pg_advisory_xact_lock\(206120, hashtext\(new\.buyer_id::text\)\)/);
  assert.match(migration, /before insert on public\.food_orders/);
  assert.match(migration, /after insert on public\.food_order_campaigns/);
});

test("existing coupon campaign conditions are preserved", () => {
  assert.match(migration, /pc\.coupon_required is distinct from true/);
  assert.match(migration, /public\.food_coupon_redemptions/);
  assert.match(migration, /order by saving desc,id/);
  assert.match(migration, /public\.merchant_join_platform_campaign/);
  assert.match(migration, /'first_order_only', pc\.first_order_only/);
});

test("customer eligibility is exposed as booleans without revealing history", () => {
  assert.match(migration, /function public\.food_first_order_offer\(p_store_id uuid\)/);
  assert.match(migration, /'eligible', v_joined and v_new_customer/);
  assert.match(migration, /revoke all on function public\.food_first_order_offer\(uuid\) from public, anon/);
  assert.match(migration, /grant execute on function public\.food_first_order_offer\(uuid\) to authenticated/);
  assert.match(food, /client\.rpc\("food_first_order_offer", \{ p_store_id: store\.id \}\)/);
  assert.match(food, /สิทธิ์ลูกค้าใหม่/);
  assert.match(food, /ระบบคำนวณส่วนลดที่เหมาะสมให้อัตโนมัติ/);
});

test("Merchant confirms opt-in and sees funding responsibility", () => {
  assert.match(merchant, /campaign\.first_order_only/);
  assert.match(merchant, /ร้านรับผิดชอบส่วนลด ฿20 เต็มจำนวน/);
  assert.match(merchant, /ร้านรับผิดชอบ/);
  assert.match(merchant, /joinPlatformCampaign/);
});

test("Admin exposes role-protected activation and usage overview", () => {
  assert.match(adminPage, /FirstOrderFoodCampaignButton/);
  assert.match(adminPage, /ส่วนลดที่ใช้แล้ว/);
  assert.match(adminControl, /setFirstOrderFoodCampaignActive/);
  assert.match(adminAction, /admin_food_first_order_set_active/);
  assert.match(migration, /internal\.log_audit_event/);
});
