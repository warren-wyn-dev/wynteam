import type { SupabaseClient } from "@supabase/supabase-js";

import { uploadFoodPrivateImage } from "@/lib/food-merchant";

/**
 * WYN-207: pay-per-click ads (supabase/migrations_wynos_food_ads_v1.sql).
 * The store tops up credit by PromptPay + slip, WYNOS Admin approves, and
 * every charged click is decided on the server.
 */
export type MerchantAdTopup = {
  id: string;
  amount: number | string;
  status: "pending" | "approved" | "rejected";
  note: string | null;
  created_at: string;
  reviewed_at: string | null;
};

export type MerchantAdAccount = {
  can_manage: boolean;
  ads_enabled: boolean;
  cost_per_click: number | string;
  min_topup: number | string;
  wynos_promptpay_name: string | null;
  wynos_promptpay_id: string | null;
  balance: number | string;
  total_spent: number | string;
  status: "none" | "active" | "paused" | "stopped";
  stop_reason: string | null;
  live: boolean;
  clicks_today: number;
  clicks_7d: number;
  spend_7d: number | string;
  topups: MerchantAdTopup[];
};

export async function fetchMerchantAdAccount(client: SupabaseClient, storeId: string): Promise<MerchantAdAccount> {
  const { data, error } = await client.rpc("merchant_ad_account", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<MerchantAdAccount>;
  return {
    can_manage: raw.can_manage === true,
    ads_enabled: raw.ads_enabled === true,
    cost_per_click: raw.cost_per_click ?? 0,
    min_topup: raw.min_topup ?? 0,
    wynos_promptpay_name: raw.wynos_promptpay_name ?? null,
    wynos_promptpay_id: raw.wynos_promptpay_id ?? null,
    balance: raw.balance ?? 0,
    total_spent: raw.total_spent ?? 0,
    status: raw.status ?? "none",
    stop_reason: raw.stop_reason ?? null,
    live: raw.live === true,
    clicks_today: Number(raw.clicks_today ?? 0),
    clicks_7d: Number(raw.clicks_7d ?? 0),
    spend_7d: raw.spend_7d ?? 0,
    topups: Array.isArray(raw.topups) ? raw.topups : [],
  };
}

export async function requestAdTopup(client: SupabaseClient, storeId: string, amount: number, slip: File) {
  const path = await uploadFoodPrivateImage(client, slip, `ads/${storeId}`);
  const { error } = await client.rpc("merchant_request_ad_topup", { p_store_id: storeId, p_amount: amount, p_slip_path: path });
  if (error) throw new Error(error.message);
}

export async function setAdActive(client: SupabaseClient, storeId: string, active: boolean) {
  const { error } = await client.rpc("merchant_set_ad_active", { p_store_id: storeId, p_active: active });
  if (error) throw new Error(error.message);
}

export function merchantAdError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("ads are not open yet")) return "ระบบโฆษณายังไม่เปิด";
  if (message.includes("top-up is below the minimum")) return "ยอดเติมต่ำกว่าขั้นต่ำ";
  if (message.includes("too many pending top-ups")) return "มีรายการรอตรวจอยู่แล้ว รอทีม WYNOS ตรวจก่อน";
  if (message.includes("ads stopped by WYNOS")) return "ทีม WYNOS หยุดโฆษณาของร้านไว้";
  if (message.includes("top up before starting ads")) return "เติมเครดิตก่อนเริ่มโฆษณา";
  if (message.includes("merchant manager access required")) return "เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่จัดการโฆษณาได้";
  if (message.includes("merchant_ad_account") || message.includes("Could not find the function")) return "ระบบโฆษณายังไม่เปิดใช้งาน";
  return message || "ดำเนินการไม่สำเร็จ";
}
