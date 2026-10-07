import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { withoutLocation } from "@/lib/image-location";
import { imageUploadType } from "@/lib/upload-image";
import type { FoodBusinessSchedule } from "@/lib/food-store-availability";
import { foodSoldOutUntilTomorrowBangkok } from "@/lib/food-store-availability";

export { orderDeliveryProof } from "@/lib/food-delivery-proof";

export type FoodStore = {
  id: string;
  merchant_account_id: string | null;
  slug: string;
  /** Short share-link code (food.wynos.online/s/<code>); null before that migration. */
  share_code?: string | null;
  name: string;
  description: string | null;
  phone: string | null;
  address: string | null;
  logo_path: string | null;
  cover_path: string | null;
  business_hours: string | null;
  business_schedule?: FoodBusinessSchedule | Record<string, unknown>;
  special_closed_dates?: string[];
  temporary_closed_until?: string | null;
  temporary_closed_reason?: string | null;
  prep_time_min_minutes?: number;
  prep_time_max_minutes?: number;
  menu_category_order?: string[];
  delivery_area: string | null;
  delivery_fee: number | string;
  minimum_order: number | string;
  /** WYN-196 delivery zone. latitude null = flat delivery fee, no radius. */
  latitude?: number | null;
  longitude?: number | null;
  /** Separate entrance / rider pickup pin. */
  pickup_latitude?: number | null;
  pickup_longitude?: number | null;
  pickup_note?: string | null;
  delivery_radius_km?: number | string;
  delivery_base_km?: number | string;
  delivery_fee_per_km?: number | string;
  promptpay_name: string | null;
  promptpay_id: string | null;
  bank_name: string | null;
  bank_account_name: string | null;
  bank_account_number: string | null;
  payment_qr_path: string | null;
  stripe_payments_enabled?: boolean;
  scheduled_orders_enabled?: boolean;
  scheduled_min_notice_minutes?: number;
  scheduled_max_days?: number;
  tax_invoice_enabled?: boolean;
  tax_legal_name?: string | null;
  tax_id?: string | null;
  tax_branch?: string | null;
  tax_address?: string | null;
  is_open: boolean;
  is_published: boolean;
  /** WYN-203: set by WYNOS Admin; the store cannot open or publish while set. */
  admin_suspended_at?: string | null;
  admin_suspended_reason?: string | null;
  created_at: string;
  updated_at: string;
};

export type FoodMenuOptionChoice = {
  id: string;
  name: string;
  price: number | string;
};

export type FoodMenuOptionGroup = {
  id: string;
  name: string;
  required: boolean;
  max_select: number;
  choices: FoodMenuOptionChoice[];
};

export type FoodMenuItem = {
  id: string;
  store_id: string;
  category: string;
  name: string;
  description: string | null;
  price: number | string;
  image_path: string | null;
  options: FoodMenuOptionGroup[];
  is_available: boolean;
  sold_out_until?: string | null;
  daily_stock_limit?: number | null;
  sort_order: number;
  created_at: string;
  updated_at: string;
};

export type FoodOrderItem = {
  id: string;
  order_id: string;
  menu_item_id: string | null;
  item_name: string;
  unit_price: number | string;
  quantity: number;
  selected_options: unknown[];
  item_note: string | null;
  created_at: string;
};

export type FoodDeliveryProof = {
  id: string;
  order_id: string;
  method: "direct" | "dropoff";
  location_note: string | null;
  image_path: string | null;
  delivered_by: string | null;
  created_at: string;
};

