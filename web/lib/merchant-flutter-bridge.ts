import { FulfillmentError, transitionPickupOrder, setStoreFulfillment, resolveCancelRequest, markStoreRefunded, uploadRefundSlip } from "@/lib/food-fulfillment-merchant";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  completeFoodDelivery, fetchMerchantSalesReport, foodPrivateSignedUrl, foodPublicUrl,
  setFoodPaymentStatus, subscribeMerchantOrders, transitionFoodOrder, updateFoodStore,
  uploadFoodPrivateImage, uploadFoodPublicImage, type FoodMenuItem, type FoodOrder, type FoodStore,
} from "@/lib/food-merchant";
import { orderDeliveryProof } from "@/lib/food-delivery-proof";
import { FOOD_DAY_KEYS, foodStoreIsEffectivelyOpen, foodStoreStatusText, type FoodBusinessSchedule } from "@/lib/food-store-availability";
import { addMerchantStaff, fetchMerchantStaff, fetchMerchantStoreReviews, updateMerchantStaff } from "@/lib/merchant-core";
import { fetchFinanceSummary, periodRange } from "@/lib/merchant-finance";
import { fetchMerchantAdAccount, merchantAdError, requestAdTopup, setAdActive } from "@/lib/merchant-ads";
import { fetchPlatformCampaigns, joinPlatformCampaign, leavePlatformCampaign, platformCampaignError } from "@/lib/merchant-platform-campaigns";
import { fetchMerchantCampaigns, saveMerchantCampaign, setMerchantCampaignActive } from "@/lib/merchant-campaigns";
import { getPushAvailability, requestPushPermissionFromGesture, hasActivePushSubscription, pushReasonDescription, subscribeToPushNotifications, unsubscribeFromPushNotifications } from "@/lib/push-notifications";

