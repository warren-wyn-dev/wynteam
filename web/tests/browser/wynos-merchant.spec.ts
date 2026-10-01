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
  expect(data).toContain('client.rpc("food_create_manual_order"');
  expect(data).toContain('client.rpc("food_set_payment_status"');
  expect(data).toContain('client.rpc("food_transition_order"');
  expect(data).toContain('client.rpc("food_complete_delivery"');
  expect(data).toContain('const FOOD_PRIVATE = "food-private"');
  expect(data).toContain('table: "food_orders"');
  expect(data).toContain("withoutLocation(file, contentType)");
});

test("Merchant workflow supports manual orders, self delivery and mandatory drop-off proof", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  expect(app).toContain("createManualFoodOrder");
  expect(app).toContain('capture="environment"');
  expect(app).toContain('deliveryMethod === "dropoff"');
  expect(app).toContain("ถ่ายรูปหลักฐานการจัดส่ง");
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
