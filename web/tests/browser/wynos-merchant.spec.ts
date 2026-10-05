import { expect, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { orderDeliveryProof } from "../../lib/food-delivery-proof";

const read = (path: string) => readFileSync(join(process.cwd(), path), "utf8");

test("Merchant is a separate installable app surface with the red WYNOS identity", () => {
  const page = read("app/merchant/page.tsx");
  const layout = read("app/merchant/layout.tsx");
  const manifest = read("app/merchant/manifest.ts");
  const css = read("app/merchant/merchant.css");

  expect(page).toContain("<WynosMerchantApp />");
  // The manifest URL may carry an icon cache-busting query (?v=…).
  expect(layout).toMatch(/manifest: "\/merchant\/manifest\.webmanifest(\?v=[^"]+)?"/);
  expect(layout).toContain('title: "Wynos Merchant"');
  expect(manifest).toContain('start_url: "/merchant"');
  expect(manifest).toContain('scope: "/merchant"');
  expect(manifest).toContain('theme_color: "#ee1228"');
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

test("Merchant production polish supports multiple stores, paged orders, help and printing", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const css = read("app/merchant/merchant.css");

  expect(data).toContain("stores: FoodStore[]");
  expect(data).toContain("fetchMerchantOrdersPage");
  expect(data).toContain(".range(safeOffset, safeOffset + safeLimit)");
  expect(data).not.toContain(".limit(250)");
  expect(app).toContain('MERCHANT_STORE_KEY = "wynos-merchant-store-v1"');
  expect(app).toContain('className="wm-store-switcher"');
  expect(app).toContain("setSelectedStoreId(storeId)");
  expect(app).toContain("โหลดออเดอร์เก่ากว่านี้");
  expect(app).toContain("function HelpPanel");
  expect(app).toContain("@wynos_s");
  expect(app).toContain("window.print()");
  expect(css).toContain("@media print");
});

test("Merchant keeps scheduled orders and tax receipts while More stays simple", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const css = read("app/merchant/merchant.css");
  const sql = read("../supabase/migrations_wynos_merchant_ops_completion_v1.sql");

  expect(app).not.toContain('onOpenTab("kitchen")');
  expect(app).not.toContain("function KitchenPanel");
  expect(app).not.toContain("ครัว / KDS");
  expect(css).not.toContain(".wm-kitchen-board");
  expect(app).toContain("เปิดรับออเดอร์ล่วงหน้า");
  expect(app).toContain("แสดงข้อมูลภาษีในใบเสร็จ");
  expect(app).toContain('className="wm-print-document"');
  expect(app).toContain('name="settings" size={52} />');
  expect(app).toContain('name="help" size={52} />');
  expect(css).toContain("grid-template-columns: repeat(4, minmax(0, 1fr))");
  expect(data).toContain("scheduled_orders_enabled?: boolean");
  expect(data).toContain("tax_invoice_enabled?: boolean");
  expect(data).toContain("receipt_tax_id?: string | null");
  expect(css).toContain(".wm-print-document");
  expect(sql).toContain("food_create_scheduled_order");
  expect(sql).toContain("food_order_receipt_snapshot");
  expect(sql).toContain("scheduled_for timestamptz");
  expect(sql).toContain("tax_invoice_enabled boolean");
});

test("Merchant notification center groups Push, order sound, vibration, quiet hours and tests", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const center = read("components/merchant/merchant-notification-settings.tsx");
  const alert = read("components/merchant/merchant-order-alert.tsx");
  const prefs = read("lib/merchant-notification-preferences.ts");
  const prompt = read("components/merchant/merchant-notification-prompt.tsx");
  const css = read("app/merchant/merchant.css");

  expect(app).toContain('"notifications"');
  expect(app).toContain("<MerchantNotificationSettings");
  expect(app).toContain('onOpenTab("notifications")');
  expect(app).not.toContain(">ลองเสียงออเดอร์</button>");
  expect(center).toContain("Web Push บนอุปกรณ์นี้");
  expect(center).toContain("เสียงออเดอร์");
  expect(center).toContain("การสั่น");
  expect(center).toContain("Quiet Hours");
  expect(center).toContain("ลองเสียงออเดอร์");
  expect(center).toContain("<MerchantNotificationTest");
  expect(prefs).toContain("MERCHANT_ALERT_PREFS_KEY");
  expect(alert).toContain("merchantAlertQuietNow");
  expect(prompt).toContain("isPushChosenOff(userId)");
  expect(css).toContain(".wm-notification-card");
});

