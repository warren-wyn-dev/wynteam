import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const read = (path: string) => readFileSync(join(process.cwd(), path), "utf8");

test("WYNOS Food is a separate product surface with its own PWA shell", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const page = read("app/food/page.tsx");
  const layout = read("app/food/layout.tsx");
  const manifest = read("app/food/manifest.ts");

  expect(page).toContain("<WynosFoodDeveloperApp />");
  // Food access and rollout checks live in the data layer the app loads through.
  expect(read("lib/food-customer.ts")).toContain('client.rpc("is_developer_account")');
  expect(app).toContain("fetchFoodCustomerSnapshot(client, userId, pickedStoreRef.current || null)");
  expect(app).not.toContain('router.replace("/")');
  expect(app).toContain("<FoodLoadError");
  expect(app).toContain("<FoodDenied />");
  expect(app).toContain('href="https://wynos.online/"');
  expect(layout).toContain("index: true");
  expect(layout).toContain("follow: true");
  expect(manifest).toContain('start_url: "/"');
  expect(manifest).toContain('scope: "/"');
  expect(manifest).toContain('theme_color: "#e32636"');
  expect(manifest).toContain('description: "WYNOS Food Public Beta"');
  const proxy = read("proxy.ts");
  expect(proxy).toContain('new URL("https://food.wynos.online")');
  expect(proxy).toContain('matcher: ["/", "/food", "/food/:path*"]');
});

test("WYNOS Food hides the persistent Social bottom navigation", () => {
  const host = read("components/app-bottom-nav-runtime.tsx");

  expect(host).toContain('const hideForFood = pathname === "/food" || pathname.startsWith("/food/");');
  expect(host).toContain("if (hideForFood || !navState?.visible || !navState.userId) return null;");
});

