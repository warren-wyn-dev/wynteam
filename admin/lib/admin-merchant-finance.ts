import { createClient } from "@/lib/supabase/server";

/**
 * WYNOS Merchant -> การเงินร้านค้า (Merchant Finance), read only.
 * One merchant:view RPC
 * (supabase/migrations/20261011120000_admin_merchant_finance_overview.sql)
 * using the same money lines as the store's own finance page (WYN-210).
 * There is no GP / commission yet: that needs Founder business decisions.
 */

export type MerchantFinanceStore = {
  store_id: string;
  store_name: string;
  is_published: boolean;
  suspended: boolean;
  orders: number;
  food: number;
  delivery: number;
  discounts: number;
  refund_count: number;
  refunds: number;
  sales_net: number;
  ad_spend: number;
  platform_funded: number;
  /** GP v1 (absent before 20261011140100 is applied). */
  gp?: number;
  gp_uncollected?: number;
  gp_rate_bp?: number;
  income: number;
  platform_owed: number;
  last_settled_at: string | null;
  stripe_status: "onboarding" | "pending" | "ready" | "restricted" | null;
  stripe_payouts_enabled: boolean | null;
  stripe_bank_last4: string | null;
  stripe_payout_interval: string | null;
  stripe_livemode: boolean | null;
};

export type MerchantFinancePayout = {
  payout_id: string;
  store_id: string;
  store_name: string;
  amount_satang: number;
  currency: string;
  status: "pending" | "in_transit" | "paid" | "failed" | "canceled";
  arrival_date: string | null;
  failure_code: string | null;
  stripe_created_at: string | null;
};

export type MerchantFinanceSettlement = {
  id: string;
  store_id: string;
  store_name: string;
  amount: number;
  order_count: number;
  reference: string;
  settled_by_username: string | null;
  created_at: string;
};

export type MerchantFinanceOverview = {
  from: string;
  to: string;
  totals: {
    stores: number;
    stores_with_sales: number;
    orders: number;
    food: number;
    delivery: number;
    discounts: number;
    refund_count: number;
    refunds: number;
    sales_net: number;
    ad_spend: number;
    platform_funded: number;
    gp?: number;
    gp_uncollected?: number;
    income: number;
    platform_owed: number;
    stores_payout_ready: number;
    stores_without_stripe: number;
  };
  stores: MerchantFinanceStore[];
  payout_status_counts: Partial<Record<MerchantFinancePayout["status"], number>>;
  payouts: MerchantFinancePayout[];
  settlements: MerchantFinanceSettlement[];
};

export async function fetchMerchantFinanceOverview(range: { from: string; to: string }): Promise<MerchantFinanceOverview> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_finance_overview", { p_from: range.from, p_to: range.to });
  if (error) throw error;
  return data as MerchantFinanceOverview;
}

// ---------------------------------------------------------------------------
// Date range (Bangkok business days)
// ---------------------------------------------------------------------------

export const FINANCE_PRESETS = [
  { value: "today", label: "วันนี้", days: 1 },
  { value: "7d", label: "7 วัน", days: 7 },
  { value: "30d", label: "30 วัน", days: 30 },
] as const;

export type FinancePreset = (typeof FINANCE_PRESETS)[number]["value"] | "custom";

/** Must match the RPC's limit. */
export const FINANCE_MAX_DAYS = 366;

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Today's date in Asia/Bangkok as YYYY-MM-DD. */
export function bangkokToday(now: Date = new Date()): string {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Bangkok" }).format(now);
}

function addDays(isoDate: string, days: number): string {
  const date = new Date(`${isoDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function isValidIsoDate(value: string | undefined): value is string {
  if (!value || !ISO_DATE.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function daysBetween(from: string, to: string) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1;
}

/**
 * Turns ?range=&from=&to= into an inclusive Bangkok date range. Anything
 * invalid (bad dates, from after to, longer than the RPC allows) falls back
 * to the last 7 days instead of erroring, and says so via `fallback`.
 */
export function resolveFinanceRange(
  params: { range?: string; from?: string; to?: string },
  now: Date = new Date(),
): { preset: FinancePreset; from: string; to: string; fallback: boolean } {
  const today = bangkokToday(now);
  if (params.range === "custom") {
    const { from, to } = params;
    if (isValidIsoDate(from) && isValidIsoDate(to) && from <= to && daysBetween(from, to) <= FINANCE_MAX_DAYS) {
      return { preset: "custom", from, to, fallback: false };
    }
    return { preset: "7d", from: addDays(today, -6), to: today, fallback: true };
  }
  const preset = FINANCE_PRESETS.find((item) => item.value === params.range) ?? FINANCE_PRESETS[1];
  return { preset: preset.value, from: addDays(today, -(preset.days - 1)), to: today, fallback: false };
}

export const STRIPE_STATUS_LABEL: Record<NonNullable<MerchantFinanceStore["stripe_status"]>, string> = {
  onboarding: "กำลังสมัคร",
  pending: "รอตรวจสอบ",
  ready: "พร้อมรับเงิน",
  restricted: "ถูกจำกัด",
};

export const PAYOUT_STATUS_LABEL: Record<MerchantFinancePayout["status"], string> = {
  pending: "รอดำเนินการ",
  in_transit: "กำลังโอน",
  paid: "โอนแล้ว",
  failed: "โอนไม่สำเร็จ",
  canceled: "ยกเลิก",
};

export const PAYOUT_INTERVAL_LABEL: Record<string, string> = {
  daily: "รายวัน",
  weekly: "รายสัปดาห์",
  monthly: "รายเดือน",
  manual: "กดโอนเอง",
  unknown: "ไม่ทราบ",
};

/** Stripe amounts are integer satang; shown in baht without float maths on the stored value. */
export function formatSatang(amountSatang: number): string {
  const satang = Math.trunc(Number(amountSatang ?? 0));
  const baht = Math.trunc(satang / 100);
  const rest = Math.abs(satang % 100);
  const sign = satang < 0 && baht === 0 ? "-" : "";
  return `฿${sign}${baht.toLocaleString("th-TH")}${rest ? `.${String(rest).padStart(2, "0")}` : ""}`;
}