test("Merchant can upload and preview store profile and cover images", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const food = read("components/food/wynos-food-developer-app.tsx");

  expect(data).toContain("logo_path: patch.logo_path");
  expect(data).toContain("cover_path: patch.cover_path");
  expect(app).toContain('chooseBrandImage("logo"');
  expect(app).toContain('chooseBrandImage("cover"');
  expect(app).toContain("รูปโปรไฟล์และรูปปกร้าน");
  expect(app).toContain("wm-store-brand-card-cover");
  expect(app).toContain("logo_path: logo");
  expect(app).toContain("cover_path: cover");
  expect(food).toContain("foodPublicUrl(client, store.cover_path)");
  expect(food).toContain("foodPublicUrl(client, store.logo_path)");
});

test("Merchant uses interactive maps for store, pickup and frequent delivery places", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const layout = read("app/merchant/layout.tsx");
  const sql = read("../supabase/migrations_wynos_food_store_pickup_point_v1.sql");

  expect(layout).toContain('import "../food/food.css"');
  expect(app).toContain("FoodLocationMapPreview");
  expect(app).toContain("FoodDeliveryMapPicker");
  expect(app).toContain("checkFoodServiceArea");
  expect(app).toContain('setMapTarget("store")');
  expect(app).toContain('setMapTarget("pickup")');
  expect(app).toContain("จุดรับอาหาร / ทางเข้าร้านสำหรับไรเดอร์");
  expect(app).toContain("ค้นหาและเลือกบนแผนที่");
  expect(app).toContain("ร้านอยู่นอกพื้นที่ให้บริการปัจจุบัน");
  expect(data).toContain("pickup_latitude: patch.pickup_latitude");
  expect(data).toContain("pickup_longitude: patch.pickup_longitude");
  expect(data).toContain("pickup_note: patch.pickup_note");
  expect(sql).toContain("add column if not exists pickup_latitude");
  expect(sql).toContain("entrance_latitude = new.pickup_latitude");
  expect(sql).toContain("create or replace function public.wynos_place_details");
});

test("Merchant store settings are grouped into clear navigable categories", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const css = read("app/merchant/merchant.css");

  for (const section of [
    "wm-store-section-info",
    "wm-store-section-media",
    "wm-store-section-hours",
    "wm-store-section-delivery",
    "wm-store-section-payment",
  ]) expect(app).toContain(section);

  expect(app).toContain("ข้อมูลร้าน");
  expect(app).toContain("รูปภาพร้าน");
  expect(app).toContain("เวลาเปิด–ปิดและการเตรียมอาหาร");
  expect(app).toContain("ตำแหน่งและการจัดส่ง");
  expect(app).toContain("การรับชำระเงิน");
  expect(app).toContain("wm-settings-savebar");
  expect(css).toContain("grid-template-columns: repeat(5, minmax(0, 1fr))");
  expect(css).toContain(".wm-store-settings-nav");
  expect(css).toContain(".wm-settings-category");
});

test("Merchant production readiness suite covers hours, publish gate, ETA, ordering and audit", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const merchant = read("lib/food-merchant.ts");
  const availability = read("lib/food-store-availability.ts");
  const sql = read("../supabase/migrations_wynos_merchant_production_readiness_v1.sql");

  expect(app).toContain("ความพร้อมของร้าน");
  expect(app).toContain("เวลาเปิด–ปิดรายวัน");
  expect(app).toContain("วันหยุดพิเศษ");
  expect(app).toContain("ปิดชั่วคราว");
  expect(app).toContain("Preview หน้าร้าน");
  expect(app).toContain("หมดวันนี้");
  expect(app).toContain("draggable={!q}");
  expect(app).toContain("ประวัติการแก้ไขร้าน");
  expect(app).toContain("checkMerchantLocationQuality");
  expect(merchant).toContain("food_store_publish_readiness");
  expect(merchant).toContain("merchant_store_audit_history");
  expect(merchant).toContain("sold_out_until");
  expect(availability).toContain("foodEstimateDeliveryRange");
  expect(availability).toContain("foodStoreIsEffectivelyOpen");
  expect(sql).toContain("food_stores_guard_publish_readiness");
  expect(sql).toContain("food_orders_guard_store_schedule");
  expect(sql).toContain("food_order_items_guard_availability");
  expect(sql).toContain("daily_stock_limit");
  expect(app).toContain("จำนวนขายต่อวัน");
  expect(sql).toContain("merchant_menu_reordered");
});