export type FoodOrder = {
  id: string;
  order_number: string;
  store_id: string;
  buyer_id: string | null;
  created_by: string | null;
  source: "app" | "manual" | "social";
  status: "pending_acceptance" | "preparing" | "ready_for_delivery" | "out_for_delivery" | "delivered" | "cancelled";
  payment_status: "pending" | "submitted" | "paid" | "issue" | "refunded";
  refund_status: "none" | "pending" | "refunded" | "failed";
  refund_note: string | null;
  refund_requested_at: string | null;
  refunded_at: string | null;
  refund_updated_by: string | null;
  recipient_name: string;
  recipient_phone: string;
  shipping_address: string;
  customer_note: string | null;
  payment_slip_path: string | null;
  payment_note: string | null;
  payment_verification_status: "not_started" | "manual_review" | "auto_verified" | "manual_verified" | "rejected";
  payment_provider: string | null;
  payment_provider_code: string | null;
  payment_transaction_ref: string | null;
  payment_verified_at: string | null;
  payment_verification_note: string | null;
  stripe_checkout_session_id?: string | null;
  stripe_payment_intent_id?: string | null;
  stripe_refund_id?: string | null;
  source_drop_id: string | null;
  subtotal: number | string;
  delivery_fee: number | string;
  delivery_latitude?: number | null;
  delivery_longitude?: number | null;
  delivery_distance_km?: number | string | null;
  campaign_id: string | null;
  campaign_name: string | null;
  campaign_discount: number | string;
  delivery_discount: number | string;
  total: number | string;
  eta_minutes: number | null;
  accepted_at: string | null;
  ready_at: string | null;
  out_for_delivery_at: string | null;
  delivered_at: string | null;
  cancelled_at: string | null;
  paid_at: string | null;
  scheduled_for?: string | null;
  receipt_legal_name?: string | null;
  receipt_tax_id?: string | null;
  receipt_tax_branch?: string | null;
  receipt_tax_address?: string | null;
  created_at: string;
  updated_at: string;
  food_order_items?: FoodOrderItem[];
  food_delivery_proofs?: FoodDeliveryProof | FoodDeliveryProof[] | null;
};



export type MerchantSnapshot = {
  access: boolean;
  stores: FoodStore[];
  store: FoodStore | null;
  menu: FoodMenuItem[];
  orders: FoodOrder[];
  has_more_orders: boolean;
};

export type MerchantSalesReport = {
  today_sales: number;
  today_orders: number;
  week_sales: number;
  week_orders: number;
  month_sales: number;
  month_orders: number;
  total_orders: number;
  average_order: number;
  best: Array<{ name: string; quantity: number }>;
};

export const MERCHANT_ORDER_PAGE_SIZE = 100;

export type MenuDraft = {
  id?: string;
  name: string;
  category: string;
  description: string;
  price: string;
  image_path?: string | null;
  options: FoodMenuOptionGroup[];
  is_available: boolean;
  sold_out_until?: string | null;
  daily_stock_limit?: string | number | null;
};


const FOOD_PUBLIC = "food-public";
const FOOD_PRIVATE = "food-private";
const SUPPORTED_FOOD_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

function errorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) return error.message;
  if (typeof error === "object" && error && "message" in error && typeof (error as { message?: unknown }).message === "string") {
    return String((error as { message: string }).message);
  }
  return fallback;
}

export function money(value: number | string | null | undefined) {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat("th-TH", { style: "currency", currency: "THB", minimumFractionDigits: amount % 1 ? 2 : 0 }).format(amount);
}

/** Options the customer picked, as saved by the server (WYN-218), e.g. "เผ็ดมาก · ไข่ดาว". */
export function orderItemOptionText(item: Pick<FoodOrderItem, "selected_options">) {
  if (!Array.isArray(item.selected_options)) return "";
  return item.selected_options
    .map((option) => {
      if (!option || typeof option !== "object") return "";
      const name = (option as { choice_name?: unknown }).choice_name;
      return typeof name === "string" ? name.trim() : "";
    })
    .filter(Boolean)
    .join(" · ");
}

export function foodPublicUrl(client: SupabaseClient, path: string | null | undefined) {
  if (!path) return null;
  return client.storage.from(FOOD_PUBLIC).getPublicUrl(path).data.publicUrl;
}

export async function foodPrivateSignedUrl(client: SupabaseClient, path: string | null | undefined, expiresIn = 900) {
  if (!path) return null;
  const { data, error } = await client.storage.from(FOOD_PRIVATE).createSignedUrl(path, expiresIn);
  if (error) return null;
  return data.signedUrl;
}

