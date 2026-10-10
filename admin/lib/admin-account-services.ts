import { createClient } from "@/lib/supabase/server";

export type WynosAccountSnapshot = {
  account_id: string;
  created_at: string;
  signals: {
    social_profile: boolean;
    food_activity: boolean;
    merchant_record: boolean;
    maps_activity: boolean;
  };
};

/**
 * Admin-only, read-only evidence of service records for the shared auth user.
 * The SQL RPC also checks platform_role=admin on the server.
 */
export async function fetchWynosAccountSnapshot(
  userId: string,
): Promise<WynosAccountSnapshot | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_wynos_account_snapshot", {
    p_user_id: userId,
  });
  if (error) throw error;
  return (data as WynosAccountSnapshot | null) ?? null;
}
