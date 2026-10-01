import type { SupabaseClient } from "@supabase/supabase-js";

export type MerchantCampaignType = "percentage" | "fixed" | "free_delivery";
export type MerchantCampaignScope = "store" | "items";

export type MerchantCampaign = {
  id: string;
  store_id: string;
  name: string;
  campaign_type: MerchantCampaignType;
  scope: MerchantCampaignScope;
  discount_value: number | string;
  min_subtotal: number | string;
  max_discount: number | string | null;
  starts_at: string;
  ends_at: string | null;
  usage_limit: number | null;
  usage_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  item_ids: string[];
  redeemed_count: number;
  delivered_orders: number;
  sales_total: number | string;
  discount_total: number | string;
};

export type MerchantCampaignList = {
  can_manage: boolean;
  campaigns: MerchantCampaign[];
};

export type MerchantCampaignDraft = {
  id?: string | null;
  name: string;
  campaignType: MerchantCampaignType;
  scope: MerchantCampaignScope;
  discountValue: string;
  minSubtotal: string;
  maxDiscount: string;
  startsAt: string;
  endsAt: string;
  usageLimit: string;
  itemIds: string[];
};

function asCampaign(value: unknown): MerchantCampaign {
  const row = (value ?? {}) as Partial<MerchantCampaign>;
  return {
    id: String(row.id ?? ""),
    store_id: String(row.store_id ?? ""),
    name: String(row.name ?? ""),
    campaign_type: row.campaign_type === "fixed" || row.campaign_type === "free_delivery" ? row.campaign_type : "percentage",
    scope: row.scope === "items" ? "items" : "store",
    discount_value: row.discount_value ?? 0,
    min_subtotal: row.min_subtotal ?? 0,
    max_discount: row.max_discount ?? null,
    starts_at: String(row.starts_at ?? ""),
    ends_at: row.ends_at ? String(row.ends_at) : null,
    usage_limit: row.usage_limit == null ? null : Number(row.usage_limit),
    usage_count: Number(row.usage_count ?? 0),
    is_active: row.is_active === true,
    created_at: String(row.created_at ?? ""),
    updated_at: String(row.updated_at ?? ""),
    item_ids: Array.isArray(row.item_ids) ? row.item_ids.map(String) : [],
    redeemed_count: Number(row.redeemed_count ?? 0),
    delivered_orders: Number(row.delivered_orders ?? 0),
    sales_total: row.sales_total ?? 0,
    discount_total: row.discount_total ?? 0,
  };
}

export async function fetchMerchantCampaigns(
  client: SupabaseClient,
  storeId: string,
): Promise<MerchantCampaignList> {
  const { data, error } = await client.rpc("merchant_food_campaigns", {
    p_store_id: storeId,
  });
  if (error) throw new Error(error.message);
  const raw = (data ?? {}) as { can_manage?: unknown; campaigns?: unknown };
  return {
    can_manage: raw.can_manage === true,
    campaigns: Array.isArray(raw.campaigns) ? raw.campaigns.map(asCampaign) : [],
  };
}

export async function saveMerchantCampaign(
  client: SupabaseClient,
  storeId: string,
  draft: MerchantCampaignDraft,
) {
  const discountValue = draft.campaignType === "free_delivery" ? 0 : Number(draft.discountValue || 0);
  const minSubtotal = Number(draft.minSubtotal || 0);
  const maxDiscount = draft.campaignType === "percentage" && draft.maxDiscount.trim()
    ? Number(draft.maxDiscount)
    : null;
  const usageLimit = draft.usageLimit.trim() ? Number(draft.usageLimit) : null;
  const startsAt = draft.startsAt ? new Date(draft.startsAt).toISOString() : new Date().toISOString();
  const endsAt = draft.endsAt ? new Date(draft.endsAt).toISOString() : null;

  const { data, error } = await client.rpc("merchant_upsert_food_campaign", {
    p_store_id: storeId,
    p_name: draft.name.trim(),
    p_campaign_type: draft.campaignType,
    p_scope: draft.campaignType === "free_delivery" ? "store" : draft.scope,
    p_discount_value: discountValue,
    p_min_subtotal: minSubtotal,
    p_max_discount: maxDiscount,
    p_starts_at: startsAt,
    p_ends_at: endsAt,
    p_usage_limit: usageLimit,
    p_item_ids: draft.campaignType === "free_delivery" || draft.scope === "store" ? [] : draft.itemIds,
    p_campaign_id: draft.id ?? null,
  });
  if (error) throw new Error(error.message);
  return String(data);
}

export async function setMerchantCampaignActive(
  client: SupabaseClient,
  storeId: string,
  campaignId: string,
  active: boolean,
) {
  const { error } = await client.rpc("merchant_set_food_campaign_active", {
    p_store_id: storeId,
    p_campaign_id: campaignId,
    p_active: active,
  });
  if (error) throw new Error(error.message);
}

export async function deleteMerchantCampaign(
  client: SupabaseClient,
  storeId: string,
  campaignId: string,
) {
  const { error } = await client.rpc("merchant_delete_food_campaign", {
    p_store_id: storeId,
    p_campaign_id: campaignId,
  });
  if (error) throw new Error(error.message);
}
