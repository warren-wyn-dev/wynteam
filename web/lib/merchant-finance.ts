import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * WYN-210: finance summary for any date range
 * (supabase/migrations_wynos_merchant_finance_v1.sql). Every number is worked
 * out on the server from the store's own orders, ad clicks and WYNOS campaign
 * shares; the page only formats it.
 */
export type FinanceDay = {
  day: string;
  orders: number;
  food: number;
  delivery: number;
  discounts: number;
  refunds: number;
  sales_net: number;
  ad_spend: number;
  platform_funded: number;
  income: number;
};

export type FinanceSummary = Omit<FinanceDay, "day"> & {
  from: string;
  to: string;
  refund_count: number;
  prev_sales_net: number;
  prev_orders: number;
  days: FinanceDay[];
  pending_slip_count: number;
  pending_slip_total: number;
  platform_owed: number;
};

export type FinancePeriod = "today" | "yesterday" | "week" | "month" | "custom";
export type DateRange = { from: string; to: string };

const NUMBER_KEYS = ["orders", "food", "delivery", "discounts", "refunds", "sales_net", "ad_spend", "platform_funded", "income"] as const;

function toDay(raw: Record<string, unknown>): FinanceDay {
  const day = { day: String(raw.day ?? "") } as FinanceDay;
  NUMBER_KEYS.forEach((key) => { day[key] = Number(raw[key] ?? 0); });
  return day;
}

export async function fetchFinanceSummary(client: SupabaseClient, storeId: string, range: DateRange): Promise<FinanceSummary> {
  const { data, error } = await client.rpc("merchant_finance_summary", { p_store_id: storeId, p_from: range.from, p_to: range.to });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Record<string, unknown>;
  return {
    ...toDay(raw),
    from: String(raw.from ?? range.from),
    to: String(raw.to ?? range.to),
    refund_count: Number(raw.refund_count ?? 0),
    prev_sales_net: Number(raw.prev_sales_net ?? 0),
    prev_orders: Number(raw.prev_orders ?? 0),
    days: Array.isArray(raw.days) ? (raw.days as Record<string, unknown>[]).map(toDay) : [],
    pending_slip_count: Number(raw.pending_slip_count ?? 0),
    pending_slip_total: Number(raw.pending_slip_total ?? 0),
    platform_owed: Number(raw.platform_owed ?? 0),
  };
}

export function financeError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("merchant manager access required")) return "เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่ดูการเงินได้";
  if (message.includes("date range is too long")) return "เลือกได้ไม่เกิน 1 ปี";
  if (message.includes("invalid date range")) return "ช่วงวันที่ไม่ถูกต้อง";
  if (message.includes("merchant_finance_summary") || message.includes("Could not find the function")) return "ระบบการเงินยังไม่เปิดใช้งาน";
  return message || "โหลดข้อมูลการเงินไม่สำเร็จ";
}

/** Today's date in Bangkok as YYYY-MM-DD, the day the server counts in. */
export function bangkokToday(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Bangkok", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
}

/** Calendar maths on YYYY-MM-DD strings (UTC noon avoids DST edges). */
export function addDays(day: string, amount: number) {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
}

export function daysBetween(from: string, to: string) {
  return Math.round((Date.parse(`${to}T12:00:00Z`) - Date.parse(`${from}T12:00:00Z`)) / 86_400_000) + 1;
}

export function periodRange(period: Exclude<FinancePeriod, "custom">, today = bangkokToday()): DateRange {
  if (period === "today") return { from: today, to: today };
  if (period === "yesterday") { const day = addDays(today, -1); return { from: day, to: day }; }
  if (period === "week") {
    // Weeks start on Monday, like the reports page.
    const weekday = (new Date(`${today}T12:00:00Z`).getUTCDay() + 6) % 7;
    return { from: addDays(today, -weekday), to: today };
  }
  return { from: `${today.slice(0, 8)}01`, to: today };
}

const THAI_DAY = new Intl.DateTimeFormat("th-TH", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
const THAI_DAY_SHORT = new Intl.DateTimeFormat("th-TH", { day: "numeric", month: "short", timeZone: "UTC" });

export function thaiDay(day: string, withYear = true) {
  return (withYear ? THAI_DAY : THAI_DAY_SHORT).format(new Date(`${day}T12:00:00Z`));
}

export function rangeLabel(range: DateRange) {
  if (range.from === range.to) return thaiDay(range.from);
  return `${thaiDay(range.from, range.from.slice(0, 4) !== range.to.slice(0, 4))} – ${thaiDay(range.to)}`;
}

/** Percent change from the previous period of the same length; null when there is nothing to compare. */
export function changePercent(current: number, previous: number) {
  if (!previous) return null;
  return Math.round(((current - previous) / Math.abs(previous)) * 100);
}

const CSV_COLUMNS: [keyof FinanceDay, string][] = [
  ["day", "วันที่"],
  ["orders", "ออเดอร์"],
  ["food", "ค่าอาหาร"],
  ["delivery", "ค่าส่ง"],
  ["discounts", "ส่วนลดโปรโมชั่น"],
  ["refunds", "คืนเงินลูกค้า"],
  ["sales_net", "ยอดขายสุทธิ"],
  ["ad_spend", "ค่าโฆษณา"],
  ["platform_funded", "WYNOS ช่วยจ่ายส่วนลด"],
  ["income", "รายได้ร้าน"],
];

/** One row per day plus a total row. UTF-8 with BOM so Excel shows Thai. */
export function financeCsv(summary: FinanceSummary) {
  const cell = (value: string | number) => (typeof value === "number" ? value.toFixed(2).replace(/\.00$/, "") : `"${value.replace(/"/g, '""')}"`);
  const rows = summary.days.map((day) => CSV_COLUMNS.map(([key]) => cell(day[key])).join(","));
  const total = CSV_COLUMNS.map(([key]) => (key === "day" ? cell("รวม") : cell(summary[key] as number))).join(",");
  return `\uFEFF${[CSV_COLUMNS.map(([, label]) => cell(label)).join(","), ...rows, total].join("\r\n")}\r\n`;
}