export async function fetchMerchantOrdersPage(
  client: SupabaseClient,
  storeId: string,
  offset = 0,
  limit = MERCHANT_ORDER_PAGE_SIZE,
): Promise<{ orders: FoodOrder[]; hasMore: boolean }> {
  const safeOffset = Math.max(0, Math.floor(offset));
  const safeLimit = Math.max(1, Math.min(250, Math.floor(limit)));
  const { data, error } = await client
    .from("food_orders")
    .select("*,food_order_items(*),food_delivery_proofs(*)")
    .eq("store_id", storeId)
    .order("created_at", { ascending: false })
    // Supabase range is inclusive, so request one extra row to detect more.
    .range(safeOffset, safeOffset + safeLimit);
  if (error) throw new Error(error.message);
  const rows = (data ?? []) as FoodOrder[];
  return { orders: rows.slice(0, safeLimit), hasMore: rows.length > safeLimit };
}

const BANGKOK_DATE_FORMAT = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Bangkok",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function bangkokDateKey(value: string | Date) {
  const parts = BANGKOK_DATE_FORMAT.formatToParts(value instanceof Date ? value : new Date(value));
  const year = parts.find((part) => part.type === "year")?.value ?? "1970";
  const month = parts.find((part) => part.type === "month")?.value ?? "01";
  const day = parts.find((part) => part.type === "day")?.value ?? "01";
  return `${year}-${month}-${day}`;
}

function bangkokWeekStartKey(today: string) {
  const [year, month, day] = today.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  const daysSinceMonday = (date.getUTCDay() + 6) % 7;
  date.setUTCDate(date.getUTCDate() - daysSinceMonday);
  return date.toISOString().slice(0, 10);
}

type MerchantReportOrder = {
  total: number | string;
  created_at: string;
  food_order_items?: Array<Pick<FoodOrderItem, "item_name" | "quantity">>;
};

function merchantSalesReportFromOrders(rows: MerchantReportOrder[]): MerchantSalesReport {
  const today = bangkokDateKey(new Date());
  const weekStart = bangkokWeekStartKey(today);
  const month = today.slice(0, 7);
  let todaySales = 0;
  let todayOrders = 0;
  let weekSales = 0;
  let weekOrders = 0;
  let monthSales = 0;
  let monthOrders = 0;
  let totalSales = 0;
  const itemCount = new Map<string, number>();

  for (const order of rows) {
    const amount = Number(order.total) || 0;
    const day = bangkokDateKey(order.created_at);
    totalSales += amount;
    if (day === today) {
      todaySales += amount;
      todayOrders += 1;
    }
    if (day >= weekStart && day <= today) {
      weekSales += amount;
      weekOrders += 1;
    }
    if (day.slice(0, 7) === month) {
      monthSales += amount;
      monthOrders += 1;
    }
    for (const item of order.food_order_items ?? []) {
      itemCount.set(item.item_name, (itemCount.get(item.item_name) ?? 0) + Number(item.quantity || 0));
    }
  }

  return {
    today_sales: todaySales,
    today_orders: todayOrders,
    week_sales: weekSales,
    week_orders: weekOrders,
    month_sales: monthSales,
    month_orders: monthOrders,
    total_orders: rows.length,
    average_order: rows.length ? totalSales / rows.length : 0,
    best: [...itemCount.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], "th"))
      .slice(0, 5)
      .map(([name, quantity]) => ({ name, quantity })),
  };
}

function normalizeMerchantSalesReport(data: unknown): MerchantSalesReport {
  const raw = (data ?? {}) as Partial<MerchantSalesReport>;
  return {
    today_sales: Number(raw.today_sales ?? 0),
    today_orders: Number(raw.today_orders ?? 0),
    week_sales: Number(raw.week_sales ?? 0),
    week_orders: Number(raw.week_orders ?? 0),
    month_sales: Number(raw.month_sales ?? 0),
    month_orders: Number(raw.month_orders ?? 0),
    total_orders: Number(raw.total_orders ?? 0),
    average_order: Number(raw.average_order ?? 0),
    best: Array.isArray(raw.best)
      ? raw.best
          .map((item) => ({ name: String(item?.name ?? ""), quantity: Number(item?.quantity ?? 0) }))
          .filter((item) => item.name && Number.isFinite(item.quantity) && item.quantity > 0)
          .slice(0, 5)
      : [],
  };
}

/**
 * Full sales report for Merchant. The RPC keeps aggregation server-side.
 * During a migration rollout, missing-RPC errors fall back to paged delivered
 * orders so the report stays complete instead of silently using the first 100.
 */