// DeveloperRouteGate remains the sole auth owner. Credentials never cross Dart.
// Every operation still uses existing RPCs and row/storage authorization.
export type MerchantFlutterBridge = { request: (method: string, payloadJson: string) => Promise<string>; dispose: () => void };
type BridgeOptions = { client: SupabaseClient; userId: string; signOut: () => Promise<void>; onOrderChange?: () => void };
type Args = Record<string, unknown>;
class BridgeInputError extends Error {}
class BridgeAccessError extends Error {}
/** A message already written for merchants by an existing helper. */
class BridgeMessageError extends Error {}
/** Keeps only the helper's own Thai messages; raw server text stays generic. */
async function friendly<T>(operation: () => Promise<T>, explain: (error: unknown) => string): Promise<T> {
  try { return await operation(); }
  catch (error) {
    const raw = error && typeof error === "object" && "message" in error ? String(error.message) : String(error ?? "");
    const message = explain(error);
    throw message && message !== raw && message !== "ดำเนินการไม่สำเร็จ" ? new BridgeMessageError(message) : error;
  }
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUSES = new Set(["pending_acceptance", "preparing", "ready_for_delivery", "out_for_delivery", "delivered", "cancelled"]);
const ROLES = new Set(["owner", "admin", "manager", "orders", "support", "delivery"]);
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
function object(value: unknown): Args {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new BridgeInputError();
  return value as Args;
}
function id(value: unknown): string {
  if (typeof value !== "string" || !UUID.test(value)) throw new BridgeInputError();
  return value;
}
function text(value: unknown, max: number, required = false): string {
  if (value == null && !required) return "";
  if (typeof value !== "string" || value.length > max || (required && !value.trim())) throw new BridgeInputError();
  return value.trim();
}
/** Baht, up to 2 decimals; the server still applies the minimum top-up. */
function topupAmount(value: unknown): number {
  // Compare in satang with a tolerance: 150.05 * 100 is 15005.000000000002 in floating point.
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0 || value > 100_000 || Math.abs(value * 100 - Math.round(value * 100)) > 1e-6) throw new BridgeInputError();
  return value;
}
function bool(value: unknown): boolean {
  if (typeof value !== "boolean") throw new BridgeInputError();
  return value;
}
function amount(value: unknown, max: number): number {
  if (typeof value !== "number" && typeof value !== "string") throw new BridgeInputError();
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > max) throw new BridgeInputError();
  return n;
}
const STAFF_ROLES = new Set(["admin", "manager", "orders", "support", "delivery"]);
const USERNAME = /^@?[A-Za-z0-9_.]{2,40}$/;
const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
/** Optional text column: blank clears it (null), like the legacy store form. */
function optionalText(value: unknown, max: number): string | null {
  return text(value, max) || null;
}
/** Digits only after removing spaces and dashes; blank clears the column. */
function digits(value: unknown, min: number, max: number): string | null {
  const raw = text(value, 40).replace(/[\s-]/g, "");
  if (!raw) return null;
  if (!/^\d+$/.test(raw) || raw.length < min || raw.length > max) throw new BridgeInputError();
  return raw;
}
function schedule(value: unknown): FoodBusinessSchedule {
  const weekly = object(object(value).weekly);
  if (Object.keys(weekly).length !== FOOD_DAY_KEYS.length) throw new BridgeInputError();
  return {
    weekly: Object.fromEntries(FOOD_DAY_KEYS.map((key) => {
      const day = object(weekly[key]);
      if (typeof day.open !== "string" || typeof day.close !== "string" || !TIME.test(day.open) || !TIME.test(day.close)) throw new BridgeInputError();
      return [key, { enabled: bool(day.enabled), open: day.open, close: day.close }];
    })),
  };
}
function closedDates(value: unknown): string[] {
  if (!Array.isArray(value) || value.length > 60) throw new BridgeInputError();
  const dates = value.map((date) => {
    if (typeof date !== "string" || !DATE.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))) throw new BridgeInputError();
    return date;
  });
  return [...new Set(dates)].sort();
}
/** Read-back check; jsonb columns come back with their keys reordered. */
function sameValue(actual: unknown, expected: unknown): boolean {
  if (actual === expected) return true;
  if (!actual || !expected || typeof actual !== "object" || typeof expected !== "object") return false;
  if (Array.isArray(actual) !== Array.isArray(expected)) return false;
  const a = actual as Args, e = expected as Args;
  const keys = Object.keys(e);
  return keys.length === Object.keys(a).length && keys.every((key) => sameValue(a[key], e[key]));
}
function safeError(error: unknown): string {
  if (error instanceof FulfillmentError || error instanceof BridgeMessageError) return error.message;
  if (error instanceof BridgeInputError) return "ข้อมูลไม่ถูกต้อง กรุณาตรวจสอบแล้วลองใหม่";
  if (error instanceof BridgeAccessError) return "บัญชีนี้ไม่มีสิทธิ์เข้าถึงร้านหรือออเดอร์นี้ กรุณาเข้าสู่ระบบใหม่";
  const message = error && typeof error === "object" && "message" in error ? String(error.message) : "";
  if (message.includes("payment must be verified")) return "ต้องยืนยันเงินเข้าก่อนรับออเดอร์";
  if (message.includes("stripe payment status")) return "รายการนี้ชำระผ่านระบบอัตโนมัติ กรุณารอสถานะจากผู้ให้บริการ";
  if (message.includes("invalid order transition") || message.includes("not out for delivery")) return "สถานะออเดอร์เปลี่ยนไปแล้ว กรุณารีเฟรชก่อนลองใหม่";
  if (message.includes("delivery photo is required")) return "กรุณาแนบรูปหลักฐานการจัดส่งของออเดอร์นี้";
  if (message.includes("dropoff location is required")) return "กรุณาระบุจุดวางอาหาร";
  if (message.includes("role required") || message.includes("merchant access") || message.includes("permission denied") || message.includes("row-level security")) return "บัญชีนี้ไม่มีสิทธิ์ดำเนินการ กรุณาตรวจสอบกับเจ้าของร้าน";
  if (message.includes("store is suspended")) return "ร้านถูกระงับ กรุณาติดต่อทีม WYNOS";
  if (message.includes("WYNOS user not found")) return "ไม่พบบัญชีนี้ กรุณาตรวจ @username อีกครั้ง";
  if (message.includes("owner role cannot be changed")) return "เปลี่ยนสิทธิ์เจ้าของร้านไม่ได้";
  if (message.includes("staff member not found")) return "ไม่พบทีมงานคนนี้ กรุณารีเฟรช";
  if (message.includes("billing owner/admin access required")) return "เฉพาะเจ้าของร้านและแอดมินร้านที่จัดการค่าบริการได้";
  if (message.includes("invoice is not waiting for payment")) return "ใบแจ้งหนี้นี้ไม่ได้รอชำระแล้ว กรุณารีเฟรช";
  if (message.includes("own staff access")) return "เปลี่ยนสิทธิ์ของตัวเองไม่ได้ ให้เจ้าของร้านหรือแอดมินคนอื่นเปลี่ยนให้";
  return "เชื่อมต่อหรือบันทึกไม่สำเร็จ กรุณารีเฟรชข้อมูลก่อนลองอีกครั้ง";
}
function pickImage(): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file"; input.accept = "image/jpeg,image/png,image/webp"; input.style.display = "none";
    document.body.appendChild(input);
    let settled = false;
    const finish = (file: File | null) => {
      if (settled) return;
      settled = true; input.remove(); window.removeEventListener("focus", onFocus); resolve(file);
    };
    const onFocus = () => { window.setTimeout(() => { if (!input.files?.length) finish(null); }, 500); };
    input.addEventListener("change", () => finish(input.files?.[0] ?? null), { once: true });
    input.addEventListener("cancel", () => finish(null), { once: true });
    window.addEventListener("focus", onFocus, { once: true });
    input.click();
  });
}
async function validateImage(file: File): Promise<void> {
  if (!file.size || file.size > MAX_IMAGE_BYTES) throw new BridgeInputError();
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const png = [137, 80, 78, 71, 13, 10, 26, 10].every((v, i) => bytes[i] === v);
  const webp = [82, 73, 70, 70].every((v, i) => bytes[i] === v) && [87, 69, 66, 80].every((v, i) => bytes[i + 8] === v);
  if (!((file.type === "image/jpeg" && jpeg) || (file.type === "image/png" && png) || (file.type === "image/webp" && webp))) throw new BridgeInputError();
  if (typeof createImageBitmap === "function") {
    const decoded = await createImageBitmap(file);
    try { if (!decoded.width || !decoded.height || decoded.width * decoded.height > 40_000_000) throw new BridgeInputError(); }
    finally { decoded.close(); }
  } else {
    const url = URL.createObjectURL(file);
    try {
      const image = new Image(); image.src = url; await image.decode();
      if (!image.naturalWidth || !image.naturalHeight || image.naturalWidth * image.naturalHeight > 40_000_000) throw new BridgeInputError();
    } finally { URL.revokeObjectURL(url); }
  }
}
export function createMerchantFlutterBridge({ client, userId, signOut, onOrderChange }: BridgeOptions): MerchantFlutterBridge {
  let disposed = false;
  type PhotoSelection = { storeId: string; orderId: string; file: File; kind?: "refund"; previewUrl: string; uploadedPath?: string; completing?: Promise<void> };
  const photos = new Map<string, PhotoSelection>();
  const releasePhoto = (path: string) => {
    const selection = photos.get(path);
    if (selection) { URL.revokeObjectURL(selection.previewUrl); photos.delete(path); }
  };
  let subscription: ReturnType<typeof subscribeMerchantOrders> | null = null;
  const ensureSession = async () => {
    if (disposed) throw new BridgeAccessError();
    const { data, error } = await client.auth.getSession();
    if (error || data.session?.user.id !== userId || data.session.user.is_anonymous || disposed) throw new BridgeAccessError();
  };
  const storeAccess = async (storeId: string) => {
    const { data, error } = await client.rpc("food_has_merchant_access", { p_store_id: storeId });
    if (error || data !== true) throw new BridgeAccessError();
  };
  const requireManageRole = async (storeId: string) => {
    const { data, error } = await client.rpc("merchant_has_store_role", { p_store_id: storeId, p_roles: ["owner", "admin", "manager"] });
    if (error || data !== true) throw new BridgeAccessError();
    await ensureSession();
  };
  // Same gate as merchant_add_staff_by_username / merchant_update_staff_member.
  const requireStaffAdmin = async (storeId: string) => {
    const { data, error } = await client.rpc("merchant_has_store_role", { p_store_id: storeId, p_roles: ["owner", "admin"] });
    if (error || data !== true) throw new BridgeAccessError();
    await ensureSession();
  };
  const verifyPatch = (row: unknown, patch: Args) => {
    const data = object(row);
    for (const [key, expected] of Object.entries(patch)) {
      const actual = key === "price" ? Number(data[key]) : data[key];
      if (!sameValue(actual, expected)) throw new Error("write_not_applied");
    }
  };
  const ownedOrder = async (storeId: string, orderId: string): Promise<FoodOrder> => {
    const { data, error } = await client.from("food_orders").select("*,food_delivery_proofs(*)").eq("store_id", storeId).eq("id", orderId).single();
    if (error || !data) throw new BridgeAccessError();
    return data as FoodOrder;
  };
  const listStores = async () => {
    // Read this user's indexed grants first. Public catalog visibility must not
    // turn each merchant refresh into a catalog scan plus one RPC per store.
    const grants = async (table: "merchant_memberships" | "food_staff", column: string) => {
      const values = new Set<string>();
      for (let offset = 0; ; offset += 500) {
        const { data, error } = await client.from(table).select(column).eq("user_id", userId).eq("active", true).order(column).range(offset, offset + 499);
        if (error) throw error;
        const rows = (data ?? []) as unknown as Args[];
        rows.forEach((row) => values.add(id(row[column])));
        if (rows.length < 500) break;
      }
      return [...values];
    };
    const [accounts, staffStores] = await Promise.all([grants("merchant_memberships", "merchant_account_id"), grants("food_staff", "store_id")]);
    await ensureSession();
    const stores = new Map<string, FoodStore>();
    for (const [column, values] of [["merchant_account_id", accounts], ["id", staffStores]] as const) {
      for (let batch = 0; batch < values.length; batch += 100) {
        for (let offset = 0; ; offset += 500) {
          const { data, error } = await client.from("food_stores").select("*").in(column, values.slice(batch, batch + 100)).order("created_at").order("id").range(offset, offset + 499);
          if (error) throw error;
          const rows = (data ?? []) as FoodStore[];
          rows.forEach((store) => stores.set(store.id, store));
          if (rows.length < 500) break;
        }
      }
    }
    const at = new Date();
    return [...stores.values()]
      .sort((a, b) => (a.created_at ?? "").localeCompare(b.created_at ?? "") || a.id.localeCompare(b.id))
      .map((store) => {
        const suspended = Boolean(store.admin_suspended_at);
        const unpublished = store.is_published !== true;
        return {
          ...store,
          image_url: foodPublicUrl(client, store.logo_path),
          payment_qr_url: foodPublicUrl(client, store.payment_qr_path),
          effective_open: !suspended && !unpublished && foodStoreIsEffectivelyOpen(store, at),
          status_text: suspended ? "ร้านถูกระงับ กรุณาติดต่อทีม WYNOS"
            : unpublished ? "ร้านยังไม่เผยแพร่" : foodStoreStatusText(store, at),
        };
      });
  };
  const execute = async (method: string, args: Args, picked: Promise<File | null> | null, permissionRequest?: Promise<NotificationPermission>): Promise<unknown> => {
    await ensureSession();
    if (method === "signOut") { await signOut(); return null; }
    if (method === "stores") return listStores();
    if (method === "pushStatus") return { enabled: await hasActivePushSubscription() === true, permission: typeof Notification === "undefined" ? "unsupported" : Notification.permission, ...(await getPushAvailability()) };
    if (method === "pushEnable") {
      const result = await subscribeToPushNotifications(client, userId, { permissionRequest, ensureActive: ensureSession });
      return result.ok ? { ok: true, enabled: true } : { ok: false, enabled: false, reason: result.reason, message: pushReasonDescription(result.reason) };
    }
    if (method === "pushDisable") {
      if (!await unsubscribeFromPushNotifications(client)) throw new Error("unsubscribe_failed");
      return { ok: true, enabled: false };
    }
    if (method === "requestedOrder") {
      const order = text(args.orderId, 80, true);
      const query = client.from("food_orders").select("id,store_id,status");
      const { data, error } = await query.eq(UUID.test(order) ? "id" : "order_number", order).maybeSingle();
      if (error) throw error;
      if (!data) return null;
      const grant = await client.rpc("food_has_merchant_access", { p_store_id: data.store_id });
      if (grant.error) throw grant.error;
      return grant.data === true ? { id: data.id, storeId: data.store_id, status: data.status } : null;
    }
    const storeId = id(args.storeId);
    await storeAccess(storeId);
    await ensureSession();
    switch (method) {
      case "setFulfillment": {
        const values = object(args.values);
        const { data, error } = await client.rpc("merchant_has_store_role", { p_store_id: storeId, p_roles: ["owner", "admin"] });
        if (error || data !== true) throw new BridgeAccessError();
        await ensureSession();
        await setStoreFulfillment(client, storeId, { pickup: bool(values.pickup), delivery: bool(values.delivery), cod: bool(values.cod), prepMinutes: Number(values.prepMinutes) });
        return null;
      }
      case "resolveCancel": {
        const orderId = id(args.orderId);
        await ownedOrder(storeId, orderId);
        await ensureSession();
        await resolveCancelRequest(client, orderId, bool(args.approve), bool(args.refund), text(args.note, 1000));
        return null;
      }
      case "markRefunded": {
        const orderId = id(args.orderId), handle = text(args.imagePath, 250, true);
        const selection = photos.get(handle);
        if (!selection || selection.kind !== "refund" || selection.storeId !== storeId || selection.orderId !== orderId || selection.completing) throw new BridgeInputError();
        const operation = async () => {
          const order = await ownedOrder(storeId, orderId);
          if (selection.uploadedPath && order.refund_status === "refunded" && order.refund_slip_path === selection.uploadedPath) return;
          if (order.payment_provider === "stripe" || order.payment_method === "cod" || order.refund_status !== "pending") throw new BridgeInputError();
          await requireManageRole(storeId);
          selection.uploadedPath ??= await uploadRefundSlip(client, storeId, orderId, selection.file);
          await ensureSession();
          await markStoreRefunded(client, storeId, orderId, selection.uploadedPath, text(args.note, 1000));
        };
        selection.completing = operation();
        try { await selection.completing; releasePhoto(handle); }
        finally { selection.completing = undefined; }
        return null;
      }
      case "hasRole": {
        if (!Array.isArray(args.roles) || args.roles.length > 6 || !args.roles.every((r) => typeof r === "string" && ROLES.has(r))) throw new BridgeInputError();
        const { data, error } = await client.rpc("merchant_has_store_role", { p_store_id: storeId, p_roles: args.roles });
        if (error) throw error;
        return data === true;
      }
      case "menu": {
        const all: FoodMenuItem[] = [];
        for (let offset = 0; ; offset += 500) {
          const { data, error } = await client.from("food_menu_items").select("*").eq("store_id", storeId).order("sort_order").order("id").range(offset, offset + 499);
          if (error) throw error;
          const rows = (data ?? []) as FoodMenuItem[]; all.push(...rows);
          if (rows.length < 500) break;
        }
        return all.map((item) => ({ ...item, image_url: foodPublicUrl(client, item.image_path) }));
      }
      case "orders": {
        const status = text(args.status, 30, true), offset = args.offset ?? 0;
        if (!STATUSES.has(status) || !Number.isSafeInteger(offset) || Number(offset) < 0 || Number(offset) > 1_000_000) throw new BridgeInputError();
        const { data, error } = await client.from("food_orders").select("*,food_order_items(*),food_delivery_proofs(*)").eq("store_id", storeId).eq("status", status).order("created_at", { ascending: !["delivered", "cancelled"].includes(status) }).order("id").range(Number(offset), Number(offset) + 49);
        if (error) throw error;
        return data ?? [];
      }
      case "report": return fetchMerchantSalesReport(client, storeId);
      case "staff": {
        const members = await fetchMerchantStaff(client, storeId);
        const me = members.find((m) => m.user_id === userId && m.active);
        return {
          canManage: me?.role === "owner" || me?.role === "admin",
          members: members.map((m) => ({
            user_id: m.user_id, username: m.username, display_name: m.display_name,
            role: m.role, active: m.active === true, self: m.user_id === userId,
          })),
        };
      }
      case "addStaff": {
        const username = text(args.username, 41, true), role = text(args.role, 20, true);
        if (!USERNAME.test(username) || !STAFF_ROLES.has(role)) throw new BridgeInputError();
        await requireStaffAdmin(storeId);
        // merchant_add_staff_by_username upserts, so adding yourself would change your own role.
        const { data: me, error: meError } = await client.from("profiles").select("username").eq("id", userId).maybeSingle();
        if (meError) throw meError;
        const own = typeof me?.username === "string" ? me.username.toLowerCase() : null;
        if (own && own === username.replace(/^@/, "").toLowerCase()) throw new Error("own staff access");
        await addMerchantStaff(client, storeId, username, role as "admin"); return null;
      }
      case "updateStaff": {
        const member = id(args.userId), role = text(args.role, 20, true), active = bool(args.active);
        // Nobody edits their own access here, so an owner/admin cannot lock themselves out.
        if (member === userId) throw new Error("own staff access");
        if (!STAFF_ROLES.has(role)) throw new BridgeInputError();
        await requireStaffAdmin(storeId);
        await updateMerchantStaff(client, storeId, member, role as "admin", active); return null;
      }
      case "billing": {
        // ZOKY-BILLING-001: owner/admin only, same gate as merchant_billing.
        await requireStaffAdmin(storeId);
        const { data, error } = await client.rpc("merchant_billing", { p_store_id: storeId });
        if (error) throw error;
        return data;
      }
      case "pickBillingSlip": {
        // The store transfers to ZOKY, then attaches the slip for one invoice.
        const invoiceId = id(args.invoiceId);
        await requireStaffAdmin(storeId);
        const file = await picked;
        if (!file) return null;
        await validateImage(file); await ensureSession();
        // The storage policy and the RPC both check the invoice belongs to this store.
        const path = await uploadFoodPrivateImage(client, file, `billing/${storeId}/${invoiceId}`);
        await ensureSession();
        const { error } = await client.rpc("merchant_submit_billing_slip", { p_invoice_id: invoiceId, p_slip_path: path });
        if (error) throw error;
        return { submitted: true };
      }
      case "ads": {
        await requireManageRole(storeId);
        return friendly(() => fetchMerchantAdAccount(client, storeId), merchantAdError);
      }
      case "pickAdSlip": {
        // Top up ad credit: the store transfers to ZOKY's PromptPay, then attaches the slip.
        const value = topupAmount(args.amount);
        await requireManageRole(storeId);
        const file = await picked;
        if (!file) return null;
        await validateImage(file); await ensureSession();
        await friendly(() => requestAdTopup(client, storeId, value, file), merchantAdError);
        return { submitted: true };
      }
      case "setAdActive": {
        const active = bool(args.active);
        await requireManageRole(storeId);
        await friendly(() => setAdActive(client, storeId, active), merchantAdError); return null;
      }
      case "platformCampaigns": {
        await requireManageRole(storeId);
        return friendly(() => fetchPlatformCampaigns(client, storeId), platformCampaignError);
      }
      case "joinPlatformCampaign": {
        const campaign = id(args.campaignId), join = bool(args.join);
        await requireManageRole(storeId);
        await friendly(() => join ? joinPlatformCampaign(client, storeId, campaign) : leavePlatformCampaign(client, storeId, campaign), platformCampaignError);
        return null;
      }
      case "finance": {
        const period = text(args.period, 12, true);
        if (!["today", "yesterday", "week", "month"].includes(period)) throw new BridgeInputError();
        await requireManageRole(storeId);
        // Bangkok calendar periods, same as the legacy finance page; the RPC rechecks the role.
        return fetchFinanceSummary(client, storeId, periodRange(period as "today" | "yesterday" | "week" | "month"));
      }
      case "quality": {
        // The existing RPC aggregates all visible store reviews independently
        // of feed length. Do not transfer customer review details into Dart.
        const feed = await fetchMerchantStoreReviews(client, storeId, 1);
        if (!feed) return { available: false, count: null, average: null, unanswered: null };
        const { count, average, unanswered } = feed;
        if (!Number.isSafeInteger(count) || count < 0 || !Number.isSafeInteger(unanswered) || unanswered < 0 || unanswered > count ||
            (count > 0 && (!Number.isFinite(average) || average < 1 || average > 5))) throw new Error("invalid_review_summary");
        return { available: true, count, average: count === 0 ? null : average, unanswered };
      }
      case "campaigns": return fetchMerchantCampaigns(client, storeId);
      case "saveMenu": {
        const values = object(args.values), itemId = args.id == null ? undefined : id(args.id);
        await requireManageRole(storeId);
        const patch: Args = {};
        if (values.name !== undefined) patch.name = text(values.name, 160, true);
        if (values.category !== undefined) patch.category = text(values.category, 60, true);
        if (values.description !== undefined) patch.description = text(values.description, 1000) || null;
        if (values.price !== undefined) patch.price = amount(values.price, 999999);
        if (values.is_available !== undefined) patch.is_available = bool(values.is_available);
        if (!Object.keys(patch).length) throw new BridgeInputError();
        if (itemId) {
          // Patch only edited fields. Rewriting an old options/image/stock
          // snapshot here could undo concurrent changes in the legacy editor.
          const { data, error } = await client.from("food_menu_items").update(patch)
            .eq("store_id", storeId).eq("id", itemId)
            .select("id,name,category,description,price,is_available,options,image_path,daily_stock_limit,sold_out_until").single();
          if (error) throw error;
          if (!data) throw new Error("write_not_applied");
          verifyPatch(data, patch);
        } else {
          const prepared = {
            store_id: storeId, name: text(values.name, 160, true),
            category: text(values.category ?? "อาหาร", 60, true),
            description: text(values.description ?? "", 1000) || null,
            price: amount(values.price, 999999),
            is_available: values.is_available == null ? true : bool(values.is_available),
          };
          const { data, error } = await client.from("food_menu_items").insert(prepared).select("*").single();
          if (error) throw error;
          if (!data) throw new Error("write_not_applied");
          verifyPatch(data, prepared);
        }
        return null;
      }
      case "saveStore": {
        const values = object(args.values), patch: Partial<FoodStore> = {};
        if (values.name !== undefined) patch.name = text(values.name, 160, true);
        if (values.phone !== undefined) patch.phone = text(values.phone, 50, true);
        if (values.address !== undefined) patch.address = text(values.address, 800, true);
        if (values.is_open !== undefined) patch.is_open = bool(values.is_open);
        // Payment channels (customers pay the store directly) and opening hours.
        if (values.promptpay_name !== undefined) patch.promptpay_name = optionalText(values.promptpay_name, 160);
        if (values.promptpay_id !== undefined) {
          // Same rule as food_stores_promptpay_id_format_check: phone (0…), citizen ID or e-wallet.
          const promptpay = digits(values.promptpay_id, 10, 15);
          if (promptpay && (![10, 13, 15].includes(promptpay.length) || (promptpay.length === 10 && !promptpay.startsWith("0")))) throw new BridgeInputError();
          patch.promptpay_id = promptpay;
        }
        if (values.bank_name !== undefined) patch.bank_name = optionalText(values.bank_name, 120);
        if (values.bank_account_name !== undefined) patch.bank_account_name = optionalText(values.bank_account_name, 160);
        if (values.bank_account_number !== undefined) patch.bank_account_number = digits(values.bank_account_number, 10, 15);
        if (values.payment_qr_path !== undefined) {
          if (values.payment_qr_path !== null) throw new BridgeInputError(); // set only by pickPaymentQr
          patch.payment_qr_path = null;
        }
        if (values.business_schedule !== undefined) patch.business_schedule = schedule(values.business_schedule);
        if (values.special_closed_dates !== undefined) patch.special_closed_dates = closedDates(values.special_closed_dates);
        if (!Object.keys(patch).length) throw new BridgeInputError();
        await requireManageRole(storeId);
        await updateFoodStore(client, storeId, patch);
        const { data, error } = await client.from("food_stores").select(`id,${Object.keys(patch).join(",")}`).eq("id", storeId).single();
        if (error) throw error;
        if (!data) throw new Error("write_not_applied");
        verifyPatch(data, patch);
        return null;
      }
      case "pickPaymentQr": {
        await requireManageRole(storeId);
        const file = await picked;
        if (!file) return null;
        await validateImage(file); await ensureSession();
        const path = await uploadFoodPublicImage(client, file, `stores/${storeId}/payment`);
        await ensureSession();
        await updateFoodStore(client, storeId, { payment_qr_path: path });
        const { data, error } = await client.from("food_stores").select("id,payment_qr_path").eq("id", storeId).single();
        if (error) throw error;
        if (!data) throw new Error("write_not_applied");
        verifyPatch(data, { payment_qr_path: path });
        return { path, url: foodPublicUrl(client, path) };
      }
      case "transition": {
        const orderId = id(args.orderId), status = text(args.status, 30, true);
        if (!["preparing", "ready_for_delivery", "out_for_delivery", "cancelled", "ready_for_pickup", "picked_up"].includes(status)) throw new BridgeInputError();
        if (args.etaMinutes != null && (!Number.isInteger(args.etaMinutes) || Number(args.etaMinutes) < 1 || Number(args.etaMinutes) > 240)) throw new BridgeInputError();
        const order = await ownedOrder(storeId, orderId);
        await ensureSession();
        // Pickup actions (contract v2): only valid on pickup orders, mapped to
        // ready_for_delivery / food_complete_pickup by the wrapper.
        if (status === "ready_for_pickup" || status === "picked_up") {
          if (order.fulfillment_type !== "pickup") throw new BridgeInputError();
          await transitionPickupOrder(client, orderId, status); return null;
        }
        if (status === "out_for_delivery" && order.fulfillment_type === "pickup") throw new BridgeInputError();
        await transitionFoodOrder(client, orderId, status as FoodOrder["status"], args.etaMinutes == null ? undefined : Number(args.etaMinutes), text(args.note, 1000)); return null;
      }
      case "payment": {
        const orderId = id(args.orderId), status = text(args.status, 20, true);
        if (!["paid", "issue"].includes(status)) throw new BridgeInputError();
        const order = await ownedOrder(storeId, orderId);
        if (order.payment_method === "cod") throw new BridgeInputError();
        if (status === "paid" && !order.payment_slip_path && !(args.manualConfirmation === true && order.payment_status === "pending")) throw new BridgeInputError();
        if (order.payment_provider === "stripe" || (order.stripe_checkout_session_id && !order.payment_slip_path)) throw new Error("stripe payment status");
        await ensureSession();
        await setFoodPaymentStatus(client, orderId, status as "paid" | "issue", text(args.note, 800)); return null;
      }
      case "signedUrl": {
        const order = await ownedOrder(storeId, id(args.orderId));
        if (args.kind !== "slip" && args.kind !== "proof") throw new BridgeInputError();
        const proof = orderDeliveryProof(order);
        return foodPrivateSignedUrl(client, args.kind === "slip" ? order.payment_slip_path : proof?.image_path, 900);
      }
      case "pickRefundSlip":
      case "pickDeliveryPhoto": {
        const order = await ownedOrder(storeId, id(args.orderId));
        const refund = method === "pickRefundSlip";
        if (refund) {
          if (order.refund_status !== "pending" || order.payment_provider === "stripe" || order.payment_method === "cod") throw new BridgeInputError();
          await requireManageRole(storeId);
        } else if (order.status !== "out_for_delivery") throw new Error("not out for delivery");
        const file = await picked;
        if (!file) return null;
        await validateImage(file); await ensureSession();
        const handle = `pending:${crypto.randomUUID()}`;
        const previewUrl = URL.createObjectURL(file);
        for (const [path, selection] of photos) {
          if (selection.storeId === storeId && selection.orderId === order.id && selection.kind === (refund ? "refund" : undefined)) {
            if (selection.completing) { URL.revokeObjectURL(previewUrl); throw new BridgeInputError(); }
            releasePhoto(path);
          }
        }
        photos.set(handle, { storeId, orderId: order.id, file, previewUrl, ...(refund ? { kind: "refund" as const } : {}) });
        return { path: handle, previewUrl };
      }
      case "releaseDeliveryPhoto": {
        const path = text(args.imagePath, 250, true), orderId = id(args.orderId);
        const selection = photos.get(path);
        if (selection && (selection.storeId !== storeId || selection.orderId !== orderId)) throw new BridgeAccessError();
        if (selection?.completing) throw new BridgeInputError();
        releasePhoto(path); return null;
      }
      case "completeDelivery": {
        const orderId = id(args.orderId), method = text(args.method, 10, true), handle = text(args.imagePath, 250, true);
        if (!["direct", "dropoff"].includes(method)) throw new BridgeInputError();
        const note = text(args.locationNote, 500, method === "dropoff");
        const selection = photos.get(handle);
        if (!selection || selection.kind === "refund" || selection.storeId !== storeId || selection.orderId !== orderId) throw new BridgeInputError();
        if (selection.completing) { await selection.completing; return null; }
        const operation = async () => {
          const order = await ownedOrder(storeId, orderId);
          const proof = orderDeliveryProof(order);
          // A lost RPC response must not create another upload or undo evidence.
          if (selection.uploadedPath && order.status === "delivered" && proof?.image_path === selection.uploadedPath) return;
          if (order.payment_method === "cod" && args.cashReceived !== true) throw new BridgeInputError();
          if (order.status !== "out_for_delivery") throw new Error("not out for delivery");
          const { data, error } = await client.rpc("merchant_has_store_role", { p_store_id: storeId, p_roles: ["owner", "admin", "manager", "orders", "delivery"] });
          if (error || data !== true) throw new BridgeAccessError();
          await ensureSession();
          selection.uploadedPath ??= await uploadFoodPrivateImage(client, selection.file, `delivery/${orderId}`);
          await ensureSession();
          await completeFoodDelivery(client, orderId, method as "direct" | "dropoff", note, selection.uploadedPath);
        };
        selection.completing = operation();
        try { await selection.completing; releasePhoto(handle); }
        finally { selection.completing = undefined; }
        return null;
      }
      case "createCampaign": {
        const name = text(args.name, 80, true), discount = amount(args.discount, 100);
        if (name.length < 2 || discount <= 0) throw new BridgeInputError();
        return saveMerchantCampaign(client, storeId, { name, campaignType: "percentage", scope: "store", discountValue: String(discount), minSubtotal: "0", maxDiscount: "", startsAt: "", endsAt: "", usageLimit: "", itemIds: [] });
      }
      case "setCampaignActive": await setMerchantCampaignActive(client, storeId, id(args.id), bool(args.active)); return null;
      case "subscribe":
        if (subscription) await client.removeChannel(subscription);
        await ensureSession();
        subscription = subscribeMerchantOrders(client, storeId, () => { if (!disposed) onOrderChange?.(); }); return null;
      default: throw new BridgeInputError();
    }
  };
  return {
    async request(method, payloadJson) {
      try {
        if (typeof method !== "string" || typeof payloadJson !== "string" || payloadJson.length > 16_384) throw new BridgeInputError();
        if (disposed) throw new BridgeAccessError();
        const args = object(JSON.parse(payloadJson));
        // OS picker opens synchronously during the user's tap, before network awaits.
        const picker = method === "pickDeliveryPhoto" || method === "pickRefundSlip" || method === "pickPaymentQr" || method === "pickAdSlip" || method === "pickBillingSlip";
        if (picker) { id(args.storeId); if (method === "pickDeliveryPhoto" || method === "pickRefundSlip") id(args.orderId); }
        if (method === "pickBillingSlip") id(args.invoiceId);
        if (method === "pickAdSlip") topupAmount(args.amount);
        const picked = picker ? pickImage() : null;
        const permissionRequest = method === "pushEnable" ? requestPushPermissionFromGesture() : undefined;
        // Session validation may reject before the captured prompt settles.
        void permissionRequest?.catch(() => undefined);
        const data = await execute(method, args, picked, permissionRequest);
        if (method !== "signOut") await ensureSession();
        return JSON.stringify({ ok: true, data: data ?? null });
      } catch (error) { return JSON.stringify({ ok: false, error: safeError(error) }); }
    },
    dispose() {
      disposed = true;
      for (const path of photos.keys()) releasePhoto(path);
      if (subscription) { void client.removeChannel(subscription).catch(() => undefined); subscription = null; }
    },
  };
}
