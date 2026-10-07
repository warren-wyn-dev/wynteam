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

export type MerchantStripeStatus = {
  connected: boolean;
  status: "not_connected" | "onboarding" | "pending" | "ready" | "restricted";
  details_submitted?: boolean;
  charges_enabled?: boolean;
  payouts_enabled?: boolean;
  promptpay_enabled?: boolean;
  promptpay_status?: "active" | "pending" | "inactive" | "unsupported" | "unrequested" | "unknown";
  bank_ready?: boolean;
  bank_name?: string | null;
  bank_last4?: string | null;
  payout_interval?: "daily" | "weekly" | "monthly" | "manual" | "unknown";
  requirements_due_count?: number;
  last_synced_at?: string | null;
};

export type MerchantPaymentSurface = MerchantStripeStatus & {
  surface?: "embedded" | "redirect" | "none" | "unavailable";
  client_secret?: string;
  publishable_key?: string;
  url?: string;
  message?: string;
};

export type MerchantStripeFinance = MerchantStripeStatus & {
  pending: number;
  available: number;
  paid_today: number;
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

export async function fetchMerchantStripeStatus(client: SupabaseClient, storeId: string): Promise<MerchantStripeStatus> {
  const { data, error } = await client.rpc("merchant_stripe_status", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  return (data ?? { connected: false, status: "not_connected" }) as MerchantStripeStatus;
}

async function merchantStripeFunctionError(error: unknown, fallback: string) {
  const raw = error as { context?: unknown } | null;
  const context = raw && typeof raw === "object" ? raw.context : null;
  if (context instanceof Response) {
    try {
      const payload = await context.clone().json() as { error?: unknown; message?: unknown };
      if (typeof payload.message === "string" && /[ก-๙]/.test(payload.message)) return payload.message;
      if (typeof payload.error === "string") {
        if (payload.error === "payments_not_configured" || payload.error === "payments_backend_not_ready") {
          return "ระบบรับชำระเงินยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง";
        }
        if (payload.error === "unauthorized") return "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง";
        if (payload.error === "owner_or_admin_required") return "เฉพาะเจ้าของร้านหรือแอดมินเท่านั้นที่จัดการการรับเงินได้";
        if (payload.error === "store_not_found") return "ไม่พบร้านที่เลือก กรุณาเลือกร้านใหม่แล้วลองอีกครั้ง";
      }
    } catch {
      // Never surface gateway or technical detail to the Merchant UI.
    }
  }
  return fallback;
}

async function invokeMerchantPayments(
  client: SupabaseClient,
  storeId: string,
  action: "status" | "onboard" | "manage" | "finance",
) {
  const { data, error } = await client.functions.invoke("merchant-stripe-connect", {
    body: { storeId, action },
  });
  if (error) {
    throw new Error(await merchantStripeFunctionError(
      error,
      action === "finance"
        ? "โหลดข้อมูลการรับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง"
        : action === "status"
          ? "อัปเดตสถานะการรับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง"
          : "เปิดหน้าตั้งค่ารับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
    ));
  }
  return data;
}

function paymentSurface(payload: unknown): MerchantPaymentSurface {
  if (!payload || typeof payload !== "object") throw new Error("เปิดหน้าตั้งค่ารับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
  const value = payload as MerchantPaymentSurface;
  if (typeof value.status !== "string") throw new Error("เปิดหน้าตั้งค่ารับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
  return value;
}

export async function startMerchantStripeOnboarding(client: SupabaseClient, storeId: string) {
  return paymentSurface(await invokeMerchantPayments(client, storeId, "onboard"));
}

export async function startMerchantPaymentManagement(client: SupabaseClient, storeId: string) {
  return paymentSurface(await invokeMerchantPayments(client, storeId, "manage"));
}

export async function createMerchantStripeSession(
  client: SupabaseClient,
  storeId: string,
  component: "account_onboarding" | "account_management",
) {
  const payload = paymentSurface(await invokeMerchantPayments(
    client,
    storeId,
    component === "account_management" ? "manage" : "onboard",
  ));
  if (payload.surface !== "embedded" || typeof payload.client_secret !== "string" || typeof payload.publishable_key !== "string") {
    throw new Error(payload.message || "ไม่สามารถเปิดแบบฟอร์มรับเงินในหน้านี้ได้ กรุณาลองใหม่อีกครั้ง");
  }
  return { clientSecret: payload.client_secret, publishableKey: payload.publishable_key };
}

export async function refreshMerchantStripeStatus(client: SupabaseClient, storeId: string): Promise<MerchantStripeStatus> {
  const payload = paymentSurface(await invokeMerchantPayments(client, storeId, "status"));
  return payload;
}

export async function fetchMerchantStripeFinance(client: SupabaseClient, storeId: string): Promise<MerchantStripeFinance> {
  const payload = paymentSurface(await invokeMerchantPayments(client, storeId, "finance")) as MerchantPaymentSurface & {
    pending?: unknown;
    available?: unknown;
    paid_today?: unknown;
  };
  return {
    ...payload,
    pending: typeof payload.pending === "number" ? payload.pending : 0,
    available: typeof payload.available === "number" ? payload.available : 0,
    paid_today: typeof payload.paid_today === "number" ? payload.paid_today : 0,
  };
}

export async function requestStripeRefund(client: SupabaseClient, orderId: string, note?: string) {
  const { data, error } = await client.functions.invoke("merchant-stripe-refund", {
    body: { orderId, note: note?.trim() || null },
  });
  if (error) throw new Error(await merchantStripeFunctionError(error, "ขอคืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง"));
  const payload = data as { status?: unknown } | null;
  if (!payload || typeof payload.status !== "string") throw new Error("ขอคืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
  return String(payload.status);
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