export async function fetchMerchantSalesReport(client: SupabaseClient, storeId: string): Promise<MerchantSalesReport> {
  const rpc = await client.rpc("merchant_sales_report", { p_store_id: storeId });
  if (!rpc.error) return normalizeMerchantSalesReport(rpc.data);
  if (rpc.error.code !== "PGRST202" && rpc.error.code !== "42883") throw new Error(rpc.error.message);

  const rows: MerchantReportOrder[] = [];
  const pageSize = 250;
  for (let offset = 0; ; offset += pageSize) {
    const page = await client
      .from("food_orders")
      .select("total,created_at,food_order_items(item_name,quantity)")
      .eq("store_id", storeId)
      .eq("status", "delivered")
      .order("created_at", { ascending: false })
      .range(offset, offset + pageSize - 1);
    if (page.error) throw new Error(page.error.message);
    const batch = (page.data ?? []) as MerchantReportOrder[];
    rows.push(...batch);
    if (batch.length < pageSize) break;
  }
  return merchantSalesReportFromOrders(rows);
}

export async function fetchMerchantSnapshot(
  client: SupabaseClient,
  preferredStoreId?: string | null,
): Promise<MerchantSnapshot> {
  const accessResult = await client.rpc("food_has_merchant_access", { p_store_id: null });
  if (accessResult.error) throw new Error(accessResult.error.message);
  const access = accessResult.data === true;
  if (!access) return { access: false, stores: [], store: null, menu: [], orders: [], has_more_orders: false };

  // RLS limits this list to stores the signed-in Merchant member may access.
  const storesResult = await client
    .from("food_stores")
    .select("*")
    .order("created_at", { ascending: true });
  if (storesResult.error) throw new Error(storesResult.error.message);
  const stores = (storesResult.data ?? []) as FoodStore[];
  const store = stores.find((item) => item.id === preferredStoreId) ?? stores[0] ?? null;
  if (!store) return { access: true, stores: [], store: null, menu: [], orders: [], has_more_orders: false };

  const [menuResult, orderPage] = await Promise.all([
    client
      .from("food_menu_items")
      .select("*")
      .eq("store_id", store.id)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: true }),
    fetchMerchantOrdersPage(client, store.id),
  ]);

  if (menuResult.error) throw new Error(menuResult.error.message);

  return {
    access: true,
    stores,
    store,
    menu: (menuResult.data ?? []) as FoodMenuItem[],
    orders: orderPage.orders,
    has_more_orders: orderPage.hasMore,
  };
}

export async function updateFoodStore(client: SupabaseClient, storeId: string, patch: Partial<FoodStore>) {
  const allowed = {
    name: patch.name,
    description: patch.description,
    phone: patch.phone,
    address: patch.address,
    logo_path: patch.logo_path,
    cover_path: patch.cover_path,
    business_hours: patch.business_hours,
    business_schedule: patch.business_schedule,
    special_closed_dates: patch.special_closed_dates,
    temporary_closed_until: patch.temporary_closed_until,
    temporary_closed_reason: patch.temporary_closed_reason,
    prep_time_min_minutes: patch.prep_time_min_minutes,
    prep_time_max_minutes: patch.prep_time_max_minutes,
    menu_category_order: patch.menu_category_order,
    delivery_area: patch.delivery_area,
    delivery_fee: patch.delivery_fee,
    minimum_order: patch.minimum_order,
    latitude: patch.latitude,
    longitude: patch.longitude,
    pickup_latitude: patch.pickup_latitude,
    pickup_longitude: patch.pickup_longitude,
    pickup_note: patch.pickup_note,
    delivery_radius_km: patch.delivery_radius_km,
    delivery_base_km: patch.delivery_base_km,
    delivery_fee_per_km: patch.delivery_fee_per_km,
    promptpay_name: patch.promptpay_name,
    promptpay_id: patch.promptpay_id,
    bank_name: patch.bank_name,
    bank_account_name: patch.bank_account_name,
    bank_account_number: patch.bank_account_number,
    payment_qr_path: patch.payment_qr_path,
    scheduled_orders_enabled: patch.scheduled_orders_enabled,
    scheduled_min_notice_minutes: patch.scheduled_min_notice_minutes,
    scheduled_max_days: patch.scheduled_max_days,
    tax_invoice_enabled: patch.tax_invoice_enabled,
    tax_legal_name: patch.tax_legal_name,
    tax_id: patch.tax_id,
    tax_branch: patch.tax_branch,
    tax_address: patch.tax_address,
    is_open: patch.is_open,
    is_published: patch.is_published,
  };
  const payload = Object.fromEntries(Object.entries(allowed).filter(([, value]) => value !== undefined));
  const { error } = await client.from("food_stores").update(payload).eq("id", storeId);
  if (error) throw new Error(error.message);
}

