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

  // Four tabs in working order; search and filters are tucked away.
  expect(app).toContain('type OrderFilter = "new" | "cooking" | "delivery" | "done";');
  expect(app).toContain('useState<OrderFilter>("new")');
  expect(app).toContain("{showTools ? <div className=\"wm-order-search-tools\">");

  // The card runs simple steps; the slip and the delivery photo still need the order open.
  expect(app).toContain('if (next.step === "check_slip" || next.step === "deliver") {');
  expect(app).toContain('await transitionFoodOrder(client, order.id, "preparing", order.eta_minutes ?? 30);');

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
  expect(merchant).toContain('enabled: tab === "home" || tab === "orders" || tab === "menu" || tab === "reports",');
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
  // One row of Wynos's own 3D icons (SVG, no third-party artwork); the
  // orders badge counts every unfinished order, not the 8 previewed.
  expect(icons).toContain("export function MerchantIcon3D({ name, size = 44 }");
  expect(app).toContain('<MerchantIcon3D name="orders" size={52} />รอจัดการ');
  expect(app).toContain('{activeOrderCount ? <b className="wm-shortcut-badge">{activeOrderCount}</b> : null}');
  // Readiness uses the publish rules (paired payment fields).
  expect(app).toContain("done: (filled(store.promptpay_name) && filled(store.promptpay_id)) || (filled(store.bank_account_name) && filled(store.bank_account_number)) || filled(store.payment_qr_path)");
  expect(app).toContain("{nextStep && !store.admin_suspended_at ? (");
  // Four bottom tabs; reports, store settings and campaigns live under "เพิ่มเติม".
  expect(app).toContain('label="รับออเดอร์"');
  expect(app).toContain('<NavButton active={MORE_PAGES.has(tab)} label="เพิ่มเติม"');
  expect(app).not.toContain('label="รายงาน"');
  expect(css).toContain("grid-template-columns: repeat(4, minmax(0, 1fr));\n}\n.wm-nav > button {");
});