test("WYNOS Food delivery address uses an interactive map pin flow", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const map = read("components/food/food-delivery-map-picker.tsx");
  const data = read("lib/food-customer.ts");

  expect(app).toContain("ค้นหาและปักหมุดบนแผนที่");
  expect(app).toContain("<FoodDeliveryMapPicker");
  const css = read("app/food/food.css");
  const mapsCss = read("app/maps/maps.css");
  const mapsV2Css = read("app/maps/maps-v2.css");
  const mapsV4Css = read("app/maps/maps-v4.css");
  const serviceArea = JSON.parse(read("public/maps/food-service-area-maha-sarakham.json")) as {
    geometry?: { coordinates?: number[][][] };
  };

  expect(map).toContain('const MAP_STYLE = "/maps/wynos-green.json";');
  expect(map).toContain("maplibre-gl@");
  expect(map).toContain("/dist/maplibre-gl.js");
  expect(map).toContain("https://tile.openstreetmap.org/{z}/{x}/{y}.png");
  expect(map).toContain("map.setStyle(FALLBACK_MAP_STYLE)");
  expect(map).toContain("dragPan: true");
  expect(map).toContain("touchZoomRotate: true");
  expect(map).toContain('addEventListener("touchmove", preventPagePan, { passive: false })');
  expect(mapsCss).toContain("touch-action: none !important");
  expect(mapsCss).toContain("overscroll-behavior: none");
  expect(map).toContain('map.on("style.load", markReady)');
  expect(map).toContain("map.project([nearbyPlace.longitude, nearbyPlace.latitude])");
  expect(map).toContain("wf-map-place-symbol");
  expect(map).toContain("wf-map-user-location");
  expect(map).toContain('anchor: selected ? "bottom" : "center"');
  expect(map).toContain("mapZoom >= 17 ? 18 : mapZoom >= 15.5 ? 12 : mapZoom >= 13.5 ? 8 : 5");
  expect(map).toContain("mapZoom >= 17 ? 46 : mapZoom >= 15.5 ? 58 : 70");
  expect(map).toContain("return aSelected ? -1 : 1");
  expect(map).toContain("wf-map-place-marker is-${kind}");
  expect(mapsV2Css).toContain(".wf-map-place-marker.is-cafe");
  expect(mapsV2Css).toContain(".wf-map-user-location");

  expect(map).toContain('const SERVICE_AREA_URL = "/maps/food-service-area-maha-sarakham.json";');
  expect(map).toContain("pointInServiceArea(location, serviceAreaBoundary)");
  expect(map).toContain("map.addSource(SERVICE_AREA_SOURCE");
  expect(map).toContain("SERVICE_AREA_FILL_LAYER");
  expect(map).toContain("SERVICE_AREA_LINE_LAYER");
  expect(map).toContain('serviceAreaState === "outside"');
  expect(map).toContain("ยืนยันไม่ได้ · นอกพื้นที่ให้บริการ");
  expect(mapsCss).toContain(".wf-map-service-area");
  expect(mapsCss).toContain(".wf-map-service-area-warning");
  expect(serviceArea.geometry?.coordinates?.[0]?.length ?? 0).toBeGreaterThan(1000);
  expect(map).toContain("แผนที่ยังโหลดไม่สำเร็จ");
  expect(css).toContain(".wf-map-canvas.maplibregl-map");
  expect(css).toContain(".wf-map-loading--error");
  expect(map).toContain("Search by LocationIQ.com");
  expect(map).toContain("เลื่อนแผนที่ให้หมุดตรงจุดรับอาหาร");
  expect(map).toContain("currentFoodLocation()");
  expect(map).toContain("searchFoodPlaces(client, trimmed, location)");
  expect(map).toContain("reverseFoodPlace(client, next)");
  expect(map).toContain("กำลังค้นหาชื่อสถานที่…");
  expect(map).toContain("ไม่พบชื่อสถานที่");
  expect(map).toContain("wf-map-confirm-address");
  expect(map).toContain("wf-map-confirm-coordinates");
  expect(map).not.toContain("function placeText(");
  expect(map).toContain("autoLocate = false");
  expect(map).toContain("FoodLocationMapPreview");
  expect(map).toContain("fetchWynosPlaceDetails");
  expect(map).toContain("wf-map-store-cover");
  expect(map).toContain("wf-map-entrance-marker");
  expect(map).toContain("ดูจุดรับอาหารบนแผนที่");
  expect(map).toContain("เลื่อนแผนที่เพื่อปรับหมุดให้ตรงตำแหน่งจริง");
  expect(map).toContain('if (standalone) setSheetDetent("half");');
  expect(mapsV4Css).toContain(".wf-map-sheet.is-searching");
  expect(mapsV4Css).toContain("max-height: min(52dvh, 430px)");
  expect(data).toContain('body: { mode: "reverse", lat: location.latitude, lon: location.longitude }');
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

test("WYNOS Maps Places enriches saved addresses without exposing customer homes", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const data = read("lib/food-customer.ts");
  const sql = read("../supabase/migrations_wynos_maps_places_saved_addresses_v1.sql");
  const nearbySql = read("../supabase/migrations_wynos_maps_nearby_places_v1.sql");
  const nearbyRankingSql = read("../supabase/migrations_wynos_maps_nearby_ranking_v2.sql");
  const reverseSql = read("../supabase/migrations_wynos_maps_reverse_place_v1.sql");
  const osmFallbackSql = read("../supabase/migrations_wynos_maps_osm_reverse_fallback_v1.sql");
  const photonFallbackSql = read("../supabase/migrations_wynos_maps_photon_fallback_v1.sql");
  const suggestionSql = read("../supabase/migrations_wynos_maps_place_suggestions_v1.sql");
  const overtureWorkflow = read("../.github/workflows/wynos-maps-import-overture-places.yml");
  const overtureImporter = read("../.github/scripts/import-overture-places.py");
  const publicGeocoder = read("../supabase/functions/wynos-maps-geocode/index.ts");
  const map = read("components/food/food-delivery-map-picker.tsx");

  expect(sql).toContain("create table if not exists public.wynos_places");
  expect(sql).toContain("alter table public.wynos_places enable row level security");
  expect(sql).toContain('revoke all on table public.wynos_places from anon, authenticated');
  expect(sql).toContain("food_upsert_customer_address_v2");
  expect(sql).toContain("food_delivery_availability");
  expect(sql).toContain("wynos_search_places");
  expect(sql).toContain("place_id text references public.wynos_places(id) on delete set null");
  expect(data).toContain('client.rpc("wynos_search_places"');
  expect(data).toContain('client.rpc("wynos_search_store_places"');
  expect(data).toContain('client.rpc("food_upsert_customer_address_v2"');
  expect(data).toContain('client.rpc("food_delivery_availability"');
  expect(data).toContain('client.rpc("wynos_nearby_places"');
  expect(data).toContain('client.rpc("wynos_reverse_place"');
  expect(data).toContain('client.functions.invoke("wynos-maps-geocode"');
  expect(reverseSql).toContain("create or replace function public.wynos_reverse_place");
  expect(reverseSql).toContain("reserve_wynos_maps_geocode_request");
  expect(osmFallbackSql).toContain("wynos_maps_reverse_cache");
  expect(osmFallbackSql).toContain("wynos_maps_reverse_cache");
  expect(photonFallbackSql).toContain("reserve_wynos_maps_photon_request");
  expect(publicGeocoder).toContain("https://photon.komoot.io");
  expect(publicGeocoder).toContain("photonSearch");
  expect(publicGeocoder).toContain("photonReverse");
  expect(publicGeocoder).toContain("nearbyBbox");
  expect(publicGeocoder).toContain("WYNOSMaps/1.0");
  expect(publicGeocoder).toContain('X-WYNOS-Maps-Provider');
  expect(publicGeocoder).toContain("LOCATIONIQ_API_KEY");
  expect(map).toContain("Geocoding by Photon");
  expect(map).toContain("© OpenStreetMap contributors");
  expect(map).toContain("Places: Overture Maps Foundation");
  expect(map).toContain("wf-map-attribution-button");
  expect(map).toContain("wf-map-attribution-panel");
  expect(map).toContain("ข้อมูลแผนที่และแหล่งข้อมูล");
  expect(map).toContain("attributionControl: false");
  expect(map).not.toContain("wf-map-geocoder-credit");
  expect(nearbySql).toContain("create or replace function public.wynos_nearby_places");
  expect(nearbySql).toContain("to anon, authenticated");
  expect(nearbyRankingSql).toContain("internal.food_distance_km(p_latitude, p_longitude, p.latitude, p.longitude)");
  expect(nearbyRankingSql).toContain("when p.category = 'residence' then 0");
  expect(map).toContain("nearbyRadiusForZoom");
  expect(map).toContain("fetchNearbyWynosPlaces");
  expect(map).toContain("wf-map-place-label");
  expect(map).toContain("เพิ่มสถานที่ที่หายไป");
  expect(map).toContain("submitWynosPlaceSuggestion");
  expect(data).toContain('client.rpc("submit_wynos_place_suggestion"');
  expect(suggestionSql).toContain("create table if not exists public.wynos_place_suggestions");
  expect(suggestionSql).toContain("admin_review_wynos_place_suggestion");
  expect(suggestionSql).toContain("daily suggestion limit reached");
  expect(overtureWorkflow).toContain("overturemaps download");
  expect(overtureWorkflow).toContain("activate_confidence");
  expect(overtureImporter).toContain("source_ref");
  expect(overtureImporter).toContain("activate-confidence");
  expect(map).toContain("สั่งใน WYNOS Food");
  expect(map).toContain("https://food.wynos.online/?store=");
  expect(app).toContain('new URLSearchParams(window.location.search).get("store")');
  expect(app).toContain("ชื่ออาคาร / หมู่บ้าน");
  expect(app).toContain("หมายเหตุถึงผู้จัดส่ง");
  expect(app).toContain("WYNOS Place ·");
  expect(app).toContain('const WYNOS_MAPS_PIN_STORAGE_KEY = "wynos:maps:last-pin";');
  expect(app).toContain("draftWithLastWynosMapsPin");
});

