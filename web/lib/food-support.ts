import type { SupabaseClient } from "@supabase/supabase-js";

export type FoodSupportStatus = "open" | "in_progress" | "waiting_customer" | "resolved" | "appealed";
export type FoodSupportCase = {
  id: string; order_id: string; order_number: string; store_name: string; kind: string;
  subject: string; status: FoodSupportStatus; evidence_item_name: string | null;
  compensation_requested: boolean; appeal_count: number; version: number;
  created_at: string; updated_at: string;
};
export type FoodSupportDetail = FoodSupportCase & {
  messages: { id: string; actor_role: "customer" | "support"; body: string; created_at: string }[];
};
export type SupportOrder = {
  id: string; order_number: string; food_order_items?: { id: string; item_name: string }[];
};
function isSupportCase(data: unknown): data is FoodSupportCase {
  if (!data || typeof data !== "object") return false;
  const item = data as FoodSupportCase;
  return typeof item.id === "string" && typeof item.order_id === "string"
    && typeof item.order_number === "string" && typeof item.subject === "string"
    && ["open", "in_progress", "waiting_customer", "resolved", "appealed"].includes(item.status)
    && Number.isInteger(item.version) && item.version > 0 && Number.isInteger(item.appeal_count);
}
function supportDetail(data: unknown): FoodSupportDetail {
  if (!isSupportCase(data)) throw new Error("Unexpected support response");
  const detail = data as FoodSupportDetail;
  if (!Array.isArray(detail.messages) || !detail.messages.every(message => message
    && typeof message.id === "string" && typeof message.body === "string"
    && ["customer", "support"].includes(message.actor_role))) throw new Error("Unexpected support response");
  return detail;
}
export async function loadFoodSupportCases(client: SupabaseClient): Promise<FoodSupportCase[]> {
  const { data, error } = await client.rpc("food_support_cases", { p_limit: 50 }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  if (!Array.isArray(data) || !data.every(isSupportCase)) throw new Error("Unexpected support response");
  return data as FoodSupportCase[];
}
export async function loadFoodSupportCase(client: SupabaseClient, id: string): Promise<FoodSupportDetail> {
  const { data, error } = await client.rpc("food_support_case_detail", { p_case_id: id }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  return supportDetail(data);
}
export async function createFoodSupportCase(client: SupabaseClient, input: {
  orderId: string; kind: string; subject: string; body: string; evidenceItemId: string; compensationRequested: boolean;
}): Promise<FoodSupportDetail> {
  const { data, error } = await client.rpc("food_create_support_case", {
    p_order_id: input.orderId, p_kind: input.kind, p_subject: input.subject.trim(), p_body: input.body.trim(),
    p_evidence_order_item_id: input.evidenceItemId || null, p_compensation_requested: input.compensationRequested,
  }).abortSignal(AbortSignal.timeout(15_000));
  if (error) throw error;
  return supportDetail(data);
}
export async function replyFoodSupportCase(client: SupabaseClient, supportCase: FoodSupportCase, body: string, appeal: boolean): Promise<FoodSupportDetail> {
  const { data, error } = await client.rpc("food_reply_support_case", {
    p_case_id: supportCase.id, p_expected_version: supportCase.version, p_body: body.trim(), p_appeal: appeal,
  }).abortSignal(AbortSignal.timeout(15_000));
  if (error) throw error;
  return supportDetail(data);
}
export function foodSupportErrorCopy(error: unknown): string {
  const message = (error as { message?: string })?.message ?? "";
  if (/abort|timeout/i.test(message)) return "ยังไม่ได้รับคำยืนยัน กรุณาโหลดเคสล่าสุดเพื่อตรวจสอบก่อนส่งอีกครั้ง";
  if (message.includes("Case changed")) return "เคสมีข้อมูลใหม่ กรุณาโหลดล่าสุดแล้วส่งอีกครั้ง";
  if (message.includes("Active case already exists")) return "มีเคสเรื่องนี้เปิดอยู่แล้ว กรุณาติดตามจากเคสของฉัน";
  if (message.includes("rate limit")) return "ส่งคำขอบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่";
  if (message.includes("Appeal not available")) return "เคสนี้ยังไม่ปิดหรือใช้สิทธิ์อุทธรณ์แล้ว";
  if (message.includes("Not authorized") || message.includes("Order not available")) return "ไม่สามารถเข้าถึงเคสหรือออเดอร์นี้ กรุณาเข้าสู่ระบบอีกครั้ง";
  if (message.includes("Invalid support input")) return "กรุณาตรวจสอบความยาวหัวข้อและรายละเอียด";
  return "ดำเนินการไม่สำเร็จ กรุณาลองใหม่อีกครั้ง";
}
