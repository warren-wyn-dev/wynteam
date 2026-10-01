import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { withoutLocation } from "@/lib/image-location";
import { imageUploadType } from "@/lib/upload-image";

export type FoodStore = {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  phone: string | null;
  address: string | null;
  logo_path: string | null;
  cover_path: string | null;
  business_hours: string | null;
  delivery_area: string | null;
  delivery_fee: number | string;
  minimum_order: number | string;
  promptpay_name: string | null;
  promptpay_id: string | null;
  bank_name: string | null;
  bank_account_name: string | null;
  bank_account_number: string | null;
  payment_qr_path: string | null;
  is_open: boolean;
  is_published: boolean;
  created_at: string;
  updated_at: string;
};

export type FoodMenuItem = {
  id: string;
  store_id: string;
  category: string;
  name: string;
  description: string | null;
  price: number | string;
  image_path: string | null;
  options: unknown[];
  is_available: boolean;
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
  source: "app" | "manual";
  status: "pending_acceptance" | "preparing" | "ready_for_delivery" | "out_for_delivery" | "delivered" | "cancelled";
  payment_status: "pending" | "submitted" | "paid" | "issue" | "refunded";
  recipient_name: string;
  recipient_phone: string;
  shipping_address: string;
  customer_note: string | null;
  payment_slip_path: string | null;
  payment_note: string | null;
  subtotal: number | string;
  delivery_fee: number | string;
  total: number | string;
  eta_minutes: number | null;
  accepted_at: string | null;
  ready_at: string | null;
  out_for_delivery_at: string | null;
  delivered_at: string | null;
  cancelled_at: string | null;
  paid_at: string | null;
  created_at: string;
  updated_at: string;
  food_order_items?: FoodOrderItem[];
  food_delivery_proofs?: FoodDeliveryProof[];
};

export type MerchantSnapshot = {
  access: boolean;
  store: FoodStore | null;
  menu: FoodMenuItem[];
  orders: FoodOrder[];
};

export type MenuDraft = {
  id?: string;
  name: string;
  category: string;
  description: string;
  price: string;
  image_path?: string | null;
  is_available: boolean;
};

export type ManualOrderDraft = {
  recipientName: string;
  recipientPhone: string;
  shippingAddress: string;
  customerNote: string;
  paymentStatus: "pending" | "paid";
  items: Array<{ menu_item_id: string; quantity: number; note?: string }>;
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

export async function fetchMerchantSnapshot(client: SupabaseClient): Promise<MerchantSnapshot> {
  const accessResult = await client.rpc("food_has_merchant_access", { p_store_id: null });
  if (accessResult.error) throw new Error(accessResult.error.message);
  const access = accessResult.data === true;
  if (!access) return { access: false, store: null, menu: [], orders: [] };

  const storeResult = await client
    .from("food_stores")
    .select("*")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (storeResult.error) throw new Error(storeResult.error.message);
  const store = (storeResult.data as FoodStore | null) ?? null;
  if (!store) return { access: true, store: null, menu: [], orders: [] };

  const [menuResult, ordersResult] = await Promise.all([
    client
      .from("food_menu_items")
      .select("*")
      .eq("store_id", store.id)
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: true }),
    client
      .from("food_orders")
      .select("*,food_order_items(*),food_delivery_proofs(*)")
      .eq("store_id", store.id)
      .order("created_at", { ascending: false })
      .limit(250),
  ]);

  if (menuResult.error) throw new Error(menuResult.error.message);
  if (ordersResult.error) throw new Error(ordersResult.error.message);

  return {
    access: true,
    store,
    menu: (menuResult.data ?? []) as FoodMenuItem[],
    orders: (ordersResult.data ?? []) as FoodOrder[],
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
    delivery_area: patch.delivery_area,
    delivery_fee: patch.delivery_fee,
    minimum_order: patch.minimum_order,
    promptpay_name: patch.promptpay_name,
    promptpay_id: patch.promptpay_id,
    bank_name: patch.bank_name,
    bank_account_name: patch.bank_account_name,
    bank_account_number: patch.bank_account_number,
    payment_qr_path: patch.payment_qr_path,
    is_open: patch.is_open,
    is_published: patch.is_published,
  };
  const payload = Object.fromEntries(Object.entries(allowed).filter(([, value]) => value !== undefined));
  const { error } = await client.from("food_stores").update(payload).eq("id", storeId);
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
    is_available: draft.is_available,
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

export async function createManualFoodOrder(client: SupabaseClient, storeId: string, draft: ManualOrderDraft) {
  if (!draft.items.some((item) => item.quantity > 0)) throw new Error("กรุณาเลือกอย่างน้อย 1 เมนู");
  const { data, error } = await client.rpc("food_create_manual_order", {
    p_store_id: storeId,
    p_recipient_name: draft.recipientName,
    p_recipient_phone: draft.recipientPhone,
    p_shipping_address: draft.shippingAddress,
    p_customer_note: draft.customerNote || null,
    p_items: draft.items.filter((item) => item.quantity > 0),
    p_payment_status: draft.paymentStatus,
  });
  if (error) throw new Error(error.message);
  return String(data);
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
  return errorMessage(error, fallback);
}
