import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { withoutLocation } from "@/lib/image-location";
import { imageUploadType } from "@/lib/upload-image";
import type { FoodBusinessSchedule } from "@/lib/food-store-availability";

export { orderDeliveryProof } from "@/lib/food-delivery-proof";

export type FoodCustomerStore = {
  id: string;
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
  /** WYN-196: pinned store location. Null keeps the flat delivery fee. */
  latitude?: number | null;
  longitude?: number | null;
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
  scheduled_orders_enabled?: boolean;
  scheduled_min_notice_minutes?: number;
  scheduled_max_days?: number;
  is_open: boolean;
  is_published: boolean;
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

export type FoodMenuOptionSelection = {
  group_id: string;
  group_name?: string;
  choice_id: string;
  choice_name?: string;
  price?: number | string;
};

export type FoodCustomerMenuItem = {
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
  /** Best-effort live stock remaining for today; null means unlimited, undefined means unsupported/unknown. */
  remaining_stock?: number | null;
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
  selected_options: FoodMenuOptionSelection[];
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
  scheduled_for?: string | null;
  receipt_legal_name?: string | null;
  receipt_tax_id?: string | null;
  receipt_tax_branch?: string | null;
  receipt_tax_address?: string | null;
  created_at: string;
  updated_at: string;
  food_order_items?: FoodCustomerOrderItem[];
  food_delivery_proofs?: FoodCustomerDeliveryProof | FoodCustomerDeliveryProof[] | null;
};



export type FoodCustomerOwnReview = {
  review_id: string;
  order_id: string;
  store_id: string;
  rating: number;
  created_at: string;
};

export type FoodStoreReview = {
  id: string;
  rating: number;
  review_text: string | null;
  tags: string[];
  reviewer_label: string;
  verified_order: boolean;
  created_at: string;
  merchant_reply: string | null;
  merchant_replied_at: string | null;
};

export type FoodStoreReviewFeed = {
  average: number;
  count: number;
  reviews: FoodStoreReview[];
};

export const FOOD_REVIEW_TAGS = ["อร่อย", "ปริมาณดี", "แพ็กดี", "ตรงปก", "คุ้มราคา", "ส่งเร็ว"] as const;

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
  place_id?: string | null;
  place_name?: string | null;
  building_name?: string | null;
  floor?: string | null;
  room?: string | null;
  landmark?: string | null;
  address_line1?: string | null;
  moo?: string | null;
  soi?: string | null;
  road?: string | null;
  subdistrict?: string | null;
  district?: string | null;
  province?: string | null;
  postal_code?: string | null;
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
  /** Server accepts group_id + choice_id and re-resolves names/prices itself. */
  selected_options?: FoodMenuOptionSelection[];
};

export function foodCartLineKey(line: Pick<FoodCartLine, "menu_item_id" | "note" | "selected_options">) {
  const options = [...(line.selected_options ?? [])]
    .map((option) => `${option.group_id}:${option.choice_id}`)
    .sort()
    .join("|");
  return `${line.menu_item_id}::${options}::${line.note.trim()}`;
}

export function foodCartLineOptionText(
  line: Pick<FoodCartLine, "selected_options">,
  item?: Pick<FoodCustomerMenuItem, "options"> | null,
) {
  return (line.selected_options ?? [])
    .map((option) => {
      const group = item?.options?.find((row) => row.id === option.group_id);
      const choice = group?.choices?.find((row) => row.id === option.choice_id);
      return choice?.name?.trim() || option.choice_name?.trim();
    })
    .filter((value): value is string => Boolean(value))
    .join(" · ");
}

