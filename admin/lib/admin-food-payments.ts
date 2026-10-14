import { createClient } from "@/lib/supabase/server";

export const FOOD_MONITOR_FILTERS = {
  all: "ทั้งหมด",
  review: "ควรตรวจสอบ",
  refund: "การคืนเงิน",
  paid: "ชำระแล้ว",
  dispute: "มีเหตุการณ์ข้อพิพาท",
} as const;

export const FOOD_MONITOR_FLAGS: Record<string, string> = {
  ledger_missing: "ไม่พบรายการในบัญชี Stripe",
  amount_mismatch: "ยอดเงิน สกุลเงิน หรือร้านไม่ตรงกัน",
  state_mismatch: "สถานะออเดอร์กับบัญชี Stripe ไม่ตรงกัน",
  refund_failed: "คืนเงินไม่สำเร็จ",
  refund_waiting_24h: "รอคืนเงินเกิน 24 ชั่วโมง",
  payment_waiting_24h: "รอชำระหรือตรวจสอบเกิน 24 ชั่วโมง",
  cancelled_paid: "ยกเลิกแล้วและยังเป็นยอดชำระแล้ว",
  refund_event_review: "ได้รับเหตุการณ์คืนเงินไม่สำเร็จ",
  dispute_event_review: "ได้รับเหตุการณ์ข้อพิพาท ต้องตรวจสอบกับ Stripe",
};

export type FoodPaymentMonitorRow = {
  order_id: string;
  order_number: string;
  store_id: string;
  store_name: string;
  order_status: string;
  payment_status: string;
  refund_status: string;
  provider: "stripe" | "manual";
  expected_satang: number;
  ledger_amount_satang: number | null;
  ledger_status: string | null;
  ledger_currency: string | null;
  created_at: string;
  updated_at: string;
  refund_requested_at: string | null;
  refunded_at: string | null;
  latest_webhook_at: string | null;
  latest_refund_event: string | null;
  latest_dispute_event: string | null;
  flags: string[];
};

type FoodObservationPage = {
  total_count: number;
  page_size: number;
  offset: number;
  as_of: string;
};

export type FoodPaymentMonitor = FoodObservationPage & {
  rows: FoodPaymentMonitorRow[];
  review_count: number;
  from: string;
  to: string;
  reconciliation: "database_only";
};

export type FoodCustomerSummary = {
  buyer_id: string;
  customer_label: string;
  order_count: number;
  paid_order_count: number;
  refunded_order_count: number;
  cancelled_order_count: number;
  paid_order_value: number | null;
  last_order_at: string;
};

export type FoodCustomerOrder = {
  order_id: string;
  order_number: string;
  store_id: string;
  store_name: string;
  order_status: string;
  payment_status: string;
  refund_status: string;
  total: number;
  created_at: string;
};

export type FoodCustomerHistory = FoodObservationPage & {
  customers: FoodCustomerSummary[];
  orders: FoodCustomerOrder[];
  customer_label?: string;
};

export type FoodObservationSearch = Record<string, string | string[] | undefined>;

export function observationText(value: string | string[] | undefined): string {
  return (Array.isArray(value) ? value[0] : value)?.trim() ?? "";
}

export function observationPage(value: string | string[] | undefined): number {
  const raw = observationText(value);
  if (!/^\d+$/.test(raw)) return 1;
  return Math.max(1, Math.min(4001, Number(raw)));
}

export function foodHistoryBuyer(value: string): string | null {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value) ? value : null;
}

export function foodMonitorDates(from: string, to: string) {
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Bangkok", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  const start = new Date(`${today}T00:00:00Z`);
  start.setUTCDate(start.getUTCDate() - 29);
  const result = { from: from || start.toISOString().slice(0, 10), to: to || today };
  for (const value of Object.values(result)) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value))
      || new Date(value).toISOString().slice(0, 10) !== value) throw new Error("invalid_dates");
  }
  const days = (Date.parse(result.to) - Date.parse(result.from)) / 86_400_000;
  if (days < 0 || days > 365) throw new Error("invalid_dates");
  return result;
}

/** Errors stay errors: a missing deployment/API never becomes a zero balance. */
function validateObservationPage(data: unknown): asserts data is FoodObservationPage {
  if (!data || typeof data !== "object" || !Number.isInteger((data as FoodObservationPage).total_count)
    || (data as FoodObservationPage).total_count < 0 || !(data as FoodObservationPage).as_of) {
    throw new Error("invalid_observation_response");
  }
}

export async function fetchFoodPaymentMonitor(params: {
  query: string; filter: keyof typeof FOOD_MONITOR_FILTERS; provider: string;
  from: string; to: string; page: number;
}): Promise<FoodPaymentMonitor> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_food_payment_monitor", {
    p_query: params.query || null, p_filter: params.filter, p_provider: params.provider || null,
    p_from: params.from, p_to: params.to, p_limit: 25, p_offset: (params.page - 1) * 25,
  }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  validateObservationPage(data);
  if (!Array.isArray((data as FoodPaymentMonitor).rows)) throw new Error("invalid_observation_response");
  return data as FoodPaymentMonitor;
}

export async function fetchFoodCustomerHistory(params: {
  buyerId: string | null; query: string; page: number;
}): Promise<FoodCustomerHistory> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_food_customer_history", {
    p_buyer_id: params.buyerId, p_query: params.query || null, p_limit: 25, p_offset: (params.page - 1) * 25,
  }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  validateObservationPage(data);
  const history = data as FoodCustomerHistory;
  if (!Array.isArray(history.customers) || !Array.isArray(history.orders)) throw new Error("invalid_observation_response");
  return history;
}

export function foodObservationError(error: unknown): string {
  if ((error as { code?: string } | null)?.code === "PGRST202") return "กำลังรอติดตั้ง API ของหน้านี้ ยังไม่สามารถแสดงข้อมูลได้";
  return "โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่ หรือตรวจสอบสิทธิ์และการเชื่อมต่อ";
}