test("Merchant receives orders from WYNOS Food only while keeping delivery workflow", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");
  const guardSql = read("../supabase/migrations_wynos_food_orders_only_v1.sql");

  expect(app).not.toContain("<small>ออเดอร์จาก WYNOS Food</small><h1>ออเดอร์</h1>");
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
  expect(app).toContain("disabled={locked || !deliveryFile");
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
  // WYN-205: the store's own discounts are called "โปรโมชั่น" in Merchant.
  expect(center).toContain("<strong>โปรโมชั่นของร้าน</strong>");
  expect(center).toContain("WYNOS Food จะเลือกโปรโมชั่นที่ลูกค้าประหยัดได้มากที่สุด");
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

test("WYN-194 Food storage is isolated per store", () => {
  const sql = read("../supabase/migrations_wynos_food_storage_store_isolation_v1.sql");

  // No storage policy may grant access to every store's files any more.
  const policies = sql.replace(/^--.*$/gm, "");
  expect(policies).not.toContain("food_has_merchant_access(null)");
  expect(sql).toContain("public.food_has_merchant_access(o.store_id)");
  expect(sql).toContain("and o.status = 'out_for_delivery'");
  expect(sql).toContain("public.merchant_has_store_role(o.store_id, array['owner','admin','manager','orders','delivery'])");
  expect(sql).toContain("create or replace function public.food_store_media_writable(p_name text)");
  expect(sql).toContain("(storage.foldername(p_name))[1] = 'stores'");
  expect(sql).toContain("with check (bucket_id='food-public' and public.food_store_media_writable(name));");
  // Index-friendly uuid comparison, never a cast of a non-uuid path segment.
  expect(sql).toContain("o.id = public.food_path_uuid((storage.foldername(name))[2])");
  expect(policies).not.toContain("o.id::text");
  for (const policy of [
    "Food private media readable by rollout gate",
    "Food private upload by rollout gate",
    "Food public media merchant upload",
    "Food public media merchant update",
    "Food public media merchant delete",
  ]) {
    expect(sql).toContain(`drop policy if exists "${policy}" on storage.objects;`);
    expect(sql).toContain(`create policy "${policy}"`);
  }
  // Slips and delivery photos are evidence: no API update/delete for anyone.
  for (const policy of ["Food private update by rollout gate", "Food private delete by rollout gate"]) {
    expect(sql).toContain(`drop policy if exists "${policy}" on storage.objects;`);
    expect(sql).not.toContain(`create policy "${policy}"`);
  }
});

test("Delivery proof is read from the one-to-one PostgREST embed", () => {
  const proof = { id: "p", order_id: "o", method: "direct", location_note: null, image_path: "delivery/o/a.jpg", created_at: "" };
  expect(orderDeliveryProof({ food_delivery_proofs: proof })).toEqual(proof);
  expect(orderDeliveryProof({ food_delivery_proofs: [proof] })).toEqual(proof);
  expect(orderDeliveryProof({ food_delivery_proofs: null })).toBeUndefined();
  expect(orderDeliveryProof({})).toBeUndefined();
  for (const lib of ["lib/food-merchant.ts", "lib/food-customer.ts"]) {
    expect(read(lib)).toContain('export { orderDeliveryProof } from "@/lib/food-delivery-proof";');
  }
  for (const file of ["components/merchant/wynos-merchant-app.tsx", "components/food/wynos-food-developer-app.tsx"]) {
    expect(read(file)).not.toContain("food_delivery_proofs?.[0]");
  }
});

test("WYN-198 Merchant order flow: one main action per order and a loud new-order alert", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const alert = read("components/merchant/merchant-order-alert.tsx");
  const css = read("app/merchant/merchant.css");

  // Four tabs in working order; the active-order page intentionally has no search/filter toolbar.
  expect(app).toContain('type OrderFilter = "new" | "cooking" | "delivery" | "done";');
  expect(app).toContain('useState<OrderFilter>("new")');
  expect(app).not.toContain("wm-order-search-tools");
  expect(app).not.toContain('aria-label="ค้นหาและตัวกรอง"');

  // The card runs simple steps; the slip and the delivery photo still need the order open.
  expect(app).toContain('if (next.step === "check_slip" || next.step === "deliver") {');
  expect(app).toContain('await transitionFoodOrder(client, order.id, "preparing", order.eta_minutes ?? Number(store?.prep_time_max_minutes ?? 30));');

  // One button confirms the payment and accepts; accepting still needs a paid order.
  expect(app).toContain('await setFoodPaymentStatus(client, order.id, "paid");\n                    await transitionFoodOrder(client, order.id, "preparing", eta);');
  expect(app).toContain('order.status === "pending_acceptance" && (order.payment_status === "submitted" || order.payment_status === "paid")');

  // WYN-202: the alert rings until the order is opened or accepted, with no time limit.
  expect(alert).not.toContain("ALERT_MAX_MS");
  expect(alert).toContain("const timer = window.setInterval(ring, ALERT_REPEAT_MS);");
  expect(alert).not.toContain('className="wm-alert-close"');
  expect(alert).toContain('role="alertdialog"');
  expect(alert).toContain('window.addEventListener("pointerdown", unlock);');
  expect(alert).toContain('if (event.key === "Escape") {');
  expect(app).toContain("key={alertKey(alertOrder)}");
  expect(app).toContain("// Reload on failure too: the order may have moved on elsewhere.");
  // A refresh asked for during another refresh is queued, not dropped.
  expect(app).toContain("reloadQueuedRef.current = true;");
  expect(app).toContain('aria-pressed={filter === item.key}');
  expect(app).not.toContain('role="tablist"');
  // The slip must be on screen before the combined button works, a failed
  // second step still reloads, and the alert never hides behind another sheet.
  expect(app).toContain("disabled={locked || !slipShown}");
  expect(app).toContain("onLoad={() => setSlipImage({ url: slipUrl, ok: true })}");
  expect(app).toContain("// Reload after failures too: a two-step action may have half succeeded.");
  expect(app).toContain("{alertOrder && !selectedOrder && !menuDraft && !storeEditing ? (");
  // A pressed card stays busy until a reload shows the order's new status.
  expect(app).toContain("acting={actedFrom.get(order.id) === order.status}");
  expect(app).toContain("const locked = busy || actedAt === stateKey;");
  expect(app).toContain("const stateKey = `${order.status}:${order.payment_status}:${order.updated_at}`;");
  expect(app).toContain('className="wm-order-card-open" type="button" disabled={acting}');
  expect(alert).toContain('context.addEventListener("statechange", sync);');
  expect(app).toContain("return () => { if (opener?.isConnected) opener.focus(); };");
  expect(css).toContain("max-height: calc(100dvh - 32px);");
  expect(css).toContain(".wm-card-action { min-height: 54px; font-size: 17px; }");
  expect(css).toContain("@media (prefers-reduced-motion: reduce)");
});

