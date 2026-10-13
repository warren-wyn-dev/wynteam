import type { SupabaseClient } from "@supabase/supabase-js";
import type { DateRange } from "@/lib/merchant-finance";

export type MerchantOrderPerformanceSummary = {
  from: string;
  to: string;
  totalOrders: number;
  completedOrders: number;
  cancelledOrders: number;
  acceptanceEligibleOrders: number;
  acceptedOrders: number;
  acceptanceRate: number | null;
  merchantCancelledOrders: number;
  merchantCancelRate: number | null;
  unattributedCancelledOrders: number;
  preparationSamples: number;
  averagePreparationMinutes: number | null;
  topItems: { menuItemId: string | null; itemName: string; quantity: number; orders: number }[];
};

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function number(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : 0;
}

function nullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

/** A disabled/unapplied additive feature hides its card without touching finance. */
export async function fetchMerchantOrderPerformance(
  client: SupabaseClient, storeId: string, range: DateRange,
): Promise<MerchantOrderPerformanceSummary | null> {
  const { data, error } = await client.rpc("merchant_order_performance", {
    p_store_id: storeId, p_from: range.from, p_to: range.to,
  });
  if (error) {
    if (error.message.includes("merchant performance is not enabled") || error.code === "PGRST202") return null;
    throw new Error(error.message);
  }
  const raw = record(data);
  return {
    from: String(raw.from ?? range.from), to: String(raw.to ?? range.to),
    totalOrders: number(raw.total_orders), completedOrders: number(raw.completed_orders),
    cancelledOrders: number(raw.cancelled_orders), acceptanceEligibleOrders: number(raw.acceptance_eligible_orders),
    acceptedOrders: number(raw.accepted_orders), acceptanceRate: nullableNumber(raw.acceptance_rate),
    merchantCancelledOrders: number(raw.merchant_cancelled_orders), merchantCancelRate: nullableNumber(raw.merchant_cancel_rate),
    unattributedCancelledOrders: number(raw.unattributed_cancelled_orders), preparationSamples: number(raw.preparation_samples),
    averagePreparationMinutes: nullableNumber(raw.average_preparation_minutes),
    topItems: Array.isArray(raw.top_items) ? raw.top_items.map((item) => {
      const row = record(item);
      return { menuItemId: row.menu_item_id == null ? null : String(row.menu_item_id),
        itemName: String(row.item_name ?? ""), quantity: number(row.quantity), orders: number(row.orders) };
    }) : [],
  };
}

export function merchantOrderPerformanceError(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  if (message.includes("merchant manager access required")) return "เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่ดูรายงานได้";
  if (message.includes("invalid date range")) return "ช่วงวันที่ไม่ถูกต้อง";
  if (message.includes("date range is too long")) return "เลือกช่วงวันที่ได้ไม่เกิน 366 วัน";
  return "โหลดสถิติคำสั่งซื้อไม่สำเร็จ กรุณาลองอีกครั้ง";
}
