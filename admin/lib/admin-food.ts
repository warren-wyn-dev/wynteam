import { createClient } from "@/lib/supabase/server";

/**
 * WYN-203: WYNOS Food / Merchant operations for WYN Admin. Every call goes
 * through a role-checked SECURITY DEFINER RPC
 * (supabase/migrations_wynos_admin_food_ops_v1.sql): store data for
 * admin + moderator, customer data and changes for admin only.
 */

export type AdminFoodOverview = {
  stores_total: number;
  stores_published: number;
  stores_open: number;
  stores_suspended: number;
  orders_today: number;
  sales_today: number;
  active_orders: number;
  days: Array<{ day: string; orders: number; sales: number }>;
};

export type AdminFoodStore = {
  id: string;
  name: string;
  slug: string;
  phone: string | null;
  is_open: boolean;
  is_published: boolean;
  admin_suspended_at: string | null;
  admin_suspended_reason: string | null;
  owner_username: string | null;
  staff_count: number;
  orders_total: number;
  orders_30d: number;
  sales_30d: number;
  active_orders: number;
  last_order_at: string | null;
  created_at: string;
};

export type AdminFoodTeamMember = {
  user_id: string;
  username: string | null;
  display_name: string | null;
  role: "owner" | "admin" | "manager" | "orders" | "support" | "delivery";
  active: boolean;
  created_at: string;
};

export type AdminFoodStoreDetail = {
  id: string;
  name: string;
  slug: string;
  phone: string | null;
  address: string | null;
  business_hours: string | null;
  is_open: boolean;
  is_published: boolean;
  admin_suspended_at: string | null;
  admin_suspended_reason: string | null;
  admin_suspended_by_username: string | null;
  created_at: string;
  orders_total: number;
  orders_30d: number;
  sales_30d: number;
  cancelled_30d: number;
  active_orders: number;
  team: AdminFoodTeamMember[];
};

export type AdminFoodOrderStatusFilter =
  | "active"
  | "pending_acceptance"
  | "preparing"
  | "ready_for_delivery"
  | "out_for_delivery"
  | "delivered"
  | "cancelled";

export type AdminFoodOrder = {
  id: string;
  order_number: string;
  store_id: string;
  store_name: string;
  status: string;
  payment_status: string;
  refund_status: string;
  recipient_name: string;
  recipient_phone: string;
  total: number;
  created_at: string;
  delivered_at: string | null;
};

export type AdminFoodOrderDetail = {
  order: Record<string, unknown> & {
    id: string;
    order_number: string;
    store_id: string;
    status: string;
    payment_status: string;
    refund_status: string;
    recipient_name: string;
    recipient_phone: string;
    shipping_address: string;
    customer_note: string | null;
    payment_slip_path: string | null;
    payment_note: string | null;
    subtotal: number;
    delivery_fee: number;
    total: number;
    created_at: string;
  };
  store_name: string | null;
  buyer_username: string | null;
  items: Array<{ item_name: string; quantity: number; unit_price: number; item_note: string | null }>;
  events: Array<{ event_type: string; from_status: string | null; to_status: string | null; note: string | null; actor_username: string | null; created_at: string }>;
  proof: { method: string; location_note: string | null; image_path: string | null; created_at: string } | null;
};

export async function fetchAdminFoodOverview(): Promise<AdminFoodOverview> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_overview");
  if (error) throw error;
  return data as AdminFoodOverview;
}

export async function fetchAdminFoodStores(query?: string): Promise<AdminFoodStore[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_stores", { p_query: query?.trim() || null });
  if (error) throw error;
  return (data ?? []) as AdminFoodStore[];
}

export async function fetchAdminFoodStoreDetail(storeId: string): Promise<AdminFoodStoreDetail | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_store_detail", { p_store_id: storeId });
  if (error) {
    if (error.message.includes("store not found")) return null;
    throw error;
  }
  return data as AdminFoodStoreDetail;
}

export async function fetchAdminFoodOrders(params: {
  storeId?: string;
  status?: AdminFoodOrderStatusFilter;
  query?: string;
  limit?: number;
}): Promise<AdminFoodOrder[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_orders", {
    p_store_id: params.storeId ?? null,
    p_status: params.status ?? null,
    p_query: params.query?.trim() || null,
    p_limit: params.limit ?? 100,
  });
  if (error) throw error;
  return (data ?? []) as AdminFoodOrder[];
}

/** Opening an order is written to the audit log by the RPC. */
export async function fetchAdminFoodOrderDetail(orderId: string): Promise<AdminFoodOrderDetail | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_order_detail", { p_order_id: orderId });
  if (error) {
    if (error.message.includes("order not found")) return null;
    throw error;
  }
  return data as AdminFoodOrderDetail;
}

/** Short-lived links to private evidence (the storage policy allows platform admins). */
export async function signAdminFoodEvidence(path: string | null | undefined): Promise<string | null> {
  if (!path) return null;
  const supabase = await createClient();
  const { data, error } = await supabase.storage.from("food-private").createSignedUrl(path, 600);
  if (error) return null;
  return data.signedUrl;
}

export const FOOD_ORDER_STATUS_LABEL: Record<string, string> = {
  pending_acceptance: "รอร้านรับ",
  preparing: "กำลังทำ",
  ready_for_delivery: "พร้อมส่ง",
  out_for_delivery: "กำลังส่ง",
  delivered: "ส่งแล้ว",
  cancelled: "ยกเลิก",
};

export const FOOD_PAYMENT_STATUS_LABEL: Record<string, string> = {
  pending: "รอชำระ",
  submitted: "รอตรวจสลิป",
  paid: "ชำระแล้ว",
  issue: "มีปัญหา",
  refunded: "คืนเงินแล้ว",
};

export const FOOD_TEAM_ROLE_LABEL: Record<AdminFoodTeamMember["role"], string> = {
  owner: "เจ้าของ",
  admin: "แอดมิน",
  manager: "ผู้จัดการ",
  orders: "รับออเดอร์",
  support: "ดูแลลูกค้า",
  delivery: "จัดส่ง",
};

export function formatBaht(value: number | string | null | undefined) {
  return `฿${Number(value ?? 0).toLocaleString("th-TH", { maximumFractionDigits: 2 })}`;
}

export function formatThaiDate(value: string | null | undefined) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Bangkok",
  }).format(new Date(value));
}