test("WYN-199 Merchant asks to turn on notifications as soon as it opens", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const prompt = read("components/merchant/merchant-notification-prompt.tsx");

  // Opens automatically, and again from the bell, using the shared Push flow
  // (permission request first, then the device token in push_tokens).
  expect(app).toContain('useState<"auto" | "bell" | null>("auto")');
  expect(app).toContain('onClick={() => setNotifyPrompt("bell")}');
  expect(app).not.toContain("Notification.requestPermission()");
  expect(prompt).toContain("await subscribeToPushNotifications(client, userId);");
  expect(prompt).toContain("isCurrentDevicePushEnabled(client, userId)");
  // Never on top of the new-order alert or another sheet; "later" lasts one session.
  expect(app).toContain("{notifyPrompt && store && !alertOrder && !selectedOrder && !menuDraft && !storeEditing ? (");
  expect(prompt).toContain("window.sessionStorage.setItem(LATER_KEY, \"1\")");
});

test("WYN-200 Merchant order alert uses Wynos's own generated sound", () => {
  const alert = read("components/merchant/merchant-order-alert.tsx");
  const generator = read("scripts/generate-merchant-order-sound.py");
  const app = read("components/merchant/wynos-merchant-app.tsx");

  // The sound is synthesized by a script in the repo (no third-party audio)
  // and the committed file exists.
  expect(generator).toContain("synthesized from scratch");
  expect(readFileSync(join(process.cwd(), "public/sounds/wynos-merchant-order.wav")).subarray(0, 4).toString()).toBe("RIFF");
  expect(alert).toContain('export const MERCHANT_ORDER_SOUND_URL = "/sounds/wynos-merchant-order.wav";');
  // Falls back to synthesized tones if the file cannot load, and can be previewed.
  expect(alert).toContain("playFallbackTones(context);");
  expect(app).toContain("previewMerchantOrderSound()");
});

