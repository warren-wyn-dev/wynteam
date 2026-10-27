import { createClient } from "@/lib/supabase/server";

/** ZOKY-BILLING-001: monthly store fee (supabase/migrations/20261028090000_zoky_billing_001.sql). */
export type AdminBillingSettings = {
  billing_enabled: boolean;
  monthly_fee: number | null;
  trial_days: number | null;
  zoky_promptpay_name: string | null;
  zoky_promptpay_id: string | null;
  zoky_bank_name: string | null;
  zoky_bank_account_name: string | null;
  zoky_bank_account_number: string | null;
  receipt_issuer_name: string | null;
  receipt_issuer_address: string | null;
  receipt_issuer_tax_id: string | null;
  launched_on: string | null;
  updated_at: string;
};

export type AdminBillingInvoiceStatus = "unpaid" | "slip_submitted" | "paid" | "rejected" | "waived";

export type AdminBillingPending = {
  id: string;
  store_id: string;
  store_name: string;
  amount: number;
  period_start: string;
  period_end: string;
  due_on: string;
  slip_path: string;
  submitted_at: string;
};

export type AdminBillingOverdue = {
  id: string;
  store_id: string;
  store_name: string;
  amount: number;
  status: "unpaid" | "rejected";
  due_on: string;
  overdue_days: number;
  note: string | null;
  suspended: boolean;
};

export type AdminBillingRecent = {
  id: string;
  store_id: string;
  store_name: string;
  amount: number;
  status: AdminBillingInvoiceStatus;
  period_start: string;
  due_on: string;
  receipt_no: string | null;
  note: string | null;
};

export type AdminBillingOverview = {
  today: string;
  settings: AdminBillingSettings;
  price_history: { monthly_fee: number | null; trial_days: number | null; set_at: string }[];
  stores: { in_trial: number; billed: number };
  pending: AdminBillingPending[];
  overdue: AdminBillingOverdue[];
  recent: AdminBillingRecent[];
};

export const BILLING_STATUS_LABEL: Record<AdminBillingInvoiceStatus, string> = {
  unpaid: "รอชำระ",
  slip_submitted: "รอตรวจสลิป",
  paid: "ชำระแล้ว",
  rejected: "สลิปไม่ผ่าน",
  waived: "ยกเว้น",
};

export async function fetchAdminBillingOverview(): Promise<AdminBillingOverview> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_billing_overview");
  if (error) throw error;
  return data as AdminBillingOverview;
}

/** A date-only value (YYYY-MM-DD) in Thai, without shifting the day. */
export function formatBillingDay(value: string | null | undefined) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeZone: "UTC" }).format(new Date(`${value}T00:00:00Z`));
}