test("WYNOS Food messages stay inside Food and never open Social Chat", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");

  expect(app).toContain('type FoodTab = "home" | "orders" | "messages" | "cart" | "account"');
  expect(app).toContain('onClick={() => onTab("messages")}');
  expect(app).toContain('tab === "messages" ? <MessagesPanel /> : null');
  expect(app).toContain("แชท WYNOS Food แยกจากแชท WYNOS");
  expect(app).not.toContain('onMessages={() => router.push("/chat")}');
});

test("Food checkout can create scheduled orders without changing immediate-order flow", () => {
  const data = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const css = read("app/food/food.css");

  expect(data).toContain('client.rpc("food_create_scheduled_order"');
  expect(data).toContain('scheduledFor?: string | null');
  expect(app).toContain('useState<"asap" | "scheduled">("asap")');
  expect(app).toContain("สั่งล่วงหน้า");
  expect(app).toContain("scheduledDate.toISOString()");
  expect(app).toContain("foodStoreIsEffectivelyOpen(store, selectedDate)");
  expect(app).toContain("ร้านปิดในวันหรือเวลาที่เลือก");
  expect(app).toContain("order.scheduled_for");
  expect(css).toContain(".wf-schedule-choice");
  expect(css).toContain(".wf-scheduled-banner");
});

