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
  // The developer gate lives in the data layer the app loads through.
  expect(read("lib/food-customer.ts")).toContain('client.rpc("is_developer_account")');
  expect(app).toContain("fetchFoodCustomerSnapshot(client, userId, pickedStoreRef.current || null)");
  expect(app).toContain('router.replace("/")');
  expect(layout).toContain("index: false");
  expect(layout).toContain("follow: false");
  expect(manifest).toContain('start_url: "/food"');
  expect(manifest).toContain('scope: "/food"');
  expect(manifest).toContain('theme_color: "#e32636"');
});

test("WYNOS Food hides the persistent Social bottom navigation", () => {
  const host = read("components/app-bottom-nav-runtime.tsx");

  expect(host).toContain('const hideForFood = pathname === "/food" || pathname.startsWith("/food/");');
  expect(host).toContain("if (hideForFood || !navState?.visible || !navState.userId) return null;");
});

test("WYNOS Food profile is delivery-specific and separate from Social profile", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const data = read("lib/food-customer.ts");

  expect(app).toContain("โปรไฟล์ WYNOS Food");
  expect(app).toContain("ข้อมูลสำหรับการสั่งและจัดส่งอาหารเท่านั้น");
  expect(app).toContain("ชื่อผู้รับ");
  expect(app).toContain("เบอร์โทร");
  expect(app).toContain("ที่อยู่หลัก");
  expect(app).toContain("โลเคชั่น");
  expect(app).toContain("รายละเอียดเพิ่มเติม");
  expect(app).toContain("ข้อมูลนี้เป็นของ WYNOS Food เท่านั้น และไม่แก้ไขโปรไฟล์ WYNOS");
  expect(app).toContain("showPin={true}");
  expect(app).not.toContain('href="/profile/');
  expect(data).toContain('.from("food_customer_addresses")');
  expect(data).toContain('client.rpc("food_upsert_customer_address"');
});

