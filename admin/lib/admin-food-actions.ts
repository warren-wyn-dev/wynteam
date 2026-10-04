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
