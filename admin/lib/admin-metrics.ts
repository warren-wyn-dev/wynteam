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
  // DAU/WAU/MAU: calendar-anchored (today so far / last 7 calendar
  // days incl. today / last 30) per the Admin Dashboard restructure
  // spec's "มาตรฐาน DAU/WAU/MAU" section -- see the RPC's own comment.
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
  // Admin Dashboard restructure -- real, existing data
  // (appeals.status = 'pending' / conversations.status = 'active'),
  // not fabricated metrics. See Section 5/6 of the restructure spec.
  appeals_pending: number;
  active_conversations: number;
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

/**
 * Deliberately a separate RPC from admin_dashboard_metrics(), not more
 * columns bolted onto it -- that function was just fixed after a
 * production migration gap, and today's whole incident is reason enough
 * to keep this purely-additive change isolated rather than risk another
 * drop-and-recreate on the one already working. Mirrors
 * admin_dashboard_trends()'s RETURNS TABLE column list exactly
 * (supabase/schema.sql).
 *
 * Two shapes of "yesterday" on purpose (Admin Dashboard restructure
 * spec, "การเปรียบเทียบข้อมูล"): the plain *_yesterday fields are
 * yesterday in full (00:00-23:59), while the *_yesterday_matched fields
 * stop at the same elapsed clock time as "now" -- comparing today (still
 * in progress) against a full yesterday would overstate or understate
 * every swing depending purely on what time it is right now, so
 * deltaPct() below is always called with the _matched figure, never the
 * plain one.
 */
export type AdminDashboardTrends = {
  new_users_yesterday: number;
  drops_yesterday: number;
  views_yesterday: number;
  likes_yesterday: number;
  comments_yesterday: number;
  redrops_yesterday: number;
  messages_yesterday: number;
  new_users_yesterday_matched: number;
  drops_yesterday_matched: number;
  views_yesterday_matched: number;
  likes_yesterday_matched: number;
  comments_yesterday_matched: number;
  redrops_yesterday_matched: number;
  messages_yesterday_matched: number;
  /** Section 1's "ผู้ใช้งานวันนี้" tile (DAU) needs this same comparison. */
  active_users_yesterday_matched: number;
};

export async function fetchAdminDashboardTrends(): Promise<AdminDashboardTrends> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_dashboard_trends").single();

  if (error || !data) {
    throw error ?? new Error("admin_dashboard_trends() returned no row");
  }

  return data as AdminDashboardTrends;
}

/**
 * "How many signups per day/week/month/year" -- admin_dashboard_metrics()'s
 * new_users_today only ever answers the "today" slice of that question.
 * Its own tiny RPC (mirrors admin_signup_counts()'s RETURNS TABLE
 * exactly) rather than more columns on an existing function, same
 * reasoning as AdminDashboardTrends above. all_time added for the
 * restructure spec's Section 3 "ทั้งหมด" row.
 */
export type SignupCounts = {
  today: number;
  this_week: number;
  this_month: number;
  this_year: number;
  all_time: number;
};

export async function fetchSignupCounts(): Promise<SignupCounts> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_signup_counts").single();

  if (error || !data) {
    throw error ?? new Error("admin_signup_counts() returned no row");
  }

  return data as SignupCounts;
}

/** One calendar day's point in an activity trend series. */
export type ActivityTrendDay = {
  day: string;
  active_users: number;
  engagement: number;
};

/**
 * Powers both Section 2's "Active Users Trend" and Section 4's
 * "Engagement Trend" (Admin Dashboard restructure spec) from one fetch
 * -- mirrors admin_activity_trend()'s RETURNS TABLE exactly
 * (supabase/schema.sql). Always fetched at the widest range (90 days);
 * the 7/30-day views are the client slicing this same array down, not
 * a second round trip -- see activity-trend-chart.tsx.
 */
export async function fetchAdminActivityTrend(days: number): Promise<ActivityTrendDay[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_activity_trend", { p_days: days });

  if (error || !data) {
    throw error ?? new Error("admin_activity_trend() returned no rows");
  }

  return data as ActivityTrendDay[];
}

/**
 * Yesterday=0 makes a percent delta meaningless (division by zero, or a
 * misleading "+∞%") -- null tells the UI to show "ใหม่" (brand new
 * activity) instead of a percentage, same convention
 * admin_dashboard_metrics() already uses for its own cohort-percent
 * columns.
 */
export function deltaPct(today: number, yesterday: number): number | null {
  if (yesterday === 0) return null;
  return Math.round(((today - yesterday) / yesterday) * 1000) / 10;
}