test("WYN-201 Merchant and Food lists refresh with a pull-down gesture", () => {
  const merchant = read("components/merchant/wynos-merchant-app.tsx");
  const food = read("components/food/wynos-food-developer-app.tsx");

  // The shared hook (same feel as the social app); lists only, never forms.
  expect(merchant).toContain('enabled: tab === "home" || tab === "orders" || tab === "menu" || tab === "reports" || tab === "finance",');
  expect(merchant).toContain('<section className="wm-content" onTouchStart={pull.onTouchStart}');
  expect(food).toContain('usePullToRefresh({ enabled: tab === "home" || tab === "orders"');
  expect(food).toContain('<section className="wf-content" onTouchStart={pull.onTouchStart}');
  expect(read("lib/use-pull-to-refresh.ts")).toContain('[role="dialog"]');
});

test("WYN-203 WYNOS Admin can suspend a store and see cross-store orders", () => {
  const migration = read("../supabase/migrations_wynos_admin_food_ops_v1.sql");
  const merchant = read("components/merchant/wynos-merchant-app.tsx");
  const data = read("lib/food-merchant.ts");

  // Suspension is enforced in the database, not only hidden in the UI.
  expect(migration).toContain("create trigger food_stores_guard_suspension");
  expect(migration).toContain("create trigger food_orders_block_suspended_store");
  expect(migration).toContain("raise exception 'store is not accepting orders'");
  // Customer data and evidence are admin only, and every order view is audited.
  expect(migration).toContain("'admin_food_order_viewed'");
  expect(migration).toContain("revoke all on function public.admin_food_order_detail(uuid) from public, anon;");
  // The store team sees why, and cannot reopen or publish while suspended.
  expect(merchant).toContain("ร้านถูกระงับโดยทีม WYNOS");
  expect(merchant).toContain("disabled={busy || Boolean(store.admin_suspended_at)} onClick={() => void toggleOpen()}");
  expect(data).toContain('if (message.includes("store is suspended"))');
});

test("WYN-204 Merchant home is a simple Wynos layout with four tabs and 3D shortcuts", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const css = read("app/merchant/merchant.css");
  const icons = read("components/merchant/merchant-3d-icons.tsx");

  // One red "today" card: store, sales (opens reports) and the open switch.
  expect(app).toContain('<section className="wm-hero">');
  expect(app).toContain('<button className="wm-hero-sales" type="button" onClick={() => onOpenTab("reports")}>');
  expect(app).toContain('className={`wm-open-switch ${store.is_open ? "is-open" : ""}`}');
  expect(app).toContain('role="switch"');
  // One row of Wynos's own 3D icons (SVG, no third-party artwork). WYN-205:
  // the Founder picked การเงิน · โฆษณา · แคมเปญ · โปรโมชั่น for this row.
  expect(icons).toContain("export function MerchantIcon3D({ name, size = 44 }");
  expect(icons).toContain('settings: (p) => (');
  expect(icons).toContain('help: (p) => (');
  for (const shortcut of ['name="finance" size={52} />การเงิน', 'name="ads" size={52} />โฆษณา', 'name="campaign" size={52} />แคมเปญ', 'name="promotion" size={52} />โปรโมชั่น']) {
    expect(app).toContain(shortcut);
  }
  // The nav badge counts every unfinished order. Founder removed the
  // "ต้องจัดการตอนนี้" list from home; orders live in "รับออเดอร์".
  expect(app).toContain("badge={activeOrderCount}");
  expect(app).not.toContain("<h2>ต้องจัดการตอนนี้</h2>");
  // Readiness uses the publish rules (paired payment fields).
  expect(app).toContain("done: (filled(store.promptpay_name) && filled(store.promptpay_id)) || (filled(store.bank_account_name) && filled(store.bank_account_number)) || filled(store.payment_qr_path)");
  expect(app).toContain("{nextStep && !store.admin_suspended_at ? (");
  // Four bottom tabs; reports, store settings and campaigns live under "เพิ่มเติม".
  expect(app).toContain('label="รับออเดอร์"');
  expect(app).toContain('<NavButton active={MORE_PAGES.has(tab)} label="เพิ่มเติม"');
  expect(app).not.toContain('label="รายงาน"');
  // WYN-208: Wynos's own bottom-bar icons, outline when idle and solid red when selected.
  expect(app).toContain('icon={<MerchantNavIcon name="orders" active={tab === "orders"} />}');
  expect(app).toContain('icon={<MerchantNavIcon name="more" active={MORE_PAGES.has(tab)} />}');
  const navIcons = read("components/merchant/merchant-nav-icons.tsx");
  expect(navIcons).toContain('const fill = active ? RED : "none";');
  expect(navIcons).toContain('const RED = "#e32636";');
  expect(css).toContain(".wm-nav-icon > svg.wm-nav-svg { width: 26px; height: 26px; stroke-width: initial; }");
  expect(css).toContain("grid-template-columns: repeat(4, minmax(0, 1fr));\n}\n.wm-nav > button {");
  // Light only: the layout pins light tokens whatever the phone or WYN theme says.
  const layout = read("app/merchant/layout.tsx");
  expect(layout).toContain('return <div className="wm-force-light">{children}</div>;');
  expect(layout).toContain('colorScheme: "light",');
  expect(css).toContain("html:has(.wm-force-light) body { background: #ffffff; color-scheme: light; }");
  expect(css).not.toContain("prefers-color-scheme: dark");
  expect(css).not.toContain("var(--wyn-");
});