/** WYN-197: a place the store delivers to, offered in the customer's place search. */
export type FoodStorePlace = {
  id: string;
  store_id: string;
  name: string;
  detail: string | null;
  latitude: number;
  longitude: number;
  is_active: boolean;
};

export type FoodStorePlaceDraft = {
  id?: string;
  name: string;
  detail: string;
  latitude: number;
  longitude: number;
  is_active: boolean;
};

/** null = the WYN-197 table is not there yet, so Merchant hides the list. */
export async function fetchStorePlaces(client: SupabaseClient, storeId: string): Promise<FoodStorePlace[] | null> {
  const { data, error } = await client
    .from("food_store_places")
    .select("id,store_id,name,detail,latitude,longitude,is_active")
    .eq("store_id", storeId)
    .order("name");
  if (error) {
    if (error.code === "42P01" || error.code === "PGRST205") return null;
    throw new Error(error.message);
  }
  return (data ?? []) as FoodStorePlace[];
}

export async function saveStorePlace(client: SupabaseClient, storeId: string, draft: FoodStorePlaceDraft) {
  const name = draft.name.trim();
  if (!name) throw new Error("กรุณาใส่ชื่อสถานที่");
  if (name.length > 120) throw new Error("ชื่อสถานที่ยาวเกินไป");
  if (!Number.isFinite(draft.latitude) || !Number.isFinite(draft.longitude)) throw new Error("กรุณาปักหมุดสถานที่");
  const payload = {
    store_id: storeId,
    name,
    detail: draft.detail.trim().slice(0, 200) || null,
    latitude: draft.latitude,
    longitude: draft.longitude,
    is_active: draft.is_active,
  };
  const query = draft.id
    ? client.from("food_store_places").update(payload).eq("id", draft.id).eq("store_id", storeId)
    : client.from("food_store_places").insert(payload);
  const { error } = await query;
  if (error) throw new Error(error.message);
}

export async function deleteStorePlace(client: SupabaseClient, storeId: string, placeId: string) {
  const { error } = await client.from("food_store_places").delete().eq("id", placeId).eq("store_id", storeId);
  if (error) throw new Error(error.message);
}

export async function saveMenuItem(client: SupabaseClient, storeId: string, draft: MenuDraft) {
  const price = Number(draft.price);
  if (!draft.name.trim()) throw new Error("กรุณาใส่ชื่อเมนู");
  if (!Number.isFinite(price) || price < 0) throw new Error("ราคาไม่ถูกต้อง");
  const payload = {
    store_id: storeId,
    name: draft.name.trim(),
    category: draft.category.trim() || "อาหาร",
    description: draft.description.trim() || null,
    price,
    image_path: draft.image_path || null,
    options: (draft.options ?? []).map((group) => ({
      id: String(group.id || "").trim(),
      name: String(group.name || "").trim(),
      required: Boolean(group.required),
      max_select: Math.max(1, Number(group.max_select) || 1),
      choices: (group.choices ?? [])
        .map((choice) => ({
          id: String(choice.id || "").trim(),
          name: String(choice.name || "").trim(),
          price: Math.max(0, Number(choice.price) || 0),
        }))
        .filter((choice) => choice.name),
    })).filter((group) => group.name && group.choices.length),
    is_available: draft.is_available,
    sold_out_until: draft.sold_out_until ?? null,
    daily_stock_limit: draft.daily_stock_limit == null || draft.daily_stock_limit === "" ? null : Math.max(1, Number(draft.daily_stock_limit) || 1),
  };
  const query = draft.id
    ? client.from("food_menu_items").update(payload).eq("id", draft.id).eq("store_id", storeId)
    : client.from("food_menu_items").insert(payload);
  const { error } = await query;
  if (error) throw new Error(error.message);
}