export function foodCartLineOptionsValid(
  item: Pick<FoodCustomerMenuItem, "options">,
  line: Pick<FoodCartLine, "selected_options">,
) {
  const groups = Array.isArray(item.options) ? item.options : [];
  const selected = line.selected_options ?? [];
  const seen = new Set<string>();

  for (const option of selected) {
    const key = `${option.group_id}:${option.choice_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    const group = groups.find((row) => row.id === option.group_id);
    if (!group || !group.choices.some((choice) => choice.id === option.choice_id)) return false;
  }

  return groups.every((group) => {
    const count = selected.filter((option) => option.group_id === group.id).length;
    const max = Math.max(1, Math.min(20, Number(group.max_select ?? 1)));
    return (!group.required || count > 0) && count <= max;
  });
}

export function foodCartLineUnitPrice(
  item: Pick<FoodCustomerMenuItem, "price" | "options">,
  line: Pick<FoodCartLine, "selected_options">,
) {
  const surcharge = (line.selected_options ?? []).reduce((sum, option) => {
    const group = item.options?.find((row) => row.id === option.group_id);
    const choice = group?.choices?.find((row) => row.id === option.choice_id);
    return sum + Math.max(0, Number(choice?.price ?? 0));
  }, 0);
  return Number(item.price) + surcharge;
}

export function foodMenuQuantityLimit(item: Pick<FoodCustomerMenuItem, "daily_stock_limit" | "remaining_stock">) {
  const configured = item.daily_stock_limit == null ? 99 : Math.max(0, Number(item.daily_stock_limit));
  const remaining = item.remaining_stock == null ? configured : Math.max(0, Number(item.remaining_stock));
  return Math.max(0, Math.min(99, configured, remaining));
}

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
  has_more_orders: boolean;
  addresses: FoodCustomerAddress[];
  ownReviews: FoodCustomerOwnReview[];
};

export type FoodAddressDraft = {
  id?: string | null;
  label: string;
  recipientName: string;
  recipientPhone: string;
  /** Legacy/full formatted address kept for rollout compatibility. */
  address: string;
  addressLine1: string;
  moo: string;
  soi: string;
  road: string;
  subdistrict: string;
  district: string;
  province: string;
  postalCode: string;
  deliveryNote: string;
  placeId: string | null;
  placeName: string;
  buildingName: string;
  floor: string;
  room: string;
  landmark: string;
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

export const FOOD_CUSTOMER_ORDER_PAGE_SIZE = 100;

export async function fetchFoodCustomerOrdersPage(
  client: SupabaseClient,
  userId: string,
  offset = 0,
  limit = FOOD_CUSTOMER_ORDER_PAGE_SIZE,
): Promise<{ orders: FoodCustomerOrder[]; hasMore: boolean }> {
  const safeOffset = Math.max(0, Math.floor(offset));
  const safeLimit = Math.max(1, Math.min(250, Math.floor(limit)));
  const { data, error } = await client
    .from("food_orders")
    .select("*,food_order_items(*),food_delivery_proofs(*)")
    .eq("buyer_id", userId)
    .order("created_at", { ascending: false })
    .range(safeOffset, safeOffset + safeLimit);
  if (error) throw new Error(error.message);
  const rows = (data ?? []) as FoodCustomerOrder[];
  return { orders: rows.slice(0, safeLimit), hasMore: rows.length > safeLimit };
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
  if (!developer && access.error) throw new Error(access.error.message);
  if (!developer && access.data !== true) {
    return { allowed: false, developer: false, store: null, menu: [], orders: [], has_more_orders: false, addresses: [], ownReviews: [] };
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
  const [menuResult, orderPage, addressesResult, ownReviewsResult, stockResult] = await Promise.all([
    store
      ? client
          .from("food_menu_items")
          .select("*")
          .eq("store_id", store.id)
          .order("sort_order", { ascending: true })
          .order("created_at", { ascending: true })
      : Promise.resolve({ data: [], error: null }),
    fetchFoodCustomerOrdersPage(client, userId),
    client
      .from("food_customer_addresses")
      .select("*")
      .eq("user_id", userId)
      .order("is_default", { ascending: false })
      .order("created_at", { ascending: false }),
    client.rpc("food_my_store_reviews"),
    store
      ? client.rpc("food_menu_stock_remaining", { p_store_id: store.id })
      : Promise.resolve({ data: [], error: null }),
  ]);

  if (menuResult.error) throw new Error(menuResult.error.message);
  if (addressesResult.error) throw new Error(addressesResult.error.message);

  const stockRows = !stockResult.error && Array.isArray(stockResult.data)
    ? stockResult.data as Array<{ menu_item_id?: unknown; remaining_stock?: unknown }>
    : [];
  const remainingByMenu = new Map(
    stockRows
      .map((row) => [String(row.menu_item_id ?? ""), row.remaining_stock == null ? null : Number(row.remaining_stock)] as const)
      .filter(([id, remaining]) => id && (remaining === null || Number.isFinite(remaining))),
  );
  const menu = ((menuResult.data ?? []) as FoodCustomerMenuItem[]).map((item) => ({
    ...item,
    remaining_stock: remainingByMenu.has(item.id) ? remainingByMenu.get(item.id)! : undefined,
  }));

  return {
    allowed: true,
    developer,
    store,
    menu,
    orders: orderPage.orders,
    has_more_orders: orderPage.hasMore,
    addresses: (addressesResult.data ?? []) as FoodCustomerAddress[],
    ownReviews: ownReviewsResult.error ? [] : (ownReviewsResult.data ?? []) as FoodCustomerOwnReview[],
  };
}

export function maskFoodReviewerName(name: string) {
  const firstWord = name.trim().split(/\s+/)[0] ?? "";
  if (!firstWord) return "ผู้ใช้ WYNOS Food";
  const segments = typeof Intl.Segmenter === "function"
    ? Array.from(new Intl.Segmenter("th", { granularity: "grapheme" }).segment(firstWord), (part) => part.segment)
    : Array.from(firstWord);
  if (segments.length === 1) return `${segments[0]}***`;
  if (segments.length === 2) return `${segments[0]}**${segments[1]}`;
  return `${segments[0]}${"*".repeat(Math.min(4, Math.max(2, segments.length - 2)))}${segments.at(-1)}`;
}

export async function fetchFoodStoreReviewFeed(
  client: SupabaseClient,
  storeId: string,
  limit = 20,
): Promise<FoodStoreReviewFeed> {
  const { data, error } = await client.rpc("food_store_review_feed", {
    p_store_id: storeId,
    p_limit: limit,
  });
  if (error || !data || typeof data !== "object") {
    return { average: 0, count: 0, reviews: [] };
  }
  const raw = data as { average?: unknown; count?: unknown; reviews?: unknown };
  const reviews = Array.isArray(raw.reviews)
    ? raw.reviews.map((row) => {
        const review = row as Partial<FoodStoreReview>;
        return {
          id: String(review.id ?? ""),
          rating: Number(review.rating ?? 0),
          review_text: typeof review.review_text === "string" ? review.review_text : null,
          tags: Array.isArray(review.tags) ? review.tags.map(String) : [],
          reviewer_label: typeof review.reviewer_label === "string" ? review.reviewer_label : "ผู้ใช้ WYNOS Food",
          verified_order: review.verified_order === true,
          created_at: typeof review.created_at === "string" ? review.created_at : new Date(0).toISOString(),
          merchant_reply: typeof review.merchant_reply === "string" ? review.merchant_reply : null,
          merchant_replied_at: typeof review.merchant_replied_at === "string" ? review.merchant_replied_at : null,
        } satisfies FoodStoreReview;
      }).filter((review) => review.id && review.rating >= 1 && review.rating <= 5)
    : [];
  return {
    average: Number(raw.average ?? 0),
    count: Number(raw.count ?? 0),
    reviews,
  };
}

export async function submitFoodStoreReview(
  client: SupabaseClient,
  input: {
    orderId: string;
    rating: number;
    reviewText?: string;
    tags: string[];
    anonymous: boolean;
  },
) {
  const { data, error } = await client.rpc("food_submit_store_review", {
    p_order_id: input.orderId,
    p_rating: input.rating,
    p_review_text: input.reviewText?.trim() || null,
    p_tags: input.tags,
    p_anonymous: input.anonymous,
  });
  if (error) throw new Error(error.message);
  return String(data);
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
  address?: string | null;
  business_hours: string | null;
  delivery_fee: number | string;
  latitude?: number | null;
  longitude?: number | null;
  prep_time_min_minutes?: number | null;
  prep_time_max_minutes?: number | null;
  categories?: string[] | null;
  rating_average?: number | string | null;
  rating_count?: number | string | null;
  delivered_order_count?: number | string | null;
  promo_name?: string | null;
  promo_type?: "percentage" | "fixed" | "free_delivery" | string | null;
  promo_value?: number | string | null;
  promo_min_subtotal?: number | string | null;
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
      selected_options: line.selected_options ?? [],
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
    scheduledFor?: string | null;
  },
) {
  const params = {
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
      selected_options: line.selected_options ?? [],
    })),
  };
  const { data, error } = input.scheduledFor
    ? await client.rpc("food_create_scheduled_order", { ...params, p_scheduled_for: input.scheduledFor })
    : await client.rpc("food_create_order", params);
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

export function foodStructuredAddressText(draft: Pick<FoodAddressDraft,
  "address" | "addressLine1" | "moo" | "soi" | "road" | "subdistrict" | "district" | "province" | "postalCode"
>) {
  const province = draft.province.trim();
  const bangkok = province === "กรุงเทพมหานคร" || province === "กรุงเทพฯ";
  const line1 = draft.addressLine1.trim() || draft.address.trim();
  return [
    line1,
    draft.moo.trim() ? `หมู่ ${draft.moo.trim()}` : "",
    draft.soi.trim() ? `ซอย ${draft.soi.trim()}` : "",
    draft.road.trim() ? `ถนน ${draft.road.trim()}` : "",
    draft.subdistrict.trim() ? `${bangkok ? "แขวง" : "ตำบล"} ${draft.subdistrict.trim()}` : "",
    draft.district.trim() ? `${bangkok ? "เขต" : "อำเภอ"} ${draft.district.trim()}` : "",
    province ? `จังหวัด ${province}` : "",
    draft.postalCode.trim(),
  ].filter(Boolean).join(" ");
}

export async function saveFoodCustomerAddress(
  client: SupabaseClient,
  draft: FoodAddressDraft,
) {
  const fullAddress = foodStructuredAddressText(draft);
  const v3 = await client.rpc("food_upsert_customer_address_v3", {
    p_address_id: draft.id ?? null,
    p_label: draft.label,
    p_recipient_name: draft.recipientName,
    p_recipient_phone: draft.recipientPhone,
    p_address_line1: draft.addressLine1 || draft.address,
    p_moo: draft.moo || null,
    p_soi: draft.soi || null,
    p_road: draft.road || null,
    p_subdistrict: draft.subdistrict || null,
    p_district: draft.district || null,
    p_province: draft.province || null,
    p_postal_code: draft.postalCode || null,
    p_delivery_note: draft.deliveryNote || null,
    p_is_default: draft.isDefault,
    p_latitude: draft.location?.latitude ?? null,
    p_longitude: draft.location?.longitude ?? null,
    p_place_id: draft.placeId || null,
    p_place_name: draft.placeName || null,
    p_building_name: draft.buildingName || null,
    p_floor: draft.floor || null,
    p_room: draft.room || null,
    p_landmark: draft.landmark || null,
  });
  if (!v3.error) return String(v3.data);
  if (v3.error.code !== "PGRST202" && v3.error.code !== "42883") throw new Error(v3.error.message);

  const v2Args = {
    p_address_id: draft.id ?? null,
    p_label: draft.label,
    p_recipient_name: draft.recipientName,
    p_recipient_phone: draft.recipientPhone,
    p_address: fullAddress,
    p_delivery_note: draft.deliveryNote || null,
    p_is_default: draft.isDefault,
    p_latitude: draft.location?.latitude ?? null,
    p_longitude: draft.location?.longitude ?? null,
    p_place_id: draft.placeId || null,
    p_place_name: draft.placeName || null,
    p_building_name: draft.buildingName || null,
    p_floor: draft.floor || null,
    p_room: draft.room || null,
    p_landmark: draft.landmark || null,
  };
  const v2 = await client.rpc("food_upsert_customer_address_v2", v2Args);
  if (!v2.error) return String(v2.data);
  if (v2.error.code !== "PGRST202" && v2.error.code !== "42883") throw new Error(v2.error.message);

  // Rollout fallback for an older database.
  const legacy = await client.rpc("food_upsert_customer_address", {
    p_address_id: draft.id ?? null,
    p_label: draft.label,
    p_recipient_name: draft.recipientName,
    p_recipient_phone: draft.recipientPhone,
    p_address: fullAddress,
    p_delivery_note: [
      draft.buildingName ? `อาคาร ${draft.buildingName}` : "",
      draft.floor ? `ชั้น ${draft.floor}` : "",
      draft.room ? `ห้อง ${draft.room}` : "",
      draft.landmark ? `จุดสังเกต ${draft.landmark}` : "",
      draft.deliveryNote,
    ].filter(Boolean).join(" · ") || null,
    p_is_default: draft.isDefault,
    ...pinParams(draft.location),
  });
  if (legacy.error) throw new Error(legacy.error.message);
  return String(legacy.data);
}

export type FoodDeliveryAvailability = {
  can_deliver: boolean;
  reason: "store_unavailable" | "outside_delivery_area" | "outside_service_area" | "location_required" | null;
  distance_km: number | null;
  delivery_fee: number | null;
  delivery_radius_km: number | null;
};

export async function checkFoodDeliveryAvailability(
  client: SupabaseClient,
  storeId: string,
  location: FoodLocation,
): Promise<FoodDeliveryAvailability | null> {
  const { data, error } = await client.rpc("food_delivery_availability", {
    p_store_id: storeId,
    p_latitude: location.latitude,
    p_longitude: location.longitude,
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    throw new Error(error.message);
  }
  const raw = (data ?? {}) as Partial<FoodDeliveryAvailability>;
  return {
    can_deliver: raw.can_deliver === true,
    reason: raw.reason ?? null,
    distance_km: raw.distance_km == null ? null : Number(raw.distance_km),
    delivery_fee: raw.delivery_fee == null ? null : Number(raw.delivery_fee),
    delivery_radius_km: raw.delivery_radius_km == null ? null : Number(raw.delivery_radius_km),
  };
}

export async function deleteFoodCustomerAddress(client: SupabaseClient, addressId: string) {
  const { error } = await client.rpc("food_delete_customer_address", {
    p_address_id: addressId,
  });
  if (error) throw new Error(error.message);
}

/**
 * Counts a just-created order as coming from a shared store link. Best
 * effort: before that migration the RPC is missing and nothing changes.
 */
export async function markFoodOrderFromShare(client: SupabaseClient, orderId: string) {
  await client.rpc("food_mark_order_from_share", { p_order_id: orderId });
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
  if (message.includes("store is closed")) return "ร้านปิดตามเวลา หรือปิดชั่วคราวในขณะนี้";
  if (message.includes("minimum order not met")) return "ยอดอาหารยังไม่ถึงขั้นต่ำของร้าน";
  if (message.includes("menu item is unavailable")) return "มีเมนูที่ไม่พร้อมขาย กรุณาตรวจตะกร้าอีกครั้ง";
  if (message.includes("menu item daily stock exceeded")) return "จำนวนเมนูที่เลือกเกินสต็อกที่เหลือสำหรับวันนี้ กรุณาตรวจตะกร้าอีกครั้ง";
  if (message.includes("required menu option missing")) return "กรุณาเลือกตัวเลือกที่จำเป็นของเมนูให้ครบ";
  if (message.includes("too many menu options selected")) return "เลือกตัวเลือกของเมนูเกินจำนวนที่ร้านกำหนด";
  if (message.includes("invalid menu option")) return "ตัวเลือกของเมนูเปลี่ยนแปลงแล้ว กรุณาเลือกใหม่อีกครั้ง";
  if (message.includes("scheduled time is too soon")) return "เวลาที่เลือกใกล้เกินไป กรุณาเลือกเวลาใหม่";
  if (message.includes("scheduled time is too far")) return "เวลาที่เลือกไกลเกินช่วงที่ร้านเปิดรับออเดอร์ล่วงหน้า";
  if (message.includes("store is closed at scheduled time")) return "ร้านปิดในวันหรือเวลาที่เลือก กรุณาเลือกเวลาใหม่";
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

export type WynosPlaceDetails = {
  placeId: string;
  entranceLatitude: number | null;
  entranceLongitude: number | null;
  pickupNote: string | null;
  merchantStoreId: string | null;
  storeSlug: string | null;
  storeLogoPath: string | null;
  storeCoverPath: string | null;
  isOpen: boolean | null;
};

export async function fetchWynosPlaceDetails(
  client: SupabaseClient,
  placeId: string,
): Promise<WynosPlaceDetails | null> {
  const { data, error } = await client.rpc("wynos_place_details", { p_place_id: placeId });
  if (error || !Array.isArray(data) || !data.length) return null;
  const row = data[0] as Record<string, unknown>;
  const entranceLatitude = row.entrance_latitude == null ? null : Number(row.entrance_latitude);
  const entranceLongitude = row.entrance_longitude == null ? null : Number(row.entrance_longitude);
  return {
    placeId: String(row.place_id ?? placeId),
    entranceLatitude: Number.isFinite(entranceLatitude) ? entranceLatitude : null,
    entranceLongitude: Number.isFinite(entranceLongitude) ? entranceLongitude : null,
    pickupNote: typeof row.pickup_note === "string" ? row.pickup_note : null,
    merchantStoreId: typeof row.merchant_store_id === "string" ? row.merchant_store_id : null,
    storeSlug: typeof row.store_slug === "string" ? row.store_slug : null,
    storeLogoPath: typeof row.store_logo_path === "string" ? row.store_logo_path : null,
    storeCoverPath: typeof row.store_cover_path === "string" ? row.store_cover_path : null,
    isOpen: typeof row.is_open === "boolean" ? row.is_open : null,
  };
}

export type FoodPlace = {
  placeId?: string | null;
  name: string;
  address: string | null;
  latitude: number;
  longitude: number;
  category?: string | null;
  verificationStatus?: string | null;
  merchantStoreId?: string | null;
  storeSlug?: string | null;
  isOpen?: boolean | null;
  deliveryRadiusKm?: number | null;
  distanceKm?: number | null;
  source?: "wynos" | "geo" | "legacy" | "osm" | "photon" | "store";
};

function parsePlaceRows(rows: unknown[], source: FoodPlace["source"], limit = 12): FoodPlace[] {
  return rows.flatMap((row) => {
    const place = row as {
      place_id?: unknown;
      placeId?: unknown;
      name?: unknown;
      address?: unknown;
      lat?: unknown;
      lon?: unknown;
      latitude?: unknown;
      longitude?: unknown;
      category?: unknown;
      verification_status?: unknown;
      merchant_store_id?: unknown;
      store_slug?: unknown;
      is_open?: unknown;
      delivery_radius_km?: unknown;
      distance_km?: unknown;
    };
    const latitude = Number(place.lat ?? place.latitude);
    const longitude = Number(place.lon ?? place.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
    return [{
      placeId: typeof place.place_id === "string"
        ? place.place_id
        : typeof place.placeId === "string"
          ? place.placeId
          : place.place_id != null
            ? String(place.place_id)
            : place.placeId != null
              ? String(place.placeId)
              : null,
      name: typeof place.name === "string" ? place.name : "",
      address: typeof place.address === "string" ? place.address : null,
      latitude,
      longitude,
      category: typeof place.category === "string" ? place.category : null,
      verificationStatus: typeof place.verification_status === "string" ? place.verification_status : null,
      merchantStoreId: typeof place.merchant_store_id === "string" ? place.merchant_store_id : null,
      storeSlug: typeof place.store_slug === "string" ? place.store_slug : null,
      isOpen: typeof place.is_open === "boolean" ? place.is_open : null,
      deliveryRadiusKm: place.delivery_radius_km == null || !Number.isFinite(Number(place.delivery_radius_km))
        ? null
        : Number(place.delivery_radius_km),
      distanceKm: place.distance_km == null || !Number.isFinite(Number(place.distance_km))
        ? null
        : Number(place.distance_km),
      source,
    }];
  }).slice(0, limit);
}

function parseMapPlaces(payload: unknown, source: FoodPlace["source"]): FoodPlace[] {
  const results = Array.isArray((payload as { results?: unknown })?.results)
    ? (payload as { results: unknown[] }).results
    : [];
  return parsePlaceRows(results, source);
}

async function reverseWynosPlace(
  client: SupabaseClient,
  location: FoodLocation,
): Promise<FoodPlace | null> {
  const { data, error } = await client.rpc("wynos_reverse_place", {
    p_latitude: location.latitude,
    p_longitude: location.longitude,
    p_max_distance_km: 0.12,
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    return null;
  }
  return parsePlaceRows(Array.isArray(data) ? data : [], "wynos", 1)[0] ?? null;
}

export async function fetchNearbyWynosPlaces(
  client: SupabaseClient,
  location: FoodLocation,
  radiusKm = 25,
): Promise<FoodPlace[]> {
  const { data, error } = await client.rpc("wynos_nearby_places", {
    p_latitude: location.latitude,
    p_longitude: location.longitude,
    p_radius_km: Math.min(Math.max(radiusKm, 1), 50),
    p_limit: 80,
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return [];
    return [];
  }
  return parsePlaceRows(Array.isArray(data) ? data : [], "wynos", 80);
}

async function searchWynosPlaces(
  client: SupabaseClient,
  query: string,
  location?: FoodLocation | null,
): Promise<FoodPlace[]> {
  const { data, error } = await client.rpc("wynos_search_places", {
    p_query: query.slice(0, 200),
    p_latitude: location?.latitude ?? null,
    p_longitude: location?.longitude ?? null,
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return [];
    return [];
  }
  return parsePlaceRows(Array.isArray(data) ? data : [], "wynos");
}

async function invokePublicMapsGeocoder(
  client: SupabaseClient,
  body:
    | { mode: "search"; query: string; lat?: number; lon?: number }
    | { mode: "reverse"; lat: number; lon: number },
): Promise<FoodPlace[] | null> {
  try {
    const { data, error } = await client.functions.invoke("wynos-maps-geocode", { body });
    if (error) return null;
    const provider = (data as { provider?: unknown } | null)?.provider;
    const source: FoodPlace["source"] =
      provider === "photon" ? "photon" :
      provider === "osm" ? "osm" :
      "legacy";
    return parseMapPlaces(data, source);
  } catch {
    return null;
  }
}

async function searchWynosMapsApi(query: string): Promise<FoodPlace[] | null> {
  try {
    const response = await fetch(`/api/maps/search?q=${encodeURIComponent(query.slice(0, 200))}`, {
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    if (response.status === 503) return null;
    if (!response.ok) throw new Error("WYNOS Maps search unavailable");
    return parseMapPlaces(await response.json(), "geo");
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
    return parseMapPlaces(await response.json(), "geo");
  } catch {
    return null;
  }
}

/**
 * WYNOS Places is searched first. WYNOS Geo is next, and the legacy
 * location-search Edge Function remains only as a rollout fallback.
 */
export async function searchFoodPlaces(
  client: SupabaseClient,
  query: string,
  location?: FoodLocation | null,
): Promise<FoodPlace[]> {
  const trimmed = query.trim();
  if (!trimmed) return [];

  const ownPlaces = await searchWynosPlaces(client, trimmed, location);
  if (ownPlaces.length) return ownPlaces;

  const wynosResults = await searchWynosMapsApi(trimmed);
  if (wynosResults?.length) return wynosResults;

  const publicFallback = await invokePublicMapsGeocoder(client, {
    mode: "search",
    query: trimmed.slice(0, 200),
    lat: location?.latitude,
    lon: location?.longitude,
  });
  if (publicFallback?.length) return publicFallback;

  // Signed-in compatibility fallback for the older location-search function.
  const { data, error } = await client.functions.invoke("location-search", {
    body: { mode: "search", query: trimmed.slice(0, 200) },
  });
  if (error) throw new Error("ค้นหาสถานที่ไม่สำเร็จตอนนี้ ลองใช้ตำแหน่งปัจจุบันแทน");
  return parseMapPlaces(data, "legacy");
}

/**
 * Reverse-geocode through WYNOS Geo first, with the legacy server-side proxy
 * kept only as a rollout fallback until the Thailand geocoder is online.
 */
export async function reverseFoodPlace(client: SupabaseClient, location: FoodLocation): Promise<FoodPlace | null> {
  const ownPlace = await reverseWynosPlace(client, location);
  if (ownPlace) return ownPlace;

  const wynosResults = await reverseWynosMapsApi(location);
  if (wynosResults?.length) return wynosResults[0];

  const publicFallback = await invokePublicMapsGeocoder(client, {
    mode: "reverse",
    lat: location.latitude,
    lon: location.longitude,
  });
  if (publicFallback?.length) return publicFallback[0];

  // Signed-in compatibility fallback for the older location-search function.
  const { data, error } = await client.functions.invoke("location-search", {
    body: { mode: "reverse", lat: location.latitude, lon: location.longitude },
  });
  if (error) return null;
  return parseMapPlaces(data, "legacy")[0] ?? null;
}


/**
 * WYN-197: free place search over the store's own list (food_store_places).
 * Returns null when the list is not available yet (migration not applied), so
 * the caller can fall back to the location-search Edge Function.
 */
export async function searchStorePlaces(client: SupabaseClient, storeId: string, query: string): Promise<FoodPlace[] | null> {
  const args = {
    p_store_id: storeId,
    p_query: query.trim().slice(0, 100),
  };

  const owned = await client.rpc("wynos_search_store_places", args);
  if (!owned.error) {
    return ((owned.data ?? []) as Array<{
      place_id: string | null;
      name: string;
      detail: string | null;
      latitude: number;
      longitude: number;
    }>).flatMap((row) => {
      const latitude = Number(row.latitude);
      const longitude = Number(row.longitude);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
      return [{
        placeId: row.place_id,
        name: row.name,
        address: row.detail,
        latitude,
        longitude,
        category: "pickup_point",
        verificationStatus: row.place_id ? "merchant_verified" : null,
        source: "store" as const,
      }];
    });
  }
  if (owned.error.code !== "PGRST202" && owned.error.code !== "42883") {
    throw new Error(foodCustomerError(owned.error, "ค้นหาสถานที่ไม่สำเร็จ"));
  }

  const { data, error } = await client.rpc("food_search_store_places", args);
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    throw new Error(foodCustomerError(error, "ค้นหาสถานที่ไม่สำเร็จ"));
  }
  return ((data ?? []) as Array<{ name: string; detail: string | null; latitude: number; longitude: number }>).flatMap((row) => {
    const latitude = Number(row.latitude);
    const longitude = Number(row.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return [];
    return [{ placeId: null, name: row.name, address: row.detail, latitude, longitude, source: "store" as const }];
  });
}

/**
 * WYN-197: read a pin pasted from a map app, e.g. "13.75631, 100.50176" or a
 * Google Maps link with "@13.75,100.50" or "q=13.75,100.50".
 */
export type WynosPlaceSuggestionInput = {
  name: string;
  category: "place" | "restaurant" | "store" | "building" | "residence" | "poi";
  address?: string;
  note?: string;
  location: FoodLocation;
};

export async function submitWynosPlaceSuggestion(
  client: SupabaseClient,
  input: WynosPlaceSuggestionInput,
): Promise<string> {
  const { data, error } = await client.rpc("submit_wynos_place_suggestion", {
    p_name: input.name.trim(),
    p_category: input.category,
    p_address: input.address?.trim() || null,
    p_note: input.note?.trim() || null,
    p_latitude: input.location.latitude,
    p_longitude: input.location.longitude,
  });
  if (error) {
    const message = error.message ?? "";
    if (message.includes("authentication required")) throw new Error("กรุณาเข้าสู่ระบบก่อนเพิ่มสถานที่");
    if (message.includes("daily suggestion limit reached")) throw new Error("วันนี้ส่งสถานที่ครบจำนวนแล้ว ลองใหม่พรุ่งนี้");
    if (message.includes("duplicate pending suggestion")) throw new Error("สถานที่นี้ถูกส่งเข้าตรวจสอบแล้ว");
    if (message.includes("place name is required")) throw new Error("กรุณาใส่ชื่อสถานที่");
    throw new Error(foodCustomerError(error, "ส่งสถานที่ไม่สำเร็จ"));
  }
  return String(data);
}

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
