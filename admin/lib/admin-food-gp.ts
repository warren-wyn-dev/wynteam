import { createClient } from "@/lib/supabase/server";

export type FoodGpStoreDraft = {
  store_id: string;
  store_name: string;
  store_slug: string;
  rate_bps: number | null;
  updated_at: string | null;
  mode: "simulation_only" | null;
};

/** QA only: read GP settings via audited, admin-gated RPC. */
export async function fetchFoodGpDrafts(): Promise<FoodGpStoreDraft[]> {
  if (process.env.NEXT_PUBLIC_SUPABASE_URL !== "https://pcatuxtenluqzjzzwsvl.supabase.co") {
    throw new Error("WYNOS GP draft is available in Sandbox only");
  }
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_food_gp_list");
  if (error) throw error;
  return (data ?? []) as FoodGpStoreDraft[];
}
