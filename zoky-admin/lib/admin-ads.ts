import { createClient } from "@/lib/supabase/server";

/** WYN-207: WYNOS Food ads (admin only; supabase/migrations_wynos_food_ads_v1.sql). */
export type AdminAdSettings = {
  cost_per_click: number;
  min_topup: number;
  wynos_promptpay_name: string | null;
  wynos_promptpay_id: string | null;
  ads_enabled: boolean;
  updated_at: string;
};

export type AdminAdTopup = { id: string; store_id: string; store_name: string; amount: number; slip_path: string; created_at: string };

export type AdminAdAccount = {
  store_id: string;
  store_name: string;
  balance: number;
  total_spent: number;
  status: "active" | "paused" | "stopped";
  stop_reason: string | null;
  live: boolean;
  clicks_7d: number;
  spend_7d: number;
};

export type AdminAdOverview = { settings: AdminAdSettings; pending_topups: AdminAdTopup[]; accounts: AdminAdAccount[] };

export async function fetchAdminAdOverview(): Promise<AdminAdOverview> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ad_overview");
  if (error) throw error;
  return data as AdminAdOverview;
}
