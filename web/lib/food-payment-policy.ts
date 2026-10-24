/**
 * ZOKY Stripe-only payments + automatic refunds (Founder 2026-10-22).
 *
 * Everything the customer web needs to know about the cut-over policy. The
 * database is the authority (order creation, payment and refunds are all
 * enforced server-side); this only decides what to show. Every helper falls
 * back to the legacy behaviour when the backend RPCs do not exist yet, so the
 * web keeps working before the migration is applied.
 *
 * Kept free of `@/` imports so the logic can be unit-tested directly.
 */
import type { SupabaseClient } from "@supabase/supabase-js";

type RpcClient = Pick<SupabaseClient, "rpc">;
type FunctionsClient = Pick<SupabaseClient, "functions">;
type FromClient = Pick<SupabaseClient, "from">;

export type FoodCheckoutMethod = "promptpay" | "card";

export type FoodStorePaymentOption = {
  store_id: string;
  accepting_orders: boolean;
  promptpay: boolean;
  card: boolean;
};

export type FoodRefundStatus = "none" | "pending" | "refunded" | "failed";

/** D3: a customer cannot cancel once Stripe has taken the payment. */
export const FOOD_CANCEL_ALREADY_PAID_COPY = "ชำระเงินแล้ว ยกเลิกไม่ได้ ติดต่อร้าน";
export const FOOD_STORE_NOT_ACCEPTING_COPY = "ร้านนี้ยังไม่เปิดรับออเดอร์";
export const FOOD_STORE_NOT_ACCEPTING_TAG = "ยังไม่เปิดรับ";
/** Under the policy PromptPay is the only method (Founder 2026-10-23), so there is no fallback to offer. */
export const FOOD_PROMPTPAY_UNAVAILABLE_COPY = "ร้านนี้ยังไม่เปิดรับชำระเงินด้วยพร้อมเพย์ กรุณาติดต่อร้าน";
/** Founder 2026-10-23: customers pay only by PromptPay QR through Stripe while the policy is on. */
export const FOOD_PROMPTPAY_OPTION_COPY = "จ่ายด้วยพร้อมเพย์ (QR)";
/** Founder request: the payee name customers see in their banking app for a Stripe PromptPay QR. */
export const FOOD_PROMPTPAY_PAYEE_NOTE = "ชื่อผู้รับในแอปธนาคารจะเป็น STRIPE PAYMENTS (THAILAND)";
export const FOOD_PROMPTPAY_ONLY_COPY = "ZOKY รับชำระด้วยพร้อมเพย์เท่านั้น";
export const FOOD_STRIPE_ONLY_PAYMENTS_COPY = "ออเดอร์นี้ชำระผ่านพร้อมเพย์ (Stripe) เท่านั้น ไม่รับสลิปหรือการยืนยันเอง";

export const FOOD_PAYMENT_POLICY_UNAVAILABLE_COPY = "ระบบชำระเงินขัดข้องชั่วคราว ตอนนี้ชำระได้เฉพาะพร้อมเพย์ผ่าน Stripe";

/**
 * food_payment_policy_public() as the web sees it (ZOKY-157):
 * - "stripe_only": the policy is on.
 * - "legacy": the policy is off, or the database has no such function yet
 *   (PGRST202, or 42883 from Postgres = migration not applied).
 * - "unavailable": any other error (5xx, timeout, offline). The caller must
 *   fail closed: never show the store's own QR/slip upload on a guess.
 * An answer of an unexpected shape counts as off, as on the server.
 */
export type FoodPaymentPolicyState = "stripe_only" | "legacy" | "unavailable";

export async function fetchFoodPaymentPolicyState(client: RpcClient): Promise<FoodPaymentPolicyState> {
  try {
    const { data, error } = await client.rpc("food_payment_policy_public");
    if (error) {
      const code = (error as { code?: unknown }).code;
      return code === "PGRST202" || code === "42883" ? "legacy" : "unavailable";
    }
    if (data === true) return "stripe_only";
    const row = Array.isArray(data) ? data[0] : data;
    return row && typeof row === "object" && (row as { stripe_only?: unknown }).stripe_only === true ? "stripe_only" : "legacy";
  } catch {
    return "unavailable";
  }
}

/**
 * What the customer payment UI does for a policy state: anything but a
 * confirmed "legacy" shows the Stripe-only UI (no store QR, no slips).
 * `unavailable` = show the outage note and read the policy again later.
 */
export function foodPaymentGateForPolicy(state: FoodPaymentPolicyState): { stripeOnly: boolean; unavailable: boolean } {
  return { stripeOnly: state !== "legacy", unavailable: state === "unavailable" };
}

