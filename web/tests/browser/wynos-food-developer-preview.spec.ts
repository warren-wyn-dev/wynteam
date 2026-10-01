import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const read = (path: string) => readFileSync(join(process.cwd(), path), "utf8");

test("WYNOS Food is a separate closed developer-only surface", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const page = read("app/food/page.tsx");
  const layout = read("app/food/layout.tsx");
  const manifest = read("app/food/manifest.ts");

  expect(page).toContain("<WynosFoodDeveloperApp />");
  expect(app).toContain('client.rpc("is_developer_account")');
  expect(app).toContain('router.replace("/")');
  expect(layout).toContain("index: false");
  expect(layout).toContain("follow: false");
  expect(manifest).toContain('start_url: "/food"');
  expect(manifest).toContain('scope: "/food"');
  expect(manifest).toContain('theme_color: "#111111"');
});

test("Food customer flow is connected to real ordering, payment and realtime APIs", () => {
  const data = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");

  expect(data).toContain('client.rpc("food_create_order"');
  expect(data).toContain('client.rpc("food_submit_payment"');
  expect(data).toContain('client.rpc("food_cancel_order"');
  expect(data).toContain('client.rpc("food_upsert_customer_address"');
  expect(data).toContain('table: "food_orders"');
  expect(data).toContain('const FOOD_PRIVATE = "food-private"');
  expect(app).toContain("ไปชำระเงิน");
  expect(app).toContain("แจ้งชำระเงิน");
  expect(app).toContain("กำลังเตรียมอาหาร");
  expect(app).toContain("กำลังจัดส่ง");
  expect(app).toContain("หลักฐานการจัดส่ง");
});

test("Food customer checkout uses server-authoritative totals and direct store settlement", () => {
  const sql = read("../supabase/migrations_wynos_food_customer_preview_v1.sql");
  const app = read("components/food/wynos-food-developer-app.tsx");

  expect(sql).toContain("v_subtotal := v_subtotal + (v_item.price * v_qty)");
  expect(sql).toContain("v_total := v_subtotal + v_store.delivery_fee");
  expect(sql).toContain("minimum order not met");
  expect(sql).toContain("menu item is unavailable");
  expect(app).toContain("โอนเงินเข้าบัญชีร้านโดยตรง");
  expect(app).not.toContain("ค่าคอม");
  expect(app).not.toContain("WYNOS Wallet");
});

test("Food developer preview can be tested without exposing the domain publicly", () => {
  const customerSql = read("../supabase/migrations_wynos_food_customer_preview_v1.sql");
  const rolloutSql = read("../supabase/migrations_wynos_food_rollout_gate_v1.sql");

  expect(customerSql).toContain("food_customer_addresses");
  expect(customerSql).toContain("food_is_permanent_account()");
  expect(customerSql).toContain("food_cancel_order");
  expect(rolloutSql).toContain("public_enabled boolean not null default false");
  expect(rolloutSql).toContain("food_public_access_enabled()");
  expect(rolloutSql).toContain("not public.is_developer_account()");
  expect(rolloutSql).toContain("not public.food_public_access_enabled()");
});


test("closed preview lockdown keeps catalog and customer APIs developer-only", () => {
  const sql = read("../supabase/migrations_wynos_food_developer_preview_lockdown.sql");
  const rls = read("../supabase/migrations_wynos_food_developer_preview_rls_lockdown.sql");

  expect(sql).toContain("food_require_developer_preview_access");
  expect(sql).toContain("public.is_developer_account()");
  expect(sql).toContain('create policy "Food stores visible to developers and staff"');
  expect(sql).toContain('create policy "Food menu visible to developers and staff"');
  expect(rls).toContain('create policy "Food orders visible to developer buyer and merchant"');
  expect(rls).toContain("public.is_developer_account()");
  expect(rls).toContain("Food private developer customer and merchant upload");
});
