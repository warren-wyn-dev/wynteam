import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { withoutLocation } from "@/lib/image-location";
import { imageUploadType } from "@/lib/upload-image";

export { orderDeliveryProof } from "@/lib/food-delivery-proof";

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
  /** WYN-196: pinned store location. Null keeps the flat delivery fee. */
  latitude?: number | null;
  longitude?: number | null;
  delivery_radius_km?: number | string;
  delivery_base_km?: number | string;
  delivery_fee_per_km?: number | string;
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
  created_at: string;
  updated_at: string;
  food_order_items?: FoodCustomerOrderItem[];
  food_delivery_proofs?: FoodCustomerDeliveryProof | FoodCustomerDeliveryProof[] | null;
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
  latitude?: number | null;
  longitude?: number | null;
  created_at: string;
  updated_at: string;
};

/** WYN-196: a delivery pin. */
export type FoodLocation = { latitude: number; longitude: number };

function pinParams(location: FoodLocation | null | undefined) {
  return location ? { p_latitude: location.latitude, p_longitude: location.longitude } : {};
}

export function addressLocation(address: Pick<FoodCustomerAddress, "latitude" | "longitude"> | null | undefined): FoodLocation | null {
  if (address?.latitude == null || address?.longitude == null) return null;
  return { latitude: Number(address.latitude), longitude: Number(address.longitude) };
}

export function storeHasDeliveryZone(store: Pick<FoodCustomerStore, "latitude" | "longitude"> | null | undefined) {
  return store?.latitude != null && store?.longitude != null;
}

export type FoodCartLine = {
  menu_item_id: string;
  quantity: number;
  note: string;
};

export type FoodOrderQuote = {
  subtotal: number;
  delivery_fee: number;
  campaign_discount: number;
  delivery_discount: number;
  total: number;
  campaign_id: string | null;
  campaign_name: string | null;
  campaign_type: "percentage" | "fixed" | "free_delivery" | null;
  delivery_distance_km: number | null;
  delivery_radius_km: number | null;
  delivery_needs_location: boolean;
};

export type FoodCustomerSnapshot = {
  /** May use WYNOS Food at all (signed-in permanent account, public rollout or developer). */
  allowed: boolean;
  /** Developer accounts skip the Maha Sarakham area check, like the server does. */
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
  location: FoodLocation | null;
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
  storeId: string | null = null,
): Promise<FoodCustomerSnapshot> {
  const [access, developerCheck] = await Promise.all([
    client.rpc("food_customer_access_enabled"),
    client.rpc("is_developer_account"),
  ]);
  const developer = !developerCheck.error && developerCheck.data === true;
  if (!developer && (access.error || access.data !== true)) {
    return { allowed: false, developer: false, store: null, menu: [], orders: [], addresses: [] };
  }

  // WYN-207: the customer can pick a store from the directory; without a
  // pick (or if it is no longer visible) Food opens the first store.
  const picked = storeId
    ? await client.from("food_stores").select("*").eq("id", storeId).maybeSingle()
    : { data: null, error: null };
  const storeResult = picked.data
    ? picked
    : await client
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
    allowed: true,
    developer,
    store,
    menu: (menuResult.data ?? []) as FoodCustomerMenuItem[],
    orders: (ordersResult.data ?? []) as FoodCustomerOrder[],
    addresses: (addressesResult.data ?? []) as FoodCustomerAddress[],
  };
}

/**
 * WYN-206: names of the WYNOS campaigns this store has joined and that are
 * running now. Best effort: an older database without the RPC shows none.
 */
export async function fetchStorePlatformCampaigns(client: SupabaseClient, storeId: string): Promise<string[]> {
  const { data, error } = await client.rpc("food_platform_campaign_badges");
  if (error || !Array.isArray(data)) return [];
  return (data as Array<{ store_id: string; campaign_name: string }>)
    .filter((row) => row.store_id === storeId)
    .map((row) => row.campaign_name);
}

/** WYN-207: a store in the Food directory; is_ad = a live paid ad (shown first, labelled). */
export type FoodDirectoryStore = {
  id: string;
  slug: string;
  name: string;
  logo_path: string | null;
  cover_path: string | null;
  business_hours: string | null;
  delivery_fee: number | string;
  is_open: boolean;
  is_ad: boolean;
};

/** Store directory with live ads first. null = not available (older database). */
export async function fetchFoodStoreDirectory(client: SupabaseClient, query = ""): Promise<FoodDirectoryStore[] | null> {
  const { data, error } = await client.rpc("food_store_directory", { p_query: query.trim() || null });
  if (error || !Array.isArray(data)) return null;
  return data as FoodDirectoryStore[];
}