/**
 * true = Stripe-only is on (merchant web). Only a confirmed "stripe_only"
 * counts; the server and the database enforce the policy again, and the
 * customer web uses fetchFoodPaymentPolicyState() to fail closed.
 */
export async function fetchFoodPaymentPolicy(client: RpcClient): Promise<boolean> {
  return (await fetchFoodPaymentPolicyState(client)) === "stripe_only";
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Per-store payment options for the given stores. null = not available
 * (missing RPC or error): callers treat every store as accepting (legacy).
 * Stores missing from the answer are left out of the map (unknown).
 */
export async function fetchStorePaymentOptions(
  client: RpcClient,
  storeIds: readonly string[],
): Promise<Map<string, FoodStorePaymentOption> | null> {
  const ids = Array.from(new Set(storeIds.filter((id) => typeof id === "string" && UUID_PATTERN.test(id))));
  if (!ids.length) return new Map();
  try {
    const { data, error } = await client.rpc("food_store_payment_options", { p_store_ids: ids });
    if (error || !Array.isArray(data)) return null;
    const options = new Map<string, FoodStorePaymentOption>();
    for (const raw of data as Array<Record<string, unknown>>) {
      if (!raw || typeof raw.store_id !== "string") continue;
      options.set(raw.store_id, {
        store_id: raw.store_id,
        accepting_orders: raw.accepting_orders !== false,
        promptpay: raw.promptpay === true,
        card: raw.card !== false,
      });
    }
    return options;
  } catch {
    return null;
  }
}

/**
 * The store cannot take new orders only when the policy is on AND the server
 * said so for this store: it is not accepting orders, or (PromptPay-only,
 * Founder 2026-10-23) its Stripe account has no PromptPay. Unknown or
 * unavailable options never block; the server checks again at checkout.
 */
export function foodStoreNotAccepting(
  stripeOnly: boolean,
  options: ReadonlyMap<string, FoodStorePaymentOption> | null | undefined,
  storeId: string | null | undefined,
): boolean {
  if (!stripeOnly || !storeId || !options) return false;
  const option = options.get(storeId);
  if (!option) return false;
  return option.accepting_orders === false || option.promptpay !== true;
}

/**
 * The JSON body of an Edge Function response. supabase-js returns a non-2xx
 * body only through `error.context` (a Response), so read it from there.
 */
export async function foodEdgePayload(error: unknown, data: unknown): Promise<Record<string, unknown> | null> {
  if (!error && data && typeof data === "object") return data as Record<string, unknown>;
  const context = (error as { context?: unknown } | null | undefined)?.context;
  if (context && typeof (context as Response).clone === "function") {
    try {
      const body = await (context as Response).clone().json();
      return body && typeof body === "object" ? body as Record<string, unknown> : null;
    } catch {
      return null;
    }
  }
  return data && typeof data === "object" ? data as Record<string, unknown> : null;
}

/** Thai copy for a food-stripe-checkout failure. */
export function foodStripeCheckoutErrorCopy(payload: Record<string, unknown> | null): string {
  const code = typeof payload?.error === "string" ? payload.error : "";
  if (code === "stripe_not_ready") return "ร้านยังไม่พร้อมรับชำระผ่าน Stripe";
  if (code === "stripe_not_configured") return "Stripe ยังไม่ได้เปิดใช้งานบน ZOKY";
  if (code === "order_not_payable") return "ออเดอร์นี้ไม่อยู่ในสถานะที่ชำระผ่าน Stripe ได้";
  if (code === "promptpay_unavailable") return FOOD_PROMPTPAY_UNAVAILABLE_COPY;
  if (code === "payment_already_completed") return "ชำระเงินแล้ว กำลังอัปเดตสถานะออเดอร์";
  if (code === "store_not_accepting_orders") return FOOD_STORE_NOT_ACCEPTING_COPY;
  if (code === "promptpay_only") return FOOD_PROMPTPAY_ONLY_COPY;
  if (code === "invalid_payment_method") return "วิธีชำระเงินไม่ถูกต้อง กรุณาเลือกใหม่อีกครั้ง";
  if (typeof payload?.message === "string" && payload.message) return payload.message;
  return "เปิดหน้าชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง";
}

/**
 * Before a customer cancels an order with a Stripe Checkout session, close
 * the session at Stripe so the cancelled order can no longer be paid.
 * - "expired": the session is closed (or there was nothing open).
 * - "none": the order has no session.
 * - "paid": Stripe already took the payment; do not cancel (D3).
 * - "failed": could not check Stripe; the caller still cancels, and the
 *   server backstops (session expiry + automatic refund of a late payment).
 */
export type FoodStripeCancelResult = "expired" | "none" | "paid" | "failed";

export async function cancelFoodStripeCheckout(client: FunctionsClient, orderId: string): Promise<FoodStripeCancelResult> {
  try {
    const { data, error } = await client.functions.invoke("food-stripe-cancel", {
      body: { orderId, reason: "order_cancelled" },
    });
    const payload = await foodEdgePayload(error, data);
    if (payload?.error === "stripe_payment_already_completed") return "paid";
    if (error) return "failed";
    if (payload?.cancelled === true) return "expired";
    if (payload?.reason === "no_stripe_session") return "none";
    return "failed";
  } catch {
    return "failed";
  }
}

export type FoodRefundNotice = { tone: "info" | "success" | "warn"; title: string; detail: string };

/**
 * Backend contract (wynteam-payjobs migration 20261023100000, ZOKY-147/148):
 * - `food_orders.refund_awaiting_customer` (boolean, existing order RLS; the
 *   web already selects `*`): true while Stripe waits for the customer to
 *   enter the bank account for a PromptPay refund (Stripe emails them).
 * - `food_order_events` written by the refund job, readable by the buyer and
 *   the store through the existing order RLS; `refund_needs_attention` means
 *   the job is parked for the ZOKY team.
 * Before that migration the column is absent (= false) and there are no such
 * events, so every helper here falls back to the generic copy.
 */
export function foodRefundAwaitingCustomer(order: { refund_awaiting_customer?: unknown }): boolean {
  return order.refund_awaiting_customer === true;
}

/** Event types the automatic refund job writes to food_order_events. */
export const FOOD_AUTO_REFUND_EVENT_TYPES = [
  "refund_auto_queued",
  "refund_requested",
  "refund_awaiting_customer",
  "refund_not_final",
  "refund_failed",
  "refund_retry_requested",
  "refund_needs_attention",
  "refund_refunded",
] as const;

export type FoodAutoRefundSignals = {
  /** An automatic refund job exists for the order (ZOKY-149). */
  jobExists: boolean;
  /** The latest job event parks it for the ZOKY team (ZOKY-148). */
  needsAttention: boolean;
};

/**
 * Reads the automatic refund signals from the order's own events. null =
 * could not tell (table/RLS error, offline): callers keep their default.
 */
export async function fetchFoodAutoRefundSignals(client: FromClient, orderId: string): Promise<FoodAutoRefundSignals | null> {
  try {
    const { data, error } = await client
      .from("food_order_events")
      .select("event_type")
      .eq("order_id", orderId)
      .in("event_type", [...FOOD_AUTO_REFUND_EVENT_TYPES])
      .order("created_at", { ascending: false })
      .order("id", { ascending: false })
      .limit(20);
    if (error || !Array.isArray(data)) return null;
    const latest = (data[0] as { event_type?: unknown } | undefined)?.event_type;
    return { jobExists: data.length > 0, needsAttention: latest === "refund_needs_attention" };
  } catch {
    return null;
  }
}

/**
 * The merchant must not start a second Stripe refund by hand (ZOKY-149) when
 * an automatic refund exists: a job event, Stripe waiting for the customer,
 * or a refund that Stripe already holds for this pending order.
 */
export function foodAutoRefundActive(
  order: { refund_status?: string | null; stripe_refund_id?: string | null; refund_awaiting_customer?: unknown },
  signals: FoodAutoRefundSignals | null,
): boolean {
  if (foodRefundAwaitingCustomer(order) || signals?.jobExists === true) return true;
  return order.refund_status === "pending" && Boolean(order.stripe_refund_id);
}

export const FOOD_REFUND_PROMPTPAY_EMAIL_COPY = "กรุณาตรวจอีเมลจาก Stripe เพื่อกรอกเลขบัญชีที่ใช้จ่าย หากไม่ได้กรอก การคืนเงินอาจไม่สำเร็จ";
export const FOOD_REFUND_NEEDS_ATTENTION_COPY = "การคืนเงินต้องตรวจสอบ ติดต่อทีม ZOKY";

/**
 * What the customer sees about a refund on an order, or null for none.
 * Under the policy every Stripe payment is PromptPay (Founder 2026-10-23),
 * so a pending Stripe refund always says to check Stripe's email. With the
 * policy off the method is unknown to the web, so the copy covers both.
 */
export function foodRefundNotice(
  order: {
    refund_status?: FoodRefundStatus | string | null;
    payment_status?: string | null;
    payment_provider?: string | null;
    refund_awaiting_customer?: unknown;
  },
  options: { stripeOnly?: boolean } = {},
): FoodRefundNotice | null {
  const status = order.refund_status ?? "none";
  const stripe = order.payment_provider === "stripe";
  if (status === "failed") {
    return {
      tone: "warn",
      title: "คืนเงินมีปัญหา ติดต่อร้าน",
      detail: stripe
        ? "คืนเงินผ่าน Stripe ไม่สำเร็จ ถ้าชำระด้วยพร้อมเพย์ อาจเป็นเพราะยังไม่ได้กรอกเลขบัญชีในอีเมลจาก Stripe กรุณาติดต่อร้าน"
        : "ระบบคืนเงินไม่สำเร็จ กรุณาติดต่อร้านเพื่อดำเนินการคืนเงิน",
    };
  }
  if (status === "refunded" || order.payment_status === "refunded") {
    return { tone: "success", title: "คืนเงินแล้ว", detail: "คืนเงินเต็มจำนวนเข้าช่องทางที่คุณชำระแล้ว ระยะเวลาเงินเข้าขึ้นกับธนาคารหรือผู้ออกบัตร" };
  }
  if (status === "pending") {
    if (!stripe) return { tone: "info", title: "กำลังคืนเงิน", detail: "ร้านจะโอนเงินคืนให้คุณ" };
    if (options.stripeOnly === true || foodRefundAwaitingCustomer(order)) {
      return { tone: "info", title: "กำลังคืนเงิน", detail: FOOD_REFUND_PROMPTPAY_EMAIL_COPY };
    }
    return {
      tone: "info",
      title: "กำลังคืนเงิน",
      detail: "คืนเงินเต็มจำนวนผ่าน Stripe · ชำระด้วยพร้อมเพย์: กรุณาตรวจอีเมลจาก Stripe เพื่อกรอกเลขบัญชีที่ใช้จ่าย · ชำระด้วยบัตร: อาจใช้ 5–10 วันทำการ",
    };
  }
  return null;
}

export type MerchantAutoRefundView = {
  /** Status chip. */
  label: string;
  /** Body lines, in order. */
  lines: string[];
  /** The merchant can ask the server to requeue a failed automatic refund. */
  canRetry: boolean;
  /** The refund is parked for the ZOKY team (ZOKY-148). */
  needsAttention: boolean;
};

/** Copy for the merchant's automatic refund box (Stripe orders). */
export function merchantAutoRefundView(
  order: { refund_status?: string | null; refund_awaiting_customer?: unknown },
  stripeOnly: boolean,
  needsAttention = false,
): MerchantAutoRefundView {
  const status = order.refund_status ?? "none";
  if (status === "refunded") return { label: "คืนเงินแล้ว", lines: [], canRetry: false, needsAttention: false };
  if (status === "failed") {
    return {
      label: "คืนเงินไม่สำเร็จ",
      lines: [
        "คืนเงินอัตโนมัติไม่สำเร็จ สาเหตุที่พบบ่อย: ลูกค้าที่ชำระด้วยพร้อมเพย์ยังไม่ได้กรอกเลขบัญชีในอีเมลจาก Stripe หรือยอดเงินในบัญชี Stripe ของร้านไม่พอ",
        "กดลองอีกครั้งเพื่อส่งคำขอคืนเงินใหม่ ถ้าลูกค้าชำระด้วยพร้อมเพย์ ลูกค้าอาจต้องกรอกเลขบัญชีในอีเมลจาก Stripe อีกครั้ง",
      ],
      canRetry: true,
      needsAttention: false,
    };
  }
  if (status === "pending") {
    if (needsAttention) {
      return { label: "ต้องตรวจสอบ", lines: [FOOD_REFUND_NEEDS_ATTENTION_COPY], canRetry: false, needsAttention: true };
    }
    const hands = "ระบบดำเนินการคืนเงินให้ ไม่ต้องกดคืนเงินเอง หากค้างนานผิดปกติ ติดต่อทีม ZOKY";
    if (foodRefundAwaitingCustomer(order)) {
      return { label: "รอลูกค้า", lines: ["รอลูกค้ากรอกเลขบัญชีที่ใช้จ่ายในอีเมลจาก Stripe เงินจะคืนหลังลูกค้ากรอกแล้ว", hands], canRetry: false, needsAttention: false };
    }
    const detail = stripeOnly
      ? "ลูกค้าชำระด้วยพร้อมเพย์ ลูกค้าต้องกรอกเลขบัญชีที่ใช้จ่ายในอีเมลจาก Stripe ก่อนเงินจะคืน"
      : "ถ้าลูกค้าชำระด้วยพร้อมเพย์ ลูกค้าต้องกรอกเลขบัญชีที่ใช้จ่ายในอีเมลจาก Stripe ก่อนเงินจะคืน";
    return { label: "กำลังคืนเงิน", lines: [detail, hands], canRetry: false, needsAttention: false };
  }
  return { label: "ยังไม่เริ่ม", lines: [], canRetry: false, needsAttention: false };
}
