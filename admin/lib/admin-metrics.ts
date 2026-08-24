import { createClient } from "@/lib/supabase/server";

/**
 * Mirrors admin_dashboard_metrics()'s RETURNS TABLE column list exactly
 * (supabase/schema.sql, WYN-050 section). The RPC itself enforces the
 * admin/moderator gate (raises otherwise) -- this function doesn't
 * re-check role, it just surfaces whatever the RPC decides.
 */
export type AdminDashboardMetrics = {
  new_users_today: number;
  dau: number;
  wau: number;
  mau: number;
  drops_today: number;
  views_today: number;
  clubs_total: number;
  clubs_new_today: number;
  likes_today: number;
  comments_today: number;
  redrops_today: number;
  messages_today: number;
  reports_total: number;
  reports_pending: number;
};

export async function fetchAdminDashboardMetrics(): Promise<AdminDashboardMetrics> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_dashboard_metrics").single();

  if (error || !data) {
    throw error ?? new Error("admin_dashboard_metrics() returned no row");
  }

  return data as AdminDashboardMetrics;
}