export async function deleteMenuItem(client: SupabaseClient, storeId: string, itemId: string) {
  const { error } = await client.from("food_menu_items").delete().eq("id", itemId).eq("store_id", storeId);
  if (error) throw new Error(error.message);
}

export async function setMenuAvailability(client: SupabaseClient, storeId: string, itemId: string, isAvailable: boolean) {
  const { error } = await client
    .from("food_menu_items")
    .update({ is_available: isAvailable })
    .eq("id", itemId)
    .eq("store_id", storeId);
  if (error) throw new Error(error.message);
}

async function foodImageBlob(file: File) {
  const { contentType, extension } = imageUploadType(file, 8 * 1024 * 1024);
  if (!SUPPORTED_FOOD_IMAGE_TYPES.has(contentType)) {
    throw new Error("WYNOS Merchant รองรับรูป JPG, PNG และ WebP");
  }
  return { contentType, extension, blob: await withoutLocation(file, contentType) };
}

export async function uploadFoodPublicImage(client: SupabaseClient, file: File, folder: string) {
  const { contentType, extension, blob } = await foodImageBlob(file);
  const path = `${folder}/${crypto.randomUUID()}.${extension}`;
  const { error } = await client.storage.from(FOOD_PUBLIC).upload(path, blob, {
    upsert: false,
    contentType,
    cacheControl: "31536000",
  });
  if (error) throw new Error(error.message);
  return path;
}

export async function uploadFoodPrivateImage(client: SupabaseClient, file: File, pathPrefix: string) {
  const { contentType, extension, blob } = await foodImageBlob(file);
  const path = `${pathPrefix}/${crypto.randomUUID()}.${extension}`;
  const { error } = await client.storage.from(FOOD_PRIVATE).upload(path, blob, {
    upsert: false,
    contentType,
    cacheControl: "300",
  });
  if (error) throw new Error(error.message);
  return path;
}

export async function setFoodPaymentStatus(client: SupabaseClient, orderId: string, status: "paid" | "issue" | "refunded", note?: string) {
  const { error } = await client.rpc("food_set_payment_status", {
    p_order_id: orderId,
    p_status: status,
    p_note: note || null,
  });
  if (error) throw new Error(error.message);
}

export async function transitionFoodOrder(client: SupabaseClient, orderId: string, status: FoodOrder["status"], etaMinutes?: number, note?: string) {
  const { error } = await client.rpc("food_transition_order", {
    p_order_id: orderId,
    p_status: status,
    p_eta_minutes: etaMinutes ?? null,
    p_note: note || null,
  });
  if (error) throw new Error(error.message);
}

export async function completeFoodDelivery(
  client: SupabaseClient,
  orderId: string,
  method: "direct" | "dropoff",
  locationNote?: string,
  imagePath?: string | null,
) {
  const { error } = await client.rpc("food_complete_delivery", {
    p_order_id: orderId,
    p_method: method,
    p_location_note: locationNote || null,
    p_image_path: imagePath || null,
  });
  if (error) throw new Error(error.message);
}

