import { createClient } from "@/lib/supabase/server";

export type FinanceConfig = {
  id: string;
  effective_from: string;
  default_gp_bps: number;
  delivery_base_fee_satang: number;
  delivery_base_distance_m: number;
  delivery_per_km_satang: number;
  delivery_min_fee_satang: number;
  delivery_max_fee_satang: number | null;
  delivery_rounding_m: number;
  free_delivery_threshold_satang: number | null;
  peak_surcharge_satang: number;
  rain_surcharge_satang: number;
  long_distance_threshold_m: number | null;
  long_distance_surcharge_satang: number;
  rider_base_pay_satang: number;
  rider_pay_per_km_satang: number;
  rider_min_earning_satang: number;
  rider_long_distance_threshold_m: number | null;
  rider_long_distance_bonus_satang: number;
  rider_peak_bonus_satang: number;
  rider_rain_bonus_satang: number;
  rider_incentive_order_count: number | null;
  rider_incentive_bonus_satang: number;
  rider_platform_fee_bps: number;
  stripe_fee_payer: "wynos" | "merchant" | "shared";
  stripe_shared_merchant_bps: number;
  service_fee_mode: "fixed" | "percent";
  service_fee_value: number;
  service_fee_min_satang: number;
  service_fee_max_satang: number | null;
  small_order_threshold_satang: number;
  small_order_fee_mode: "fixed" | "percent";
  small_order_fee_value: number;
  small_order_fee_max_satang: number | null;
  surge_fee_mode: "fixed" | "percent";
  surge_fee_value: number;
  surge_fee_max_satang: number | null;
  tax_enabled: boolean;
  vat_registered: boolean;
  vat_percent_bps: number;
};

export type FinanceStore = {
  id: string;
  name: string;
  slug: string;
  gp_bps: number;
  gp_source: "promotion" | "custom" | "default";
  override_id: string | null;
  promotion_id: string | null;
  payment_ready: boolean;
  payment_enabled: boolean;
  payout_suspended: boolean;
  promotion_eligible: boolean;
};

export type FinanceRider = {
  id: string;
  user_id: string;
  status: string;
  active: boolean;
  service_area_code: string | null;
  payout_suspended: boolean;
  approved_at: string | null;
};

export type FinanceSettlement = {
  id: string;
  store_id: string;
  store_name: string;
  period_from: string;
  period_to: string;
  status: "pending" | "paid" | "cancelled";
  order_count: number;
  gross_sales_satang: number;
  merchant_discount_satang: number;
  gp_satang: number;
  payment_fees_satang: number;
  refunds_satang: number;
  adjustments_satang: number;
  net_satang: number;
  reference: string | null;
  note: string | null;
  created_at: string;
  paid_at: string | null;
};

export type FinanceControlSnapshot = {
  config: FinanceConfig;
  flags: Record<string, boolean>;
  stores: FinanceStore[];
  gp_promotions: Array<Record<string, unknown>>;
  zone_pricing: Array<Record<string, unknown>>;
  settlements: FinanceSettlement[];
  riders: FinanceRider[];
};

export type FinanceOperations = {
  payments: Array<Record<string, unknown>>;
  refunds: Array<Record<string, unknown>>;
  merchant_settlements: Array<Record<string, unknown>>;
  rider_payouts: Array<Record<string, unknown>>;
};

export type RiderFinanceRow = Record<string, unknown> & {
  rider_id: string;
  user_id: string;
  username: string | null;
  display_name: string | null;
  status: string;
  active: boolean;
  service_area_code: string | null;
  payout_suspended: boolean;
  gross_earnings_satang: number;
  bonus_satang: number;
  adjustments_satang: number;
  paid_satang: number;
  pending_payout_satang: number;
  jobs: number;
};

export type FinanceDashboard = {
  from: string;
  to: string;
  orders: number;
  gross_order_value_satang: number;
  gp_revenue_satang: number;
  delivery_revenue_satang: number;
  stripe_fees_satang: number;
  merchant_net_satang: number;
  rider_earnings_satang: number;
  refunds_satang: number;
  promotion_cost_satang: number;
  net_platform_revenue_satang: number;
  legacy_orders_without_snapshot: number;
};

export async function fetchFinanceControlSnapshot(): Promise<FinanceControlSnapshot> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_finance_control_snapshot");
  if (error) throw new Error(error.message);
  return data as FinanceControlSnapshot;
}

export async function fetchFinanceDashboard(from: string, to: string): Promise<FinanceDashboard> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_finance_dashboard", { p_from: from, p_to: to });
  if (error) throw new Error(error.message);
  return data as FinanceDashboard;
}

export async function fetchFinanceOperations(limit = 100): Promise<FinanceOperations> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_finance_operations", { p_limit: limit });
  if (error) throw new Error(error.message);
  return data as FinanceOperations;
}

export async function fetchRiderFinance(): Promise<RiderFinanceRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_rider_finance");
  if (error) throw new Error(error.message);
  return (data ?? []) as RiderFinanceRow[];
}

export function bahtFromSatang(value: number | string | null | undefined) {
  return Number(value ?? 0) / 100;
}

export function formatSatang(value: number | string | null | undefined) {
  return new Intl.NumberFormat("th-TH", {
    style: "currency",
    currency: "THB",
    minimumFractionDigits: 2,
  }).format(bahtFromSatang(value));
}

export function percentFromBps(value: number | string | null | undefined) {
  return Number(value ?? 0) / 100;
}

export function formatFinanceDate(value: unknown) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Bangkok",
  }).format(new Date(String(value)));
}


export type MerchantSettlementPreview = {
  store_id: string;
  from: string;
  to: string;
  order_count: number;
  gross_sales_satang: number;
  merchant_discount_satang: number;
  gp_satang: number;
  payment_fees_satang: number;
  refunds_satang: number;
  adjustments_satang: number;
  net_satang: number;
};

export async function fetchMerchantSettlementPreview(
  storeId: string,
  from: string,
  to: string,
): Promise<MerchantSettlementPreview> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_settlement_preview", {
    p_store_id: storeId,
    p_from: from,
    p_to: to,
  });
  if (error) throw new Error(error.message);
  return data as MerchantSettlementPreview;
}
