import { createClient } from "@/lib/supabase/server";

export type FoodSupportStatus = "open" | "in_progress" | "waiting_customer" | "resolved" | "appealed";
export type FoodSupportCase = {
  id: string; order_id: string; order_number: string; store_id: string; store_name: string;
  kind: string; subject: string; status: FoodSupportStatus; evidence_item_name: string | null;
  compensation_requested: boolean; assigned: boolean; assigned_to_me: boolean | null;
  appeal_count: number; version: number; created_at: string; updated_at: string;
};
export type FoodSupportDetail = FoodSupportCase & {
  messages: { id: string; actor_role: "customer" | "support"; body: string; created_at: string }[];
  history: { action: string; before_status: FoodSupportStatus | null; after_status: FoodSupportStatus; created_at: string }[];
};
export async function fetchFoodSupportCases(): Promise<FoodSupportCase[]> {
  const client = await createClient();
  const { data, error } = await client.rpc("admin_food_support_cases", { p_limit: 100 }).abortSignal(AbortSignal.timeout(10_000));
  if (error) throw error;
  if (!Array.isArray(data)) throw new Error("Unexpected support response");
  return data as FoodSupportCase[];
}