test("Food customer menu options, stock and history are wired end to end", () => {
  const data = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const css = read("app/food/food.css");
  const stockSql = read("../supabase/migrations_wynos_food_customer_stock_v1.sql");

  expect(data).toContain("FoodMenuOptionGroup");
  expect(data).toContain("foodCartLineKey");
  expect(data).toContain("foodCartLineUnitPrice");
  expect(data).toContain("foodCartLineOptionsValid");
  expect(data).toContain("selected_options: line.selected_options ?? []");
  expect(data.match(/selected_options: line\.selected_options \?\? \[\]/g)?.length ?? 0).toBeGreaterThanOrEqual(2);
  expect(data).toContain('client.rpc("food_menu_stock_remaining"');
  expect(data).toContain("fetchFoodCustomerOrdersPage");
  expect(app).toContain('className="wf-option-groups"');
  expect(app).toContain("selected_options: selectedOptions");
  expect(app).toContain("foodMenuQuantityLimit");
  expect(app).toContain("ดูคำสั่งซื้อเก่ากว่านี้");
  expect(app).toContain("เพิ่มอีก {foodMoney(Math.max(0, minimum - subtotal))}");
  expect(css).toContain(".wf-option-choices");
  expect(css).toContain(".wf-load-more");
  expect(stockSql).toContain("create or replace function public.food_menu_stock_remaining");
  expect(stockSql).toContain("public.food_customer_access_enabled()");
  expect(stockSql).toContain("grant execute on function public.food_menu_stock_remaining(uuid) to authenticated");
});

