import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const read = (path: string) => readFileSync(join(process.cwd(), path), "utf8");

test("Merchant is a separate installable app surface with the red WYNOS identity", () => {
  const page = read("app/merchant/page.tsx");
  const layout = read("app/merchant/layout.tsx");
  const manifest = read("app/merchant/manifest.ts");
  const css = read("app/merchant/merchant.css");

  expect(page).toContain("<WynosMerchantApp />");
  expect(layout).toContain('manifest: "/merchant/manifest.webmanifest"');
  expect(layout).toContain('title: "WYNOS Merchant"');
  expect(manifest).toContain('start_url: "/merchant"');
  expect(manifest).toContain('scope: "/merchant"');
  expect(manifest).toContain('theme_color: "#e32636"');
  expect(css).toContain("--wm-red: #e32636");
  expect(css).toContain(".wm-nav");
  expect(css).toContain(".wm-delivery-methods");
});

test("Merchant data layer uses dedicated Food RPCs, secure evidence storage and realtime", () => {
  const data = read("lib/food-merchant.ts");
  expect(data).toContain('client.rpc("food_has_merchant_access"');
  expect(data).toContain('client.rpc("food_set_payment_status"');
  expect(data).toContain('client.rpc("food_transition_order"');
  expect(data).toContain('client.rpc("food_complete_delivery"');
  expect(data).toContain('const FOOD_PRIVATE = "food-private"');
  expect(data).toContain('table: "food_orders"');
  expect(data).toContain("withoutLocation(file, contentType)");
});

test("Merchant receives orders from WYNOS Food only while keeping delivery workflow", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const guardSql = read("../supabase/migrations_wynos_food_orders_only_v1.sql");

  expect(app).toContain("ออเดอร์จาก WYNOS Food");
  expect(app).not.toContain("createManualFoodOrder");
  expect(app).not.toContain("ManualOrderSheet");
  expect(app).not.toContain("> สร้างออเดอร์</button>");
  expect(data).not.toContain('client.rpc("food_create_manual_order"');

  expect(guardSql).toContain("new orders must be created through WYNOS Food");
  expect(guardSql).toContain("revoke execute on function public.food_create_manual_order");
  expect(guardSql).toContain("revoke insert on table public.food_orders from anon, authenticated");
  expect(guardSql).toContain("new.source <> 'app'");
  expect(guardSql).toContain("new.buyer_id <> new.created_by");

  expect(app).toContain('deliveryMethod === "dropoff"');
  expect(app).toContain("แนบรูปยืนยันการจัดส่งจากคนส่ง (จำเป็น)");
  expect(app).toContain("disabled={busy || !deliveryFile");
  expect(app).toContain("วางสินค้าไว้ที่ไหน?");
  expect(app).toContain("ยืนยันส่งสำเร็จ");
  expect(app).toContain("ยืนยันเงินเข้า");
  expect(app).toContain("เริ่มจัดส่ง");
});

test("Food Merchant migration isolates the restaurant domain and has no commission ledger", () => {
  const sql = read("../supabase/migrations_wynos_food_merchant_v1.sql");
  for (const table of [
    "food_stores",
    "food_staff",
    "food_menu_items",
    "food_orders",
    "food_order_items",
    "food_order_events",
    "food_delivery_proofs",
  ]) expect(sql).toContain(`public.${table}`);

  expect(sql).toContain("alter table public.food_orders enable row level security");
  expect(sql).toContain("food_has_merchant_access");
  expect(sql).toContain("food_create_manual_order");
  expect(sql).toContain("food_complete_delivery");
  expect(sql).toContain("food_delivery_proofs_dropoff_evidence");
  expect(sql).toContain("p_image_path not like 'delivery/' || p_order_id::text || '/%'");
  expect(sql).not.toContain("fee_percent");
  expect(sql).not.toContain("commission");
  expect(sql).not.toContain("merchant_wallet");
});


test("Food Merchant hardening blocks anonymous accounts from permanent orders and private media", () => {
  const sql = read("../supabase/migrations_wynos_food_merchant_v1_hardening.sql");
  expect(sql).toContain("food_is_permanent_account");
  expect(sql).toContain("permanent account required");
  expect(sql).toContain("(auth.uid()::text || '/slips/%')");
  expect(sql).toContain("public.food_is_permanent_account()");
});


