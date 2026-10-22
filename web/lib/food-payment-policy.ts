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
export const FOOD_PROMPTPAY_UNAVAILABLE_COPY = "ร้านนี้ยังไม่รองรับพร้อมเพย์ กรุณาเลือกบัตรเครดิต/เดบิต";

/**
 * true = Stripe-only is on. A missing RPC (older database), an error or any
 * unexpected shape means false: the legacy payment UI stays.
 */
export async function fetchFoodPaymentPolicy(client: RpcClient): Promise<boolean> {
  try {
    const { data, error } = await client.rpc("food_payment_policy_public");
    if (error) return false;
    if (data === true) return true;
    const row = Array.isArray(data) ? data[0] : data;
    return Boolean(row && typeof row === "object" && (row as { stripe_only?: unknown }).stripe_only === true);
  } catch {
    return false;
  }
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
 * said so for this store. Unknown or unavailable options never block.
 */
export function foodStoreNotAccepting(
  stripeOnly: boolean,
  options: ReadonlyMap<string, FoodStorePaymentOption> | null | undefined,
  storeId: string | null | undefined,
): boolean {
  if (!stripeOnly || !storeId || !options) return false;
  return options.get(storeId)?.accepting_orders === false;
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

/** What the customer sees about a refund on an order, or null for none. */
export function foodRefundNotice(order: {
  refund_status?: FoodRefundStatus | string | null;
  payment_status?: string | null;
  payment_provider?: string | null;
}): FoodRefundNotice | null {
  const status = order.refund_status ?? "none";
  if (status === "failed") {
    return { tone: "warn", title: "คืนเงินมีปัญหา ติดต่อร้าน", detail: "ระบบคืนเงินไม่สำเร็จ กรุณาติดต่อร้านเพื่อดำเนินการคืนเงิน" };
  }
  if (status === "refunded" || order.payment_status === "refunded") {
    return { tone: "success", title: "คืนเงินแล้ว", detail: "คืนเงินเต็มจำนวนเข้าช่องทางที่คุณชำระแล้ว ระยะเวลาเงินเข้าขึ้นกับธนาคารหรือผู้ออกบัตร" };
  }
  if (status === "pending") {
    return order.payment_provider === "stripe"
      ? { tone: "info", title: "กำลังคืนเงิน", detail: "ระบบกำลังคืนเงินเต็มจำนวนเข้าช่องทางที่คุณชำระโดยอัตโนมัติ" }
      : { tone: "info", title: "กำลังคืนเงิน", detail: "ร้านจะโอนเงินคืนให้คุณ" };
  }
  return null;
}
