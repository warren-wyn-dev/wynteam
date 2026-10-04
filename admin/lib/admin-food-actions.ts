"use client";

import { createClient } from "@/lib/supabase/client";

/** WYN-203: admin-only changes; the RPCs re-check the role and write the audit log. */
export async function setFoodStoreSuspension(params: {
  storeId: string;
  suspend: boolean;
  reason?: string;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_food_store_suspension", {
    p_store_id: params.storeId,
    p_suspend: params.suspend,
    p_reason: params.reason?.trim() || null,
  });
  if (error) throw error;
}

export async function setFoodStoreMemberActive(params: {
  storeId: string;
  userId: string;
  active: boolean;
}): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_set_food_store_member_active", {
    p_store_id: params.storeId,
    p_user_id: params.userId,
    p_active: params.active,
  });
  if (error) throw error;
}

export function adminFoodError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("suspension reason is required")) return "กรุณาใส่เหตุผลการระงับ";
  if (message.includes("cannot deactivate the only owner")) return "ปิดสิทธิ์เจ้าของคนเดียวของร้านไม่ได้";
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่ทำรายการนี้ได้";
  return message || fallback;
}

/** WYN-206: create or edit a WYNOS campaign (admin only; the RPC re-checks). */
export type PlatformCampaignInput = {
  id: string | null;
  name: string;
  description: string;
  campaignType: "percentage" | "fixed" | "free_delivery";
  discountValue: number;
  minSubtotal: number;
  maxDiscount: number | null;
  startsAt: string;
  endsAt: string | null;
  usageLimitPerStore: number | null;
  platformSharePercent: number;
  joinOpen: boolean;
  isActive: boolean;
};

export async function savePlatformCampaign(input: PlatformCampaignInput): Promise<string> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("admin_upsert_platform_campaign", {
    p_campaign_id: input.id,
    p_name: input.name,
    p_description: input.description,
    p_campaign_type: input.campaignType,
    p_discount_value: input.discountValue,
    p_min_subtotal: input.minSubtotal,
    p_max_discount: input.maxDiscount,
    p_starts_at: input.startsAt,
    p_ends_at: input.endsAt,
    p_usage_limit_per_store: input.usageLimitPerStore,
    p_platform_share_percent: input.platformSharePercent,
    p_join_open: input.joinOpen,
    p_is_active: input.isActive,
  });
  if (error) throw error;
  return data as string;
}

/** WYN-206: record that WYNOS transferred what it owes a store. */
export async function settlePlatformStore(params: { storeId: string; reference: string; note?: string }): Promise<void> {
  const supabase = createClient();
  const { error } = await supabase.rpc("admin_settle_platform_store", {
    p_store_id: params.storeId,
    p_reference: params.reference.trim(),
    p_note: params.note?.trim() || null,
  });
  if (error) throw error;
}

export function platformCampaignError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? error ?? "");
  if (message.includes("food_platform_campaigns_name_length")) return "ชื่อแคมเปญต้องยาว 2–80 ตัวอักษร";
  if (message.includes("food_platform_campaigns_discount_check")) return "ส่วนลดไม่ถูกต้อง (เปอร์เซ็นต์ 1–100 หรือจำนวนเงินมากกว่า 0)";
  if (message.includes("food_platform_campaigns_dates_check")) return "วันจบต้องอยู่หลังวันเริ่ม";
  if (message.includes("food_platform_campaigns_share_check")) return "สัดส่วนที่ WYNOS ออกต้องอยู่ระหว่าง 0–100%";
  if (message.includes("transfer reference is required")) return "กรุณาใส่เลขอ้างอิงการโอน";
  if (message.includes("nothing to settle")) return "ไม่มียอดค้างโอนแล้ว";
  if (message.includes("Only admins")) return "เฉพาะ Admin เท่านั้นที่ทำรายการนี้ได้";
  return message || fallback;
}