test("WYN-205 Merchant finance page and the store's own promotions", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");

  // WYN-210 replaced the order-based finance panel (opened to every store by the Founder).
  const finance = read("components/merchant/merchant-finance.tsx");
  expect(app).not.toContain("function FinancePanel(");
  // Payment channels are still masked to the last 4 digits.
  expect(finance).toContain("const last4 = (value: string | null) => {");
  expect(finance).toContain('const digits = (value ?? "").replace(/\\D/g, "");');
  // Dynamic promotion text is translated through EN_PATTERNS.
  const en = read("lib/i18n/en.ts");
  expect(en).toContain('["{0} โปรโมชั่นกำลังใช้งาน", "{0} active promotions"]');
  expect(en).toContain('["โปรโมชั่น · {0}", "Promotion · {0}"]');
  // The existing discount system is "โปรโมชั่น"; WYNOS campaigns (WYN-206)
  // and ads (WYN-207) have their own pages.
  expect(app).toContain('{tab === "promotions" && store ? (');
  expect(app).toContain("<MerchantCampaignCenter client={client} store={store} menu={menu} onMessage={setMessage} />");
  expect(app).not.toContain("ComingSoonPanel");
});

test("WYN-206 WYNOS campaigns: Admin designs, stores join, hybrid funding is shown before joining", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const page = read("components/merchant/merchant-platform-campaigns.tsx");
  const migration = read("../supabase/migrations_wynos_platform_campaigns_v1.sql");
  const food = read("components/food/wynos-food-developer-app.tsx");

  // Joined stores reuse the existing server pricing; WYNOS's share is snapshot per order.
  expect(migration).toContain("platform_share_percent numeric(5,2) not null default 0");
  expect(migration).toContain("create trigger food_order_campaigns_platform_share");
  expect(migration).toContain("create trigger food_campaigns_platform_guard");
  expect(migration).toContain("raise exception 'nothing to settle'");
  // The store sees who pays what before it joins, and what WYNOS owes it.
  expect(app).toContain("<MerchantPlatformCampaigns client={client} store={store} onMessage={setMessage} />");
  expect(page).toContain("`ทุกออเดอร์ที่ใช้แคมเปญนี้ WYNOS ออกส่วนลดให้ ${Number(confirming.platform_share_percent)}% ร้านออก ${100 - Number(confirming.platform_share_percent)}%`");
  expect(page).toContain("WYNOS จะโอนคืนร้าน");
  // Customers see the campaign on the store.
  expect(food).toContain("{`แคมเปญ WYNOS · ${name}`}");
});

