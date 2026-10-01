import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { withoutLocation } from "@/lib/image-location";
import { imageUploadType } from "@/lib/upload-image";

export type FoodCustomerStore = {
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

export type FoodCustomerMenuItem = {
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

export type FoodCustomerOrderItem = {
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

export type FoodCustomerDeliveryProof = {
  id: string;
  order_id: string;
  method: "direct" | "dropoff";
  location_note: string | null;
  image_path: string | null;
  delivered_by: string | null;
  created_at: string;
};

export type FoodCustomerOrder = {
  id: string;
  order_number: string;
  store_id: string;
  buyer_id: string | null;
  source: "app" | "manual" | "social";
  status: "pending_acceptance" | "preparing" | "ready_for_delivery" | "out_for_delivery" | "delivered" | "cancelled";
  payment_status: "pending" | "submitted" | "paid" | "issue" | "refunded";
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
  source_drop_id: string | null;
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
  food_order_items?: FoodCustomerOrderItem[];
  food_delivery_proofs?: FoodCustomerDeliveryProof[];
};

export type FoodCustomerAddress = {
  id: string;
  user_id: string;
  label: string;
  recipient_name: string;
  recipient_phone: string;
  address: string;
  delivery_note: string | null;
  is_default: boolean;
  created_at: string;
  updated_at: string;
};

export type FoodCartLine = {
  menu_item_id: string;
  quantity: number;
  note: string;
};

export type FoodCustomerSnapshot = {
  developer: boolean;
  store: FoodCustomerStore | null;
  menu: FoodCustomerMenuItem[];
  orders: FoodCustomerOrder[];
  addresses: FoodCustomerAddress[];
};

export type FoodAddressDraft = {
  id?: string | null;
  label: string;
  recipientName: string;
  recipientPhone: string;
  address: string;
  deliveryNote: string;
  isDefault: boolean;
};

const FOOD_PUBLIC = "food-public";
const FOOD_PRIVATE = "food-private";
const SUPPORTED_SLIP_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export function foodMoney(value: number | string | null | undefined) {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat("th-TH", {
    style: "currency",
    currency: "THB",
    minimumFractionDigits: amount % 1 ? 2 : 0,
  }).format(amount);
}

export function foodPublicUrl(client: SupabaseClient, path: string | null | undefined) {
  if (!path) return null;
  return client.storage.from(FOOD_PUBLIC).getPublicUrl(path).data.publicUrl;
}

export async function foodPrivateSignedUrl(
  client: SupabaseClient,
  path: string | null | undefined,
  expiresIn = 900,
) {
  if (!path) return null;
  const { data, error } = await client.storage.from(FOOD_PRIVATE).createSignedUrl(path, expiresIn);
  if (error) return null;
  return data.signedUrl;
}

export async function fetchFoodCustomerSnapshot(
  client: SupabaseClient,
  userId: string,
): Promise<FoodCustomerSnapshot> {
  const access = await client.rpc("is_developer_account");
  if (access.error || access.data !== true) {
    return { developer: false, store: null, menu: [], orders: [], addresses: [] };
  }

  const storeResult = await client
    .from("food_stores")
    .select("*")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (storeResult.error) throw new Error(storeResult.error.message);

  const store = (storeResult.data as FoodCustomerStore | null) ?? null;
  const [menuResult, ordersResult, addressesResult] = await Promise.all([
    store
      ? client
          .from("food_menu_items")
          .select("*")
          .eq("store_id", store.id)
          .order("sort_order", { ascending: true })
          .order("created_at", { ascending: true })
      : Promise.resolve({ data: [], error: null }),
    client
      .from("food_orders")
      .select("*,food_order_items(*),food_delivery_proofs(*)")
      .eq("buyer_id", userId)
      .order("created_at", { ascending: false })
      .limit(100),
    client
      .from("food_customer_addresses")
      .select("*")
      .eq("user_id", userId)
      .order("is_default", { ascending: false })
      .order("created_at", { ascending: false }),
  ]);

  if (menuResult.error) throw new Error(menuResult.error.message);
  if (ordersResult.error) throw new Error(ordersResult.error.message);
  if (addressesResult.error) throw new Error(addressesResult.error.message);

  return {
    developer: true,
    store,
    menu: (menuResult.data ?? []) as FoodCustomerMenuItem[],
    orders: (ordersResult.data ?? []) as FoodCustomerOrder[],
    addresses: (addressesResult.data ?? []) as FoodCustomerAddress[],
  };
}

export async function createFoodCustomerOrder(
  client: SupabaseClient,
  storeId: string,
  input: {
    recipientName: string;
    recipientPhone: string;
    shippingAddress: string;
    customerNote?: string;
    items: FoodCartLine[];
  },
) {
  const { data, error } = await client.rpc("food_create_order", {
    p_store_id: storeId,
    p_recipient_name: input.recipientName,
    p_recipient_phone: input.recipientPhone,
    p_shipping_address: input.shippingAddress,
    p_customer_note: input.customerNote || null,
    p_items: input.items.map((line) => ({
      menu_item_id: line.menu_item_id,
      quantity: line.quantity,
      note: line.note || "",
      selected_options: [],
    })),
  });
  if (error) throw new Error(error.message);
  return String(data);
}

export async function uploadFoodPaymentSlip(
  client: SupabaseClient,
  userId: string,
  orderId: string,
  file: File,
) {
  const { contentType, extension } = imageUploadType(file, 8 * 1024 * 1024);
  if (!SUPPORTED_SLIP_TYPES.has(contentType)) {
    throw new Error("รองรับสลิป JPG, PNG และ WebP เท่านั้น");
  }
  const blob = await withoutLocation(file, contentType);
  const path = `${userId}/slips/${orderId}/${crypto.randomUUID()}.${extension}`;
  const { error } = await client.storage.from(FOOD_PRIVATE).upload(path, blob, {
    upsert: false,
    contentType,
    cacheControl: "300",
  });
  if (error) throw new Error(error.message);
  return path;
}

export type FoodPaymentVerificationResult = {
  status: "auto_verified" | "manual_review" | "rejected";
  provider?: string;
  code?: string | null;
};

export async function fetchFoodPromptPayQr(client: SupabaseClient, orderId: string) {
  const { data, error } = await client.functions.invoke("food-payment-qr", {
    body: { orderId },
  });
  if (error || !data || typeof data.dataUrl !== "string") return null;
  return {
    dataUrl: data.dataUrl as string,
    amount: Number(data.amount ?? 0),
    payeeName: typeof data.payeeName === "string" ? data.payeeName : null,
  };
}

export async function submitFoodPayment(
  client: SupabaseClient,
  orderId: string,
  slipPath: string,
): Promise<FoodPaymentVerificationResult> {
  const { error } = await client.rpc("food_submit_payment", {
    p_order_id: orderId,
    p_slip_path: slipPath,
  });
  if (error) throw new Error(error.message);

  const verification = await client.functions.invoke("food-verify-slip", {
    body: { orderId },
  });
  if (verification.error || !verification.data) {
    return { status: "manual_review", provider: "manual" };
  }

  const status = verification.data.status;
  if (status !== "auto_verified" && status !== "manual_review" && status !== "rejected") {
    return { status: "manual_review", provider: "manual" };
  }
  return {
    status,
    provider: typeof verification.data.provider === "string" ? verification.data.provider : undefined,
    code: typeof verification.data.code === "string" ? verification.data.code : null,
  };
}

export async function saveFoodCustomerAddress(
  client: SupabaseClient,
  draft: FoodAddressDraft,
) {
  const { data, error } = await client.rpc("food_upsert_customer_address", {
    p_address_id: draft.id ?? null,
    p_label: draft.label,
    p_recipient_name: draft.recipientName,
    p_recipient_phone: draft.recipientPhone,
    p_address: draft.address,
    p_delivery_note: draft.deliveryNote || null,
    p_is_default: draft.isDefault,
  });
  if (error) throw new Error(error.message);
  return String(data);
}

export async function deleteFoodCustomerAddress(client: SupabaseClient, addressId: string) {
  const { error } = await client.rpc("food_delete_customer_address", {
    p_address_id: addressId,
  });
  if (error) throw new Error(error.message);
}

export async function cancelFoodCustomerOrder(
  client: SupabaseClient,
  orderId: string,
  reason?: string,
) {
  const { error } = await client.rpc("food_cancel_order", {
    p_order_id: orderId,
    p_reason: reason || null,
  });
  if (error) throw new Error(error.message);
}

export function subscribeFoodCustomerOrders(
  client: SupabaseClient,
  userId: string,
  onChange: () => void,
): RealtimeChannel {
  return client
    .channel(`wynos-food-customer:${userId}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "food_orders", filter: `buyer_id=eq.${userId}` },
      onChange,
    )
    .subscribe();
}

export function foodOrderStatusLabel(status: FoodCustomerOrder["status"]) {
  return ({
    pending_acceptance: "รอร้านรับออเดอร์",
    preparing: "กำลังเตรียมอาหาร",
    ready_for_delivery: "พร้อมจัดส่ง",
    out_for_delivery: "กำลังจัดส่ง",
    delivered: "จัดส่งสำเร็จ",
    cancelled: "ยกเลิกแล้ว",
  } satisfies Record<FoodCustomerOrder["status"], string>)[status];
}

export function foodPaymentStatusLabel(status: FoodCustomerOrder["payment_status"]) {
  return ({
    pending: "รอชำระเงิน",
    submitted: "กำลังตรวจสอบสลิป",
    paid: "ชำระเงินแล้ว",
    issue: "การชำระเงินมีปัญหา",
    refunded: "คืนเงินแล้ว",
  } satisfies Record<FoodCustomerOrder["payment_status"], string>)[status];
}

export function foodCustomerError(error: unknown, fallback = "ดำเนินการไม่สำเร็จ") {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("store is not accepting orders")) return "ร้านยังไม่เปิดรับออเดอร์";
  if (message.includes("minimum order not met")) return "ยอดอาหารยังไม่ถึงขั้นต่ำของร้าน";
  if (message.includes("menu item is unavailable")) return "มีเมนูที่ไม่พร้อมขาย กรุณาตรวจตะกร้าอีกครั้ง";
  if (message.includes("order cannot be cancelled by customer")) return "ออเดอร์นี้ยกเลิกเองไม่ได้แล้ว กรุณาติดต่อร้าน";
  if (message.includes("permanent account required")) return "ต้องใช้บัญชี WYNOS ที่ลงทะเบียนแล้ว";
  if (message.includes("address information is required")) return "กรุณากรอกข้อมูลที่อยู่ให้ครบ";
  return message || fallback;
}
