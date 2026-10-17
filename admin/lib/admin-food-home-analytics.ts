import { createClient } from "@/lib/supabase/server";

export type FoodHomeAnalyticsKind = "banner" | "featured";
export type FoodHomeAnalyticsDays = 7 | 30 | 90;
export type FoodHomeAnalytics = {
  placement_kind: FoodHomeAnalyticsKind;
  days: FoodHomeAnalyticsDays;
  starts_on: string;
  ends_on: string;
  impressions: number;
  clicks: number;
  ctr_pct: number | null;
  items: Array<{ id: string; label: string; impressions: number; clicks: number; ctr_pct: number | null }>;
  last_limited_at: string | null;
};

export function foodHomeAnalyticsDays(value: string | string[] | undefined): FoodHomeAnalyticsDays {
  return value === "7" ? 7 : value === "90" ? 90 : 30;
}

export async function fetchFoodHomeAnalytics(kind: FoodHomeAnalyticsKind, days: FoodHomeAnalyticsDays): Promise<FoodHomeAnalytics> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_food_home_placement_analytics", {
    p_placement_kind: kind,
    p_days: days,
  }).abortSignal(AbortSignal.timeout(10_000));
  if (error || !data) throw error ?? new Error("Food home analytics unavailable");
  return data as FoodHomeAnalytics;
}
