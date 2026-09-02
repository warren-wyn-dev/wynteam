import { createClient } from "@/lib/supabase/server";

/**
 * Mirrors admin_dashboard_metrics()'s RETURNS TABLE column list exactly
 * (supabase/schema.sql, WYN-050 section). The RPC itself enforces the
 * admin/moderator gate (raises otherwise) -- this function doesn't
 * re-check role, it just surfaces whatever the RPC decides.
 */
export type TopSource = {
  source: string;
  count: number;
};

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
  // WYN-077 additions -- see .wyn/docs/design/wyn-077-basic-product-analytics.md.
  // Percentages are null (not 0) when their cohort is empty (e.g. no
  // signups at all in the relevant window) -- the RPC's own `case when
  // ... = 0 then null` guards against a misleading "0%".
  signup_started_24h: number;
  signup_completed_24h: number;
  signup_conversion_pct: number | null;
  activation_pct_24h: number | null;
  activation_count_24h: number;
  retention_d1_pct: number | null;
  retention_d7_pct: number | null;
  top_sources: TopSource[];
};

export async function fetchAdminDashboardMetrics(): Promise<AdminDashboardMetrics> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_dashboard_metrics").single();

  if (error || !data) {
    throw error ?? new Error("admin_dashboard_metrics() returned no row");
  }

  return data as AdminDashboardMetrics;
}
