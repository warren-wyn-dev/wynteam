import type { SupabaseClient } from "@supabase/supabase-js";

import { money } from "@/lib/food-merchant";

/**
 * WYN-206: WYNOS campaigns designed by WYNOS Admin that a store can join.
 * The server (supabase/migrations_wynos_platform_campaigns_v1.sql) prices
 * orders, records WYNOS's share and what is owed back to the store.
 */
export type PlatformCampaignType = "percentage" | "fixed" | "free_delivery";

export type PlatformCampaign = {
  id: string;
  name: string;
  description: string | null;
  campaign_type: PlatformCampaignType;
  discount_value: number | string;
  min_subtotal: number | string;
  max_discount: number | string | null;
  starts_at: string;
  ends_at: string | null;
  usage_limit_per_store: number | null;
  platform_share_percent: number | string;
  join_open: boolean;
  is_active: boolean;
  joined: boolean;
  joined_at: string | null;
  usage_count: number;
  delivered_orders: number;
  discount_total: number | string;
  platform_funded_total: number | string;
};

export type PlatformSettlement = {
  id: string;
  amount: number | string;
  order_count: number;
  reference: string;
  note: string | null;
  created_at: string;
};

export type PlatformCampaignsSnapshot = {
  can_manage: boolean;
  campaigns: PlatformCampaign[];
  owed: number | string;
  owed_orders: number;
  settlements: PlatformSettlement[];
};

export async function fetchPlatformCampaigns(client: SupabaseClient, storeId: string): Promise<PlatformCampaignsSnapshot> {
  const { data, error } = await client.rpc("merchant_platform_campaigns", { p_store_id: storeId });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as Partial<PlatformCampaignsSnapshot>;
  return {
    can_manage: raw.can_manage === true,
    campaigns: Array.isArray(raw.campaigns) ? raw.campaigns : [],
    owed: raw.owed ?? 0,
    owed_orders: Number(raw.owed_orders ?? 0),
    settlements: Array.isArray(raw.settlements) ? raw.settlements : [],
  };
}

export async function joinPlatformCampaign(client: SupabaseClient, storeId: string, campaignId: string) {
  const { error } = await client.rpc("merchant_join_platform_campaign", { p_store_id: storeId, p_campaign_id: campaignId });
  if (error) throw new Error(error.message);
}

export async function leavePlatformCampaign(client: SupabaseClient, storeId: string, campaignId: string) {
  const { error } = await client.rpc("merchant_leave_platform_campaign", { p_store_id: storeId, p_campaign_id: campaignId });
  if (error) throw new Error(error.message);
}

/** "ลด 20% สูงสุด ฿100 · ขั้นต่ำ ฿150" */
export function platformCampaignTerms(campaign: Pick<PlatformCampaign, "campaign_type" | "discount_value" | "max_discount" | "min_subtotal">) {
  const parts: string[] = [];
  if (campaign.campaign_type === "percentage") {
    parts.push(`ลด ${Number(campaign.discount_value)}%`);
    if (campaign.max_discount != null && Number(campaign.max_discount) > 0) parts.push(`สูงสุด ${money(campaign.max_discount)}`);
  } else if (campaign.campaign_type === "fixed") {
    parts.push(`ลด ${money(campaign.discount_value)}`);
  } else {
    parts.push("ส่งฟรี");
  }
  const terms = parts.join(" ");
  return Number(campaign.min_subtotal) > 0 ? `${terms} · ขั้นต่ำ ${money(campaign.min_subtotal)}` : terms;
}

export function platformCampaignError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("campaign is not open for joining")) return "แคมเปญนี้ปิดรับร้านแล้ว";
  if (message.includes("merchant manager access required")) return "เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่เข้าร่วมแคมเปญได้";
  if (message.includes("store is suspended")) return "ร้านถูกระงับโดยทีม WYNOS เข้าร่วมแคมเปญไม่ได้";
  if (message.includes("merchant_platform_campaigns") || message.includes("Could not find the function")) return "ระบบแคมเปญ WYNOS ยังไม่เปิดใช้งาน";
  return message || "ดำเนินการไม่สำเร็จ";
}