test("Food customer menu supports add-ons, variants, live stock and real push registration", () => {
  const data = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const push = read("lib/push-notifications.ts");
  const stockSql = read("../supabase/migrations_wynos_food_customer_stock_v1.sql");

  expect(data).toContain("selected_options: line.selected_options ?? []");
  expect(data).toContain("foodCartLineKey");
  expect(data).toContain("foodCartLineUnitPrice");
  expect(data).toContain('client.rpc("food_menu_stock_remaining"');
  expect(app).toContain("subscribeToPushNotifications(client, userId)");
  expect(app).toContain("isCurrentDevicePushEnabled(client, userId)");
  expect(app).toContain("กรุณาเลือกตัวเลือกที่จำเป็นให้ครบ");
  expect(app).toContain("เพิ่มอีก");
  expect(app).toContain("ดูคำสั่งซื้อเก่ากว่านี้");
  expect(stockSql).toContain("create or replace function public.food_menu_stock_remaining");
  expect(stockSql).toContain("revoke all on function public.food_menu_stock_remaining(uuid) from public, anon");
  expect(push).toContain("drop|food");
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
  expect(app).toContain("subscribeToPushNotifications(client, userId)");
  expect(app).toContain("isCurrentDevicePushEnabled(client, userId)");
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

test("Food rollout migration keeps the public-access switch explicit", () => {
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


test("Food customer access gate supports developer and public rollout access", () => {
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

test("WYN-195 WYNOS Food entry sits under the Home tabs and in the drawer (WYN-211/212)", () => {
  const home = read("components/home/home-screen.tsx");
  const drawer = read("components/home/home-drawer.tsx");
  const shortcut = read("components/home/home-food-shortcut.tsx");

  expect(home).toContain("const showFood = Boolean(userId);");
  expect(home).toContain("{foodShortcut.visible ? <HomeFoodShortcut onHide={foodShortcut.hide} /> : null}");
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
  const map = read("components/food/food-delivery-map-picker.tsx");
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
  expect(app).toContain("disabled={!address || busy || quoteLoading || Boolean(blockedReason) || !scheduledValid}");
  expect(map).toContain('aria-label="ค้นหาสถานที่หรือที่อยู่"');
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
  const map = read("components/food/food-delivery-map-picker.tsx");
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
  expect(map).toContain("let next = storeId ? (await searchStorePlaces(client, storeId, trimmed)) ?? [] : [];");
  expect(map).toContain("if (!next.length) next = await searchFoodPlaces(client, trimmed);");

  // Merchant manages the list and hides it until the table exists.
  expect(merchantLib).toContain('.from("food_store_places")');
  expect(merchantLib).toContain('if (error.code === "42P01" || error.code === "PGRST205") return null;');
  expect(merchant).toContain("<StorePlacesEditor");
  expect(merchant).toContain("parseFoodLocation(form.coords)");
});

test("WYN-211 WYNOS Food is open to everyone; ordering only in Maha Sarakham", () => {
  const sql = read("../supabase/migrations_wynos_food_service_area_v1.sql");
  const lib = read("lib/food-customer.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");
  const panels = read("components/merchant/merchant-core-panels.tsx");
  const workflow = read("../.github/workflows/food-apply-wyn211.yml");

  // Public rollout switch, and the client follows the server's access rule.
  expect(sql).toContain("update public.food_rollout_settings set public_enabled = true where id = true;");
  expect(lib).toContain('client.rpc("food_customer_access_enabled")');
  expect(lib).toContain("if (!developer && access.error) throw new Error(access.error.message);");
  expect(lib).toContain("if (!developer && access.data !== true) {");
  // Server: store pin and delivery pin must be inside the province (developers exempt).
  expect(sql).toContain("raise exception 'store is outside the service area';");
  expect(sql).toContain("raise exception 'outside service area';");
  expect(sql).toContain("case when not internal.food_in_service_area(s.latitude, s.longitude) then 'service_area' end");
  expect(sql).toContain("revoke all on table public.food_service_areas from public, anon, authenticated;");
  // Web: customers outside the area only get the introduction page.
  expect(app).toContain('if (!snapshot.developer && area !== "inside") {');
  expect(app).toContain("<h1>WYNOS Food เปิดให้บริการเฉพาะจังหวัดมหาสารคาม</h1>");
  expect(lib).toContain('if (message.includes("outside service area")) return "ตอนนี้ WYNOS Food ส่งได้เฉพาะในจังหวัดมหาสารคาม";');
  expect(panels).toContain('service_area: "ปักหมุดร้านในจังหวัดมหาสารคาม",');
  expect(workflow).toContain("github.event.inputs.confirm == 'APPLY-WYN-211'");
});

test("WYN-212 Home Food banner only for people known in Maha Sarakham; drawer for all", () => {
  const home = read("components/home/home-screen.tsx");
  const shortcut = read("components/home/home-food-shortcut.tsx");
  const memory = read("lib/food-area-memory.ts");
  const app = read("components/food/wynos-food-developer-app.tsx");

  // Drawer keeps Food for every signed-in user; the banner is gated.
  expect(home).toContain("const showFood = Boolean(userId);");
  expect(home).toContain("showFood={showFood}");
  expect(home).toContain("const foodShortcut = useHomeFoodShortcut(client, userId);");
  // Home never asks for GPS: Food's own check or the saved delivery pin.
  expect(memory).not.toContain("geolocation");
  expect(memory).toContain('client.rpc("food_service_area_check"');
  expect(memory).toContain('.from("food_customer_addresses")');
  expect(memory).toContain("? Promise.resolve(memory.area === \"inside\")");
  expect(app).toContain('rememberFoodArea(userId, inside ? "inside" : "outside");');
  // The banner can be hidden for good.
  expect(shortcut).toContain('aria-label="ซ่อน WYNOS Food จากหน้าหลัก" onClick={onHide}');
  expect(memory).toContain('write(hiddenKey(userId), "1");');
});

test("WYNOS Food home separates store discovery from the storefront", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const css = read("app/food/food.css");

  expect(app).toContain("A Food home should remain a directory even when only one store is live.");
  expect(app).toContain("storefrontOpen: boolean;");
  expect(app).toContain('storeSection === "reviews" ? <StoreReviewsSection');
  expect(app).toContain('storeSection === "info" ? (');
  expect(app).toContain('className="wf-store-cart-bar"');
  expect(app).toContain('setStorefrontOpen(true);');
  expect(css).toContain(".wf-dir-cover");
  expect(css).toContain(".wf-store-tabs");
  expect(css).toContain(".wf-store-cart-bar");
});

test("WYNOS Food storefront uses compact search and keeps favorite off the category row", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const css = read("app/food/food.css");

  expect(app).toContain('className="wf-menu-search-trigger"');
  expect(app).toContain('aria-label="ค้นหาเมนูอาหาร"');
  expect(app).toContain('className="wf-store-favorite');
  expect(app).toContain('aria-label="รายการโปรด"');
  expect(app).toContain('aria-pressed={favorite}');
  expect(app).toContain('<Sheet title="ค้นหาเมนูอาหาร"');
  expect(app).not.toContain('<label className="wf-search">\n        <Search size={19} strokeWidth={1.7} />\n        <input value={query}');
  expect(app).not.toContain('>ร้านโปรด</button>');
  expect(css).toContain(".wf-menu-filter-bar");
  expect(css).toContain(".wf-menu-search-trigger");
  expect(css).toContain(".wf-store-favorite");
});

test("WYNOS Food menu search shows popular, recent and compact result rows", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const css = read("app/food/food.css");
  const en = read("lib/i18n/en.ts");

  expect(app).toContain("<h3>เมนูยอดนิยม</h3>");
  expect(app).toContain("<h3>คำค้นหาล่าสุด</h3>");
  expect(app).toContain('className="wf-menu-popular"');
  expect(app).toContain('className="wf-menu-recent"');
  expect(app).toContain('className="wf-menu-search-row"');
  expect(app).toContain('className="wf-menu-search-add"');
  expect(app).toContain("wynos-food-menu-search-v1:");
  expect(css).toContain(".wf-menu-popular");
  expect(css).toContain("grid-auto-columns: 118px;");
  expect(css).toContain("grid-area: auto !important;");
  expect(css).toContain(".wf-menu-recent");
  expect(css).toContain(".wf-menu-search-row");
  expect(css).toContain("min-height: 70px;");
  expect(css).toContain("min-height: 60px;");
  expect(css).toContain("display: flex;");
  expect(css).toContain("flex: 0 0 60px;");
  expect(css).toContain("white-space: normal;");
  expect(css).toContain(".wf-menu-search-add");
  expect(css).toContain("width: 36px;");
  expect(en).toContain('"เมนูยอดนิยม": "Popular menu"');
  expect(en).toContain('"คำค้นหาล่าสุด": "Recent searches"');
});



test("Food customer options, stock, push and pagination are wired end-to-end", () => {
  const app = read("components/food/wynos-food-developer-app.tsx");
  const data = read("lib/food-customer.ts");
  const push = read("lib/push-notifications.ts");
  const sql = read("../supabase/migrations_wynos_food_customer_stock_v1.sql");

  expect(data).toContain("selected_options: line.selected_options ?? []");
  expect(data).toContain("foodCartLineKey");
  expect(data).toContain("foodCartLineUnitPrice");
  expect(data).toContain("food_menu_stock_remaining");
  expect(data).toContain("fetchFoodCustomerOrdersPage");
  expect(app).toContain("subscribeToPushNotifications(client, userId)");
  expect(app).toContain("foodMenuQuantityLimit");
  expect(app).toContain("เพิ่มอีก");
  expect(app).toContain("ร้านปิดในวันหรือเวลาที่เลือก");
  expect(app).toContain("ดูคำสั่งซื้อเก่ากว่านี้");
  expect(push).toContain("|food)");
  expect(sql).toContain("create or replace function public.food_menu_stock_remaining");
  expect(sql).toContain("revoke all on function public.food_menu_stock_remaining(uuid) from public, anon");
});
