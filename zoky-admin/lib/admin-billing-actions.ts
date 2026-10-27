import { createClient } from "@/lib/supabase/client";

/** ZOKY-BILLING-001 Admin writes; the RPCs recheck merchant:edit on the server. */
export type BillingSettingsInput = {
  enabled: boolean;
  monthlyFee: number | null;
  trialDays: number | null;
  promptpayName: string;
  promptpayId: string;
  bankName: string;
  bankAccountName: string;
  bankAccountNumber: string;
  issuerName: string;
  issuerAddress: string;
  issuerTaxId: string;
};

export async function saveBillingSettings(input: BillingSettingsInput) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_update_billing_settings", {
    p_enabled: input.enabled,
    p_monthly_fee: input.monthlyFee,
    p_trial_days: input.trialDays,
    p_promptpay_name: input.promptpayName,
    p_promptpay_id: input.promptpayId,
    p_bank_name: input.bankName,
    p_bank_account_name: input.bankAccountName,
    p_bank_account_number: input.bankAccountNumber,
    p_issuer_name: input.issuerName,
    p_issuer_address: input.issuerAddress,
    p_issuer_tax_id: input.issuerTaxId,
  });
  if (error) throw error;
}

export async function reviewBillingInvoice(params: { invoiceId: string; approve: boolean; note?: string }) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_review_billing_invoice", {
    p_invoice_id: params.invoiceId,
    p_approve: params.approve,
    p_note: params.note?.trim() || null,
  });
  if (error) throw error;
}

export async function waiveBillingInvoice(params: { invoiceId: string; reason: string }) {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_waive_billing_invoice", { p_invoice_id: params.invoiceId, p_reason: params.reason.trim() });
  if (error) throw error;
}

export function adminBillingError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? error ?? "");
  if (message.includes("monthly fee and trial days")) return "ใส่ค่าบริการรายเดือนและจำนวนวันทดลองใช้ก่อนเปิดระบบ";
  if (message.includes("ZOKY payment account")) return "ใส่ PromptPay หรือบัญชีธนาคารของ ZOKY ให้ครบก่อนเปิดระบบ";
  if (message.includes("receipt issuer")) return "ใส่ชื่อผู้ออกใบเสร็จก่อนเปิดระบบ";
  if (message.includes("food_billing_settings_fee_check")) return "ค่าบริการต้องมากกว่า 0 และไม่เกิน 100,000 บาท";
  if (message.includes("food_billing_settings_trial_check")) return "วันทดลองใช้ต้องอยู่ระหว่าง 0–365 วัน";
  if (message.includes("food_billing_settings_promptpay_check")) return "PromptPay ต้องเป็นเบอร์มือถือ 10 หลัก (ขึ้นต้นด้วย 0) หรือเลข 13/15 หลัก";
  if (message.includes("food_billing_settings_bank_number_check")) return "เลขบัญชีธนาคารต้องเป็นตัวเลข 10–15 หลัก";
  if (message.includes("food_billing_settings_tax_id_check")) return "เลขผู้เสียภาษีต้องเป็นตัวเลข 13 หลัก";
  if (message.includes("food_billing_settings_text_check")) return "ข้อความยาวเกินกำหนด";
  if (message.includes("reason is required")) return "กรุณาใส่เหตุผล";
  if (message.includes("no slip waiting")) return "รายการนี้ตรวจไปแล้ว กรุณารีเฟรช";
  if (message.includes("already closed")) return "ใบแจ้งหนี้นี้ปิดไปแล้ว กรุณารีเฟรช";
  if (message.includes("Not authorized")) return "บัญชีนี้ไม่มีสิทธิ์แก้ไขการเงินร้านค้า";
  return fallback;
}