test("WYNOS Food messages stay inside Food and never open Social Chat", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");

  expect(app).toContain('type FoodTab = "home" | "orders" | "messages" | "cart" | "account"');
  expect(app).toContain('onClick={() => onTab("messages")}');
  expect(app).toContain('tab === "messages" ? <MessagesPanel /> : null');
  expect(app).toContain("แชท WYNOS Food แยกจากแชท WYNOS");
  expect(app).not.toContain('onMessages={() => router.push("/chat")}');
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


test("Food customer access gate keeps preview closed and future rollout explicit", () => {
  const sql = read("../supabase/migrations_wynos_food_customer_access_gate_v2.sql");

  expect(sql).toContain("food_customer_access_enabled()");
  expect(sql).toContain("public.is_developer_account()");
  expect(sql).toContain("public.food_public_access_enabled()");
  expect(sql).toContain('create policy "Food stores visible by rollout gate"');
  expect(sql).toContain('create policy "Food orders visible by rollout gate"');
  expect(sql).toContain('create policy "Food customer addresses visible by rollout gate"');
  expect(sql).toContain('create policy "Food private upload by rollout gate"');
  expect(sql).toContain("food customer access required");
});


test("Food checkout previews Campaign Center savings but revalidates them on the server", () => {
  const data = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const sql = read("../supabase/migrations_wynos_merchant_campaign_center_v1.sql");

  expect(data).toContain('client.rpc("food_quote_order"');
  expect(app).toContain("campaign_discount");
  expect(app).toContain("delivery_discount");
  expect(app).toContain("ส่วนลดจะยืนยันอีกครั้งโดยระบบก่อนสร้างออเดอร์");
  expect(sql).toContain("select * into v_campaign");
  expect(sql).toContain("for update");
  expect(sql).toContain("v_total := greatest");
  expect(sql).toContain("usage_count=usage_count+1");
});

test("WYN-195 WYNOS Food entry sits under the Home tabs and in the drawer for developers only", () => {
  const home = read("components/home/home-screen.tsx");
  const drawer = read("components/home/home-drawer.tsx");
  const shortcut = read("components/home/home-food-shortcut.tsx");

  expect(home).toContain("const showFood = useIsDeveloperAccount(client, userId);");
  expect(home).toContain("{showFood ? <HomeFoodShortcut /> : null}");
  expect(home).toContain("showFood={showFood}");
  expect(shortcut).toContain('href="/food"');
  expect(drawer).toContain("showFood = false");
  expect(drawer).toContain('{showFood ? (');
  expect(drawer).toContain('go("/food")');
});

test("WYN-196 delivery zone: distance fee and radius are enforced on the server", () => {
  const sql = read("../supabase/migrations_wynos_food_delivery_zone_v1.sql");
  const lib = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const merchant = read("components/merchant/wynos-merchant-app.tsx");

  // Server owns the fee and the radius; old signatures cannot bypass them.
  expect(sql).toContain("drop function if exists public.food_quote_order(uuid,jsonb);");
  expect(sql).toContain("drop function if exists public.food_create_order(uuid,text,text,text,text,jsonb);");
  expect(sql).toContain("raise exception 'outside delivery area'");
  expect(sql).toContain("raise exception 'delivery location required'");
  expect(sql).toContain("ceil(greatest(v_distance - v_store.delivery_base_km, 0) * v_store.delivery_fee_per_km)");
  expect(sql).toContain("add column if not exists delivery_radius_km numeric(5,2) not null default 5");
  expect(sql).toContain("from internal.food_delivery_fee(p_store_id, p_latitude, p_longitude) z;");
  expect(sql).not.toMatch(/v_store\.delivery_fee,v_item_totals/);

  // Client sends the pin; checkout blocks unpinned or out-of-range addresses.
  expect(lib).toContain("return location ? { p_latitude: location.latitude, p_longitude: location.longitude } : {};");
  expect(lib).toContain('client.functions.invoke("location-search"');
  expect(app).toContain("location: storeHasDeliveryZone(store) ? addressLocation(address) : null");
  expect(app).toContain("disabled={!address || busy || quoteLoading || Boolean(blockedReason)}");
  expect(app).toContain('aria-label="ค้นหา"');
  expect(merchant).toContain("Math.ceil(");
  expect(app).toContain("<DeliveryPinPicker");
  expect(merchant).toContain("delivery_fee_per_km: Number(form.delivery_fee_per_km || 0)");
  expect(merchant).toContain("const zoneReady = store.delivery_radius_km !== undefined;");
  expect(lib).toContain("...pinParams(input.location)");
  expect(merchant).toContain("foodMapsHref(");
});

test("WYN-197 free place search uses the store's own place list", () => {
  const sql = read("../supabase/migrations_wynos_food_store_places_v1.sql");
  const lib = read("lib/food-customer.ts");
  const merchantLib = read("lib/food-merchant.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const merchant = read("components/merchant/wynos-merchant-app.tsx");

  // Only the store's managers write; customers read through a scoped RPC.
  expect(sql).toContain("alter table public.food_store_places enable row level security;");
  expect(sql).toContain("using (public.food_has_merchant_access(store_id));");
  expect(sql).toContain("with check (public.merchant_has_store_role(store_id, array['owner','admin','manager']));");
  expect(sql).toContain("where p.store_id = p_store_id\n    and p.is_active");
  expect(sql).toContain("revoke all on function public.food_search_store_places(uuid,text) from public, anon;");
  expect(sql).not.toMatch(/to anon/);

  // Food searches the store list first; the geocoder is only a fallback.
  expect(lib).toContain('client.rpc("food_search_store_places"');
  expect(app).toContain("let next = storeId ? (await searchStorePlaces(client, storeId, query)) ?? [] : [];");
  expect(app).toContain("next = await searchFoodPlaces(client, query).catch(() => []);");

  // Merchant manages the list and hides it until the table exists.
  expect(merchantLib).toContain('.from("food_store_places")');
  expect(merchantLib).toContain('if (error.code === "42P01" || error.code === "PGRST205") return null;');
  expect(merchant).toContain("<StorePlacesEditor");
  expect(merchant).toContain("parseFoodLocation(form.coords)");
});