test("WYN-205 Wynos red leads on every Merchant page", () => {
  const css = read("app/merchant/merchant.css");
  // Primary buttons and summary cards are red, not black.
  expect(css).toMatch(/\.wm-primary \{[^}]*background: var\(--wm-red\);[^}]*color: #fff;/);
  expect(css).toMatch(/\.wm-small-primary \{[^}]*background: var\(--wm-red\);/);
  expect(css).toMatch(/\.wm-report-hero \{[^}]*background: linear-gradient\(150deg, #ff4d5e 0%, #e32636 55%, #b8142a 100%\);/);
  // No rainbow colours in the page styling (Founder: "ถ้ามีสีรุ้ง ตัดทิ้งเลย").
  // The 3D icons keep their own colours so each one is easy to tell apart
  // (Founder: "พวกไอคอน ไม่ต้องคุมโทนแดง หมดก็ได้ เดียว งง").
  for (const colour of ["#ffa31a", "#22b45e", "#2f8cf0", "#8a5cf6"]) {
    expect(css).not.toContain(colour);
  }
});

test("WYN-207 pay-per-click ads: Admin-controlled, charged on the server, labelled in Food", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const ads = read("components/merchant/merchant-ads.tsx");
  const data = read("lib/merchant-ads.ts");
  const food = read("components/food/wynos-food-developer-app.tsx");
  const migration = read("../supabase/migrations_wynos_food_ads_v1.sql");

  // Server decides every charge: once per customer per store per day, never the store's own team.
  expect(migration).toContain("constraint food_ad_clicks_once_per_day unique (store_id, viewer_id, click_day)");
  expect(migration).toContain("return 'own_store';");
  expect(migration).toContain("ads_enabled boolean not null default false");
  // Slips go to the store's own private folder and Admin approves the credit.
  expect(data).toContain("uploadFoodPrivateImage(client, slip, `ads/${storeId}`)");
  expect(app).toContain("<MerchantAds client={client} store={store} onMessage={setMessage} />");
  expect(ads).toContain("ส่งสลิปให้ WYNOS ตรวจ");
  // Food: ads first, always labelled; opening one reports the click.
  expect(food).toContain('{store.is_ad ? <b className="wf-ad-label">โฆษณา</b> : null}');
  expect(food).toContain("if (next.is_ad) void recordFoodAdClick(client, next.id, placement)");
});

test("WYN-209 Merchant app icon: complete PNGs at every size, separate maskable art", () => {
  const layout = read("app/merchant/layout.tsx");
  const manifest = read("app/merchant/manifest.ts");
  expect(layout).toContain('const MERCHANT_ICON_180 = "/icons/merchant/v15-180.png";');
  expect(manifest).toContain('{ src: "/icons/merchant/v15-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" }');
  // v14-512 shipped truncated; every published icon must be a whole PNG of the stated size.
  for (const [file, size] of [["v15-180", 180], ["v15-192", 192], ["v15-512", 512], ["v15-maskable-512", 512]] as const) {
    const png = readFileSync(join(process.cwd(), `public/icons/merchant/${file}.png`));
    expect(png.subarray(1, 4).toString("latin1")).toBe("PNG");
    expect(png.readUInt32BE(16)).toBe(size);
    expect(png.readUInt32BE(20)).toBe(size);
    expect(png.subarray(png.length - 8, png.length - 4).toString("latin1")).toBe("IEND");
  }
});

test("WYN-210 finance: any period, net sales and income worked out on the server", () => {
  const app = read("components/merchant/wynos-merchant-app.tsx");
  const page = read("components/merchant/merchant-finance.tsx");
  const lib = read("lib/merchant-finance.ts");
  const migration = read("../supabase/migrations_wynos_merchant_finance_v1.sql");
  const workflow = read("../.github/workflows/food-apply-wyn210.yml");

  // Periods: today, yesterday, this week, this month, or a calendar range.
  expect(page).toContain('{ id: "yesterday", label: "เมื่อวาน" },');
  expect(page).toContain('onPick={(next) => { setPicking(false); setPeriod("custom"); setSummary(null); setRange(next); }}');
  expect(page).toContain("disabled={day > today}");
  expect(lib).toContain('return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Bangkok"');
  // Two headline numbers, each with the lines that make it up.
  expect(page).toContain("<small>ยอดขายสุทธิ</small><strong>{money(current.sales_net)}</strong>");
  expect(page).toContain("<small>รายได้ร้าน</small><strong>{money(current.income)}</strong>");
  // The WYNOS line only shows when there is money, with the plain-language name.
  expect(page).toContain("{current.platform_owed > 0 ? (");
  expect(page).toContain("<strong>เงินที่ WYNOS จะโอนให้ร้าน</strong>");
  // Numbers from an older range are never shown for the new one.
  expect(page).toContain("const current = summary && summary.from === range.from && summary.to === range.to ? summary : null;");
  // Founder "เปิดทุกคน": every store gets the new finance page (staged rollout ended).
  expect(app).toContain('{tab === "finance" && store ? <MerchantFinance client={client} store={store} refreshKey={orders}');
  expect(app).not.toContain("<FinancePanel");
  // The calendar sheet takes focus, closes on Escape and keeps Tab inside.
  expect(page).toContain('<section ref={sheetRef} tabIndex={-1} className="wm-sheet" role="dialog" aria-modal="true"');
  expect(page).toContain('if (event.key === "Escape") { event.preventDefault(); closeRef.current(); return; }');
  expect(page).toContain("return () => {\n      document.removeEventListener(\"keydown\", onKey);\n      if (opener?.isConnected) opener.focus();");
  // Pull to refresh still reloads the finance page.
  expect(app).toContain("refreshKey={orders}");
  // CSV opens in Excel with Thai (UTF-8 BOM) and carries a total row.
  expect(lib).toContain("return `\\uFEFF${");
  // Server: manager roles only, read only, Bangkok days, bounded range.
  // Not merchant_has_store_role(): it lets developers into any store and ignores legacy staff roles.
  expect(migration).toContain("and mm.role in ('owner', 'admin', 'manager')");
  expect(migration).toContain("and fs.role = 'owner'");
  expect(migration).not.toContain("merchant_has_store_role(p_store_id");
  expect(migration).toContain("paid_total - refunds - ad_spend + platform_funded as income");
  expect(migration).toContain("if v_days > 366 then");
  expect(migration).toContain("revoke all on function public.merchant_finance_summary(uuid, date, date) from public, anon;");
  expect(workflow).toContain("github.event.inputs.confirm == 'APPLY-WYN-210'");
});

test("WYN-213 merchant access hardening: no developer cross-store access, legacy roles, safe payouts", () => {
  const sql = read("../supabase/migrations_wynos_merchant_access_hardening_v1.sql");
  const adminActions = read("../admin/lib/admin-food-actions.ts");
  const settleButton = read("../admin/components/admin/platform-campaign-actions.tsx");
  const workflow = read("../.github/workflows/food-apply-wyn213.yml");

  // Helpers no longer let developer accounts into every store.
  expect(sql).not.toContain("from public.developer_accounts");
  // Legacy food_staff rows count by their real role.
  expect(sql).toContain("(case fs.role when 'owner' then 'owner' when 'staff' then 'orders' when 'delivery' then 'delivery' end) = any(p_roles)");
  // WYNOS owes only paid orders from real customers.
  expect(sql).toContain("and o.payment_status = 'paid'");
  expect(sql).toContain("where mm.merchant_account_id = s.merchant_account_id and mm.user_id = o.buyer_id");
  // Payouts must match what the admin saw; one slip, one top-up.
  expect(sql).toContain("raise exception 'owed amount changed, reload and check before recording';");
  expect(sql).toContain("drop function if exists public.admin_settle_platform_store(uuid, text, text);");
  expect(sql).toContain("create unique index if not exists food_ad_topups_slip_path_uidx on public.food_ad_topups(slip_path);");
  expect(adminActions).toContain("p_expected_amount: params.expectedAmount,");
  expect(settleButton).toContain("expectedAmount: owedAmount, expectedCount: owedOrders");
  expect(workflow).toContain("github.event.inputs.confirm == 'APPLY-WYN-213'");
});

test("WYN-214 Admin merchant polish: service area, order money, refunds, safe approvals", () => {
  const sql = read("../supabase/migrations_wynos_admin_merchant_polish_v1.sql");
  const store = read("../admin/app/(admin)/food/stores/[id]/page.tsx");
  const orders = read("../admin/app/(admin)/food/orders/page.tsx");
  const order = read("../admin/app/(admin)/food/orders/[id]/page.tsx");
  const card = read("../admin/components/admin/merchant-review-card.tsx");

  expect(sql).toContain("'in_service_area', internal.food_in_service_area(v_store.latitude, v_store.longitude),");
  expect(sql).toContain("or (p_status = 'refund_pending' and o.refund_status in ('pending', 'failed'))");
  expect(store).toContain('{store.in_service_area ? "อยู่ในเขตมหาสารคาม" : "อยู่นอกเขต / ยังไม่ปักหมุด"}');
  expect(orders).toContain('{ value: "refund_pending", label: "รอคืนเงิน" },');
  expect(orders).toContain("orders.length >= ORDER_LIMIT");
  // The breakdown now adds up: discounts are shown.
  expect(order).toContain("Number(order.campaign_discount ?? 0) > 0");
  // Approval is final: confirm first, errors in Thai.
  expect(card).toContain("if (!window.confirm(`${what}? อนุมัติแล้วย้อนกลับไม่ได้`)) return;");
  expect(card).toContain('return "คำขอนี้อนุมัติไปแล้ว เปลี่ยนไม่ได้";');
});