test("Merchant shares WYNOS auth while keeping business tenancy separate", () => {
  const login = read("app/merchant/login/page.tsx");
  const signup = read("app/merchant/signup/page.tsx");
  const auth = read("components/merchant/merchant-auth.tsx");
  const app = read("components/merchant/wynos-merchant-app.tsx");

  expect(login).toContain("MerchantLoginScreen");
  expect(signup).toContain("MerchantSignupScreen");
  expect(auth).toContain('signInWithEmail');
  expect(auth).toContain('getSupabaseBrowserClient');
  expect(auth).toContain("ใช้บัญชี WYNOS เดิมได้");
  expect(auth).toContain("ร้านมี Merchant Account ของตัวเอง");
  expect(auth).toContain("รองรับ Owner และ Staff หลายคน");
  expect(auth).toContain('rememberReturnPath("/merchant/signup")');
  expect(auth).toContain('router.push("/signup/step-1")');
  expect(app).toContain('signedOutPath="/merchant/login"');
  expect(app).toContain("DeveloperRouteGate");
  expect(app).not.toContain("MerchantRouteGate");
});
test("Merchant applications use business tenancy and cannot self-approve", () => {
  const data = read("lib/merchant-application.ts");
  const baseSql = read("../supabase/migrations_wynos_merchant_application_v1.sql");
  const accountSql = read("../supabase/migrations_wynos_merchant_accounts_v2.sql");

  expect(data).toContain('client.rpc("merchant_submit_application"');
  expect(accountSql).toContain("public.merchant_accounts");
  expect(accountSql).toContain("public.merchant_memberships");
  expect(accountSql).toContain("merchant_account_id");
  expect(accountSql).toContain("status='pending'");
  expect(accountSql).toContain("Only admins can review merchant applications");
  expect(baseSql).toContain("alter table public.merchant_applications enable row level security");
  expect(baseSql).toContain("revoke all on public.merchant_applications from anon");
  expect(accountSql).not.toContain("grant update (status, reviewed_at");
});


test("Campaign Center keeps promotion creation in Merchant and pricing in WYNOS Food", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const center = read("components/merchant/merchant-campaign-center.tsx");
  const sql = read("../supabase/migrations_wynos_merchant_campaign_center_v1.sql");

  expect(app).toContain("MerchantCampaignCenter");
  expect(center).toContain("Campaign Center");
  expect(center).toContain("WYNOS Food จะเลือกแคมเปญที่ลูกค้าประหยัดได้มากที่สุด");
  expect(sql).toContain("internal.food_campaign_candidates");
  expect(sql).toContain("order by saving desc");
  expect(sql).toContain("food_quote_order");
  expect(sql).toContain("campaign_applied");
});


test("WYN-193 every Food delivery needs an uploaded photo and notifies the buyer", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const sql = read("../supabase/migrations_wynos_food_delivery_photo_required_v1.sql");

  // The photo comes from an outside courier, so it is picked from the gallery
  // and is required for both "direct" and "dropoff".
  expect(app).not.toContain('capture="environment" onChange={(e) => setDeliveryFile');
  expect(app).toContain('if (!deliveryFile) throw new Error("กรุณาแนบรูปยืนยันการจัดส่งจากคนส่ง");');
  expect(app).toContain("uploadFoodPrivateImage(client, deliveryFile, `delivery/${order.id}`)");

  expect(sql).toContain("create or replace function public.food_complete_delivery(");
  expect(sql).toContain("raise exception 'delivery photo is required'");
  expect(sql).toContain("p_image_path not like 'delivery/' || p_order_id::text || '/%'");
  expect(sql).toContain("o.bucket_id='food-private' and o.name=p_image_path");
  expect(sql).toContain("merchant_has_store_role(v_order.store_id, array['owner','admin','manager','orders','delivery'])");
  expect(sql).toContain("raise exception 'dropoff location is required'");
  expect(sql).not.toContain("case when p_method='dropoff' then p_image_path else null end");
  expect(sql).toContain("insert into public.notifications(recipient_id,actor_id,type,reason)");
  expect(sql).toContain("revoke all on function public.food_complete_delivery(uuid,text,text,text) from public, anon;");
});
