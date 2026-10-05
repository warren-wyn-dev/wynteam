import type { SupabaseClient } from "@supabase/supabase-js";

export type MerchantStaffRole = "owner" | "admin" | "manager" | "orders" | "support" | "delivery";

export type MerchantStaffMember = {
  user_id: string;
  username: string | null;
  display_name: string | null;
  role: MerchantStaffRole;
  active: boolean;
  created_at: string;
  updated_at: string;
};

export type MerchantNotification = {
  id: string;
  merchant_account_id: string;
  recipient_user_id: string;
  type: "system" | "order" | "payment" | "staff";
  reason: string;
  read_at: string | null;
  created_at: string;
};

export type MerchantActivity = {
  id: string;
  merchant_account_id: string;
  actor_id: string | null;
  actor_username_snapshot: string | null;
  action: string;
  target_type: string;
  target_id: string | null;
  detail: Record<string, unknown>;
  created_at: string;
};

export type MerchantStoreReadiness = {
  ready: boolean;
  missing: string[];
};

export type MerchantStoreReview = {
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

export type MerchantStoreReviewFeed = {
  average: number;
  count: number;
  unanswered: number;
  reviews: MerchantStoreReview[];
};

export async function fetchMerchantStaff(client: SupabaseClient, storeId: string) {
  const { data, error } = await client.rpc("merchant_staff_members", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  return (data ?? []) as MerchantStaffMember[];
}

export async function addMerchantStaff(
  client: SupabaseClient,
  storeId: string,
  username: string,
  role: Exclude<MerchantStaffRole, "owner">,
) {
  const clean = username.trim().replace(/^@/, "");
  if (!clean) throw new Error("กรุณาใส่ @username ของบัญชี WYNOS");
  const { data, error } = await client.rpc("merchant_add_staff_by_username", {
    p_store_id: storeId,
    p_username: clean,
    p_role: role,
  });
  if (error) throw new Error(error.message);
  return String(data);
}

export async function updateMerchantStaff(
  client: SupabaseClient,
  storeId: string,
  userId: string,
  role: Exclude<MerchantStaffRole, "owner">,
  active: boolean,
) {
  const { error } = await client.rpc("merchant_update_staff_member", {
    p_store_id: storeId,
    p_user_id: userId,
    p_role: role,
    p_active: active,
  });
  if (error) throw new Error(error.message);
}

export async function fetchMerchantNotifications(
  client: SupabaseClient,
  merchantAccountId: string,
  limit = 30,
) {
  const { data, error } = await client
    .from("merchant_notifications")
    .select("*")
    .eq("merchant_account_id", merchantAccountId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data ?? []) as MerchantNotification[];
}

export async function markMerchantNotificationRead(client: SupabaseClient, id: string) {
  const { error } = await client
    .from("merchant_notifications")
    .update({ read_at: new Date().toISOString() })
    .eq("id", id);
  if (error) throw new Error(error.message);
}

export async function markAllMerchantNotificationsRead(client: SupabaseClient, merchantAccountId: string) {
  const { error } = await client
    .from("merchant_notifications")
    .update({ read_at: new Date().toISOString() })
    .eq("merchant_account_id", merchantAccountId)
    .is("read_at", null);
  if (error) throw new Error(error.message);
}

export async function fetchMerchantActivity(
  client: SupabaseClient,
  merchantAccountId: string,
  limit = 30,
) {
  const { data, error } = await client
    .from("merchant_activity_log")
    .select("*")
    .eq("merchant_account_id", merchantAccountId)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data ?? []) as MerchantActivity[];
}

export async function fetchStoreReadiness(client: SupabaseClient, storeId: string) {
  const { data, error } = await client.rpc("merchant_store_readiness", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<MerchantStoreReadiness>;
  return {
    ready: raw.ready === true,
    missing: Array.isArray(raw.missing) ? raw.missing.map(String) : [],
  } satisfies MerchantStoreReadiness;
}

export async function fetchMerchantStoreReviews(
  client: SupabaseClient,
  storeId: string,
  limit = 50,
): Promise<MerchantStoreReviewFeed | null> {
  const { data, error } = await client.rpc("merchant_store_reviews", {
    p_store_id: storeId,
    p_limit: limit,
  });
  if (error) {
    if (error.code === "PGRST202" || error.code === "42883") return null;
    throw new Error(error.message);
  }
  if (!data || typeof data !== "object") return { average: 0, count: 0, unanswered: 0, reviews: [] };
  const raw = data as { average?: unknown; count?: unknown; unanswered?: unknown; reviews?: unknown };
  const reviews = Array.isArray(raw.reviews)
    ? raw.reviews.map((row) => {
        const review = row as Partial<MerchantStoreReview>;
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
        } satisfies MerchantStoreReview;
      }).filter((review) => review.id && review.rating >= 1 && review.rating <= 5)
    : [];
  return {
    average: Number(raw.average ?? 0),
    count: Number(raw.count ?? 0),
    unanswered: Number(raw.unanswered ?? 0),
    reviews,
  };
}

export async function replyMerchantStoreReview(
  client: SupabaseClient,
  reviewId: string,
  reply: string,
) {
  const clean = reply.trim();
  if (!clean) throw new Error("กรุณาเขียนคำตอบก่อนส่ง");
  const { error } = await client.rpc("food_reply_store_review", {
    p_review_id: reviewId,
    p_reply: clean,
  });
  if (error) throw new Error(error.message);
}

export async function setMerchantStorePublished(
  client: SupabaseClient,
  storeId: string,
  published: boolean,
) {
  if (published) {
    const readiness = await fetchStoreReadiness(client, storeId);
    if (!readiness.ready) {
      throw new Error(`ร้านยังไม่พร้อมเผยแพร่: ${readiness.missing.join(", ")}`);
    }
  }
  const { error } = await client.from("food_stores").update({ is_published: published }).eq("id", storeId);
  if (error) throw new Error(error.message);
}

export async function setMerchantRefundStatus(
  client: SupabaseClient,
  orderId: string,
  status: "pending" | "refunded" | "failed",
  note?: string,
) {
  const { error } = await client.rpc("merchant_set_refund_status", {
    p_order_id: orderId,
    p_status: status,
    p_note: note?.trim() || null,
  });
  if (error) throw new Error(error.message);
}


export const MERCHANT_NOTIFICATION_TEST_RESULT_KEY = "wynos.merchant.notification-test.result.v1";

export type MerchantNotificationTestReceipt = {
  merchant_notification_id: string;
  push_notification_id: string;
  created_at: string;
};

export type MerchantPushDelivery = {
  id: string;
  notification_id: string;
  platform: string;
  status: string;
  attempt_count: number;
  last_error: string | null;
  sent_at: string | null;
  updated_at: string;
};

export async function sendMerchantTestNotification(
  client: SupabaseClient,
  storeId: string,
): Promise<MerchantNotificationTestReceipt> {
  const { data, error } = await client.rpc("merchant_send_test_notification", {
    p_store_id: storeId,
  });
  if (error) {
    if (error.message.includes("notification_test_rate_limited")) {
      throw new Error("กรุณารอสักครู่ก่อนทดสอบอีกครั้ง");
    }
    throw new Error(error.message);
  }
  const raw = (data ?? {}) as Partial<MerchantNotificationTestReceipt>;
  if (!raw.merchant_notification_id || !raw.push_notification_id || !raw.created_at) {
    throw new Error("ทดสอบการแจ้งเตือนไม่สำเร็จ");
  }
  return {
    merchant_notification_id: String(raw.merchant_notification_id),
    push_notification_id: String(raw.push_notification_id),
    created_at: String(raw.created_at),
  };
}

export async function fetchMerchantNotificationById(
  client: SupabaseClient,
  id: string,
): Promise<MerchantNotification | null> {
  const { data, error } = await client
    .from("merchant_notifications")
    .select("*")
    .eq("id", id)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data as MerchantNotification | null) ?? null;
}

export async function fetchMerchantPushDeliveries(
  client: SupabaseClient,
  notificationId: string,
): Promise<MerchantPushDelivery[]> {
  const { data, error } = await client
    .from("notification_push_deliveries")
    .select("id,notification_id,platform,status,attempt_count,last_error,sent_at,updated_at")
    .eq("notification_id", notificationId)
    .eq("platform", "web")
    .order("updated_at", { ascending: false });
  if (error) throw new Error(error.message);
  return (data ?? []) as MerchantPushDelivery[];
}

export async function countMerchantWebPushTokens(
  client: SupabaseClient,
  userId: string,
): Promise<number> {
  const { count, error } = await client
    .from("push_tokens")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("platform", "web");
  if (error) throw new Error(error.message);
  return count ?? 0;
}