export function subscribeMerchantOrders(
  client: SupabaseClient,
  storeId: string,
  onOrderChange: (payload: { eventType: string; new: Record<string, unknown>; old: Record<string, unknown> }) => void,
): RealtimeChannel {
  return client
    .channel(`wynos-merchant-orders:${storeId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "food_orders", filter: `store_id=eq.${storeId}` },
      (payload) => onOrderChange(payload as unknown as { eventType: string; new: Record<string, unknown>; old: Record<string, unknown> }),
    )
    .subscribe();
}

export function statusLabel(status: FoodOrder["status"]) {
  return ({
    pending_acceptance: "รอรับออเดอร์",
    preparing: "กำลังเตรียม",
    ready_for_delivery: "พร้อมจัดส่ง",
    out_for_delivery: "กำลังจัดส่ง",
    delivered: "ส่งสำเร็จ",
    cancelled: "ยกเลิก",
  } satisfies Record<FoodOrder["status"], string>)[status];
}

export function paymentLabel(status: FoodOrder["payment_status"]) {
  return ({
    pending: "รอชำระเงิน",
    submitted: "รอตรวจสลิป",
    paid: "ชำระแล้ว",
    issue: "มีปัญหาการชำระเงิน",
    refunded: "คืนเงินแล้ว",
  } satisfies Record<FoodOrder["payment_status"], string>)[status];
}

export function merchantError(error: unknown, fallback = "ดำเนินการไม่สำเร็จ") {
  const message = errorMessage(error, fallback);
  if (message.includes("store suspension can only be changed by WYNOS admin")) return "การระงับร้านเปลี่ยนได้โดยทีม WYNOS เท่านั้น";
  if (message.includes("store is suspended")) return "ร้านถูกระงับโดยทีม WYNOS เปิดร้านหรือเผยแพร่ไม่ได้จนกว่าจะยกเลิกการระงับ";
  return message;
}


export type MerchantStoreReadiness = {
  ready: boolean;
  checks: Record<string, boolean>;
  missing: string[];
};

export type MerchantLocationQuality = {
  score: number;
  nearby_store_count: number;
  possible_duplicate_count: number;
  pickup_distance_km: number | null;
  warnings: string[];
};

export type MerchantAuditEntry = {
  id: string;
  actor_id: string | null;
  actor_username: string | null;
  event_type: string;
  detail: Record<string, unknown> | null;
  created_at: string;
};

export async function fetchMerchantStoreReadiness(client: SupabaseClient, storeId: string): Promise<MerchantStoreReadiness> {
  const { data, error } = await client.rpc("food_store_publish_readiness", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<MerchantStoreReadiness>;
  return {
    ready: raw.ready === true,
    checks: raw.checks ?? {},
    missing: Array.isArray(raw.missing) ? raw.missing.map(String) : [],
  };
}

export async function checkMerchantLocationQuality(
  client: SupabaseClient,
  storeId: string,
  latitude: number,
  longitude: number,
  name: string,
): Promise<MerchantLocationQuality> {
  const { data, error } = await client.rpc("food_store_location_quality", {
    p_store_id: storeId,
    p_latitude: latitude,
    p_longitude: longitude,
    p_name: name,
  });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<MerchantLocationQuality>;
  return {
    score: Number(raw.score ?? 0),
    nearby_store_count: Number(raw.nearby_store_count ?? 0),
    possible_duplicate_count: Number(raw.possible_duplicate_count ?? 0),
    pickup_distance_km: raw.pickup_distance_km == null ? null : Number(raw.pickup_distance_km),
    warnings: Array.isArray(raw.warnings) ? raw.warnings.map(String) : [],
  };
}

export async function fetchMerchantAuditHistory(client: SupabaseClient, storeId: string): Promise<MerchantAuditEntry[]> {
  const { data, error } = await client.rpc("merchant_store_audit_history", { p_store_id: storeId, p_limit: 60 });
  if (error) throw new Error(error.message);
  return (data ?? []) as MerchantAuditEntry[];
}

export async function setMenuSoldOutToday(client: SupabaseClient, storeId: string, itemId: string, soldOut: boolean) {
  const { error } = await client
    .from("food_menu_items")
    .update({ sold_out_until: soldOut ? foodSoldOutUntilTomorrowBangkok() : null })
    .eq("id", itemId)
    .eq("store_id", storeId);
  if (error) throw new Error(error.message);
}

export async function saveMenuSortOrder(client: SupabaseClient, storeId: string, orderedIds: string[]) {
  const updates = orderedIds.map((id, index) =>
    client.from("food_menu_items").update({ sort_order: index }).eq("id", id).eq("store_id", storeId),
  );
  const results = await Promise.all(updates);
  const failure = results.find((result) => result.error);
  if (failure?.error) throw new Error(failure.error.message);
}

export async function saveMenuCategoryOrder(client: SupabaseClient, storeId: string, categories: string[]) {
  const unique = Array.from(new Set(categories.map((value) => value.trim()).filter(Boolean)));
  const { error } = await client.from("food_stores").update({ menu_category_order: unique }).eq("id", storeId);
  if (error) throw new Error(error.message);
}