/** Tells the server an ad was opened; the server decides whether it is charged. */
export async function recordFoodAdClick(client: SupabaseClient, storeId: string, placement: "home" | "search") {
  await client.rpc("food_ad_click", { p_store_id: storeId, p_placement: placement });
}

export async function quoteFoodCustomerOrder(
  client: SupabaseClient,
  storeId: string,
  items: FoodCartLine[],
  location: FoodLocation | null = null,
): Promise<FoodOrderQuote> {
  const { data, error } = await client.rpc("food_quote_order", {
    // Coordinates are sent only when there is a pin, so this also works
    // against the pre-WYN-196 RPC signature during a rollout.
    ...pinParams(location),
    p_store_id: storeId,
    p_items: items.map((line) => ({
      menu_item_id: line.menu_item_id,
      quantity: line.quantity,
    })),
  });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<FoodOrderQuote>;
  return {
    subtotal: Number(raw.subtotal ?? 0),
    delivery_fee: Number(raw.delivery_fee ?? 0),
    campaign_discount: Number(raw.campaign_discount ?? 0),
    delivery_discount: Number(raw.delivery_discount ?? 0),
    total: Number(raw.total ?? 0),
    campaign_id: raw.campaign_id ? String(raw.campaign_id) : null,
    campaign_name: raw.campaign_name ? String(raw.campaign_name) : null,
    campaign_type: raw.campaign_type === "percentage" || raw.campaign_type === "fixed" || raw.campaign_type === "free_delivery"
      ? raw.campaign_type
      : null,
    delivery_distance_km: raw.delivery_distance_km == null ? null : Number(raw.delivery_distance_km),
    delivery_radius_km: raw.delivery_radius_km == null ? null : Number(raw.delivery_radius_km),
    delivery_needs_location: raw.delivery_needs_location === true,
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
    location: FoodLocation | null;
  },
) {
  const { data, error } = await client.rpc("food_create_order", {
    ...pinParams(input.location),
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
    ...pinParams(draft.location),
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
  if (message.includes("store is outside the service area")) return "ร้านนี้ยังไม่เปิดให้บริการในพื้นที่";
  if (message.includes("outside service area")) return "ตอนนี้ WYNOS Food ส่งได้เฉพาะในจังหวัดมหาสารคาม";
  if (message.includes("outside delivery area")) return "ที่อยู่นี้อยู่นอกพื้นที่จัดส่งของร้าน";
  if (message.includes("delivery location required")) return "กรุณาปักหมุดตำแหน่งที่อยู่จัดส่งก่อนสั่ง";
  if (message.includes("invalid delivery location")) return "ตำแหน่งที่อยู่ไม่ถูกต้อง ลองปักหมุดใหม่";
  return message || fallback;
}

/**
 * WYN-211: is this point inside the area WYNOS Food serves (Maha Sarakham)?
 * The server checks every quote and order again; this only drives the
 * introduction page for customers outside the area.
 */
export async function checkFoodServiceArea(client: SupabaseClient, location: FoodLocation) {
  const { data, error } = await client.rpc("food_service_area_check", { p_latitude: location.latitude, p_longitude: location.longitude });
  if (error) throw new Error(error.message);
  return data === true;
}

/** WYN-196: the phone's current position, for the delivery pin. */
export function currentFoodLocation(timeoutMs = 12000): Promise<FoodLocation> {
  return new Promise((resolve, reject) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      reject(new Error("อุปกรณ์นี้ไม่รองรับการระบุตำแหน่ง"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (position) => resolve({ latitude: position.coords.latitude, longitude: position.coords.longitude }),
      (error) => reject(new Error(
        error.code === error.PERMISSION_DENIED
          ? "กรุณาอนุญาตให้เข้าถึงตำแหน่งในเบราว์เซอร์"
          : "หาตำแหน่งปัจจุบันไม่สำเร็จ ลองใหม่หรือค้นหาสถานที่แทน",
      )),
      { enableHighAccuracy: true, timeout: timeoutMs, maximumAge: 60_000 },
    );
  });
}

export type FoodPlace = { name: string; address: string | null; latitude: number; longitude: number };

function parseMapPlaces(payload: unknown): FoodPlace[] {
  const results = Array.isArray((payload as { results?: unknown })?.results)
    ? (payload as { results: unknown[] }).results
    : [];
  return results.flatMap((row) => {
    const place = row as { name?: unknown; address?: unknown; lat?: unknown; lon?: unknown };
    const latitude = Number(place.lat);
    const longitude = Number(place.lon);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
    return [{
      name: typeof place.name === "string" ? place.name : "",
      address: typeof place.address === "string" ? place.address : null,
      latitude,
      longitude,
    }];
  }).slice(0, 8);
}

async function searchWynosMapsApi(query: string): Promise<FoodPlace[] | null> {
  try {
    const response = await fetch(`/api/maps/search?q=${encodeURIComponent(query.slice(0, 200))}`, {
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    if (response.status === 503) return null;
    if (!response.ok) throw new Error("WYNOS Maps search unavailable");
    return parseMapPlaces(await response.json());
  } catch {
    return null;
  }
}

async function reverseWynosMapsApi(location: FoodLocation): Promise<FoodPlace[] | null> {
  try {
    const response = await fetch(
      `/api/maps/reverse?lat=${encodeURIComponent(String(location.latitude))}&lon=${encodeURIComponent(String(location.longitude))}`,
      { headers: { Accept: "application/json" }, cache: "no-store" },
    );
    if (response.status === 503) return null;
    if (!response.ok) throw new Error("WYNOS Maps reverse unavailable");
    return parseMapPlaces(await response.json());
  } catch {
    return null;
  }
}

/**
 * Search WYNOS Geo first. During the self-hosted rollout only, fall back to the
 * legacy location-search Edge Function so delivery pinning never goes down.
 */
export async function searchFoodPlaces(client: SupabaseClient, query: string): Promise<FoodPlace[]> {
  const trimmed = query.trim();
  if (!trimmed) return [];

  const wynosResults = await searchWynosMapsApi(trimmed);
  if (wynosResults !== null) return wynosResults;

  const { data, error } = await client.functions.invoke("location-search", {
    body: { mode: "search", query: trimmed.slice(0, 200) },
  });
  if (error) throw new Error("ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองใช้ตำแหน่งปัจจุบันแทน");
  return parseMapPlaces(data);
}

/**
 * Reverse-geocode through WYNOS Geo first, with the legacy server-side proxy
 * kept only as a rollout fallback until the Thailand geocoder is online.
 */
export async function reverseFoodPlace(client: SupabaseClient, location: FoodLocation): Promise<FoodPlace | null> {
  const wynosResults = await reverseWynosMapsApi(location);
  if (wynosResults !== null) return wynosResults[0] ?? null;

  const { data, error } = await client.functions.invoke("location-search", {
    body: { mode: "reverse", lat: location.latitude, lon: location.longitude },
  });
  if (error) return null;
  return parseMapPlaces(data)[0] ?? null;
}


/**
 * WYN-197: free place search over the store's own list (food_store_places).
 * Returns null when the list is not available yet (migration not applied), so
 * the caller can fall back to the location-search Edge Function.
 */
export async function searchStorePlaces(client: SupabaseClient, storeId: string, query: string): Promise<FoodPlace[] | null> {
  const { data, error } = await client.rpc("food_search_store_places", {
    p_store_id: storeId,
    p_query: query.trim().slice(0, 100),
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    throw new Error(foodCustomerError(error, "ค้นหาสถานที่ไม่สำเร็จ"));
  }
  return ((data ?? []) as Array<{ name: string; detail: string | null; latitude: number; longitude: number }>).flatMap((row) => {
    const latitude = Number(row.latitude);
    const longitude = Number(row.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
    return [{ name: row.name, address: row.detail, latitude, longitude }];
  });
}

/**
 * WYN-197: read a pin pasted from a map app, e.g. "13.75631, 100.50176" or a
 * Google Maps link with "@13.75,100.50" or "q=13.75,100.50".
 */
export function parseFoodLocation(text: string): FoodLocation | null {
  const match = text.match(/(?:^|[^\d.])(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)(?![\d.])/);
  if (!match) return null;
  const latitude = Number(match[1]);
  const longitude = Number(match[2]);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
  return { latitude, longitude };
}

/** Straight-line distance in km, the same haversine formula as the server. */
export function foodDistanceKm(from: FoodLocation, to: FoodLocation) {
  const rad = (value: number) => (value * Math.PI) / 180;
  const dLat = rad(to.latitude - from.latitude);
  const dLng = rad(to.longitude - from.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(from.latitude)) * Math.cos(rad(to.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** A Google Maps link that opens at the exact pin when there is one. */
export function foodMapsHref(location: FoodLocation | null, fallbackAddress: string) {
  return location
    ? `https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}`
    : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(fallbackAddress)}`;
}
