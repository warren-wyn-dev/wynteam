import { createClient } from "@/lib/supabase/server";

/**
 * WYN-206: WYNOS campaigns designed in Admin and joined by stores
 * (supabase/migrations_wynos_platform_campaigns_v1.sql). Admin and moderator
 * read the list; designing, payouts and transfers are admin only.
 */
export type PlatformCampaignType = "percentage" | "fixed" | "free_delivery";

export type AdminPlatformCampaign = {
  id: string;
  name: string;
  description: string | null;
  campaign_type: PlatformCampaignType;
  discount_value: number;
  min_subtotal: number;
  max_discount: number | null;
  starts_at: string;
  ends_at: string | null;
  usage_limit_per_store: number | null;
  platform_share_percent: number;
  join_open: boolean;
  is_active: boolean;
  created_at: string;
  joined_stores: number;
  delivered_orders: number;
  discount_total: number;
  platform_funded_total: number;
};

export type AdminPlatformOwed = {
  store_id: string;
  store_name: string;
  promptpay_name: string | null;
  promptpay_id: string | null;
  bank_name: string | null;
  bank_account_name: string | null;
  bank_account_number: string | null;
  owed: number;
  owed_orders: number;
  last_settled_at: string | null;
};

export async function fetchAdminPlatformCampaigns(): Promise<AdminPlatformCampaign[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_platform_campaigns");
  if (error) throw error;
  return (data ?? []) as AdminPlatformCampaign[];
}

export async function fetchAdminPlatformOwed(): Promise<AdminPlatformOwed[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_platform_owed");
  if (error) throw error;
  return (data ?? []) as AdminPlatformOwed[];
}

export function platformCampaignTerms(campaign: Pick<AdminPlatformCampaign, "campaign_type" | "discount_value" | "max_discount" | "min_subtotal">) {
  const baht = (value: number) => `฿${Number(value).toLocaleString("th-TH", { maximumFractionDigits: 2 })}`;
  let terms = campaign.campaign_type === "percentage"
    ? `ลด ${Number(campaign.discount_value)}%${campaign.max_discount ? ` สูงสุด ${baht(campaign.max_discount)}` : ""}`
    : campaign.campaign_type === "fixed" ? `ลด ${baht(campaign.discount_value)}` : "ส่งฟรี";
  if (Number(campaign.min_subtotal) > 0) terms += ` · ขั้นต่ำ ${baht(campaign.min_subtotal)}`;
  return terms;
}
