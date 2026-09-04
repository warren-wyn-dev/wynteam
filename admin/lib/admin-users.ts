import { createClient } from "@/lib/supabase/server";

export type UserSearchResult = {
  id: string;
  username: string;
  display_name: string | null;
  platform_role: "user" | "moderator" | "admin";
};

/** profiles' own SELECT policy (`using (true)`) already lets any
 * authenticated caller read any profile -- no new RPC needed for
 * search itself, per the Design spec's Screen 1. */
export async function searchUsers(query: string): Promise<UserSearchResult[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, username, display_name, platform_role")
    .or(`username.ilike.%${query}%,display_name.ilike.%${query}%`)
    .order("username")
    .limit(30);

  if (error) throw error;
  return data ?? [];
}

export type UserProfile = {
  id: string;
  username: string;
  display_name: string | null;
  bio: string | null;
  platform_role: "user" | "moderator" | "admin";
  created_at: string;
};

export async function fetchUserProfile(userId: string): Promise<UserProfile | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, username, display_name, bio, platform_role, created_at")
    .eq("id", userId)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export type ModerationHistoryRow = {
  id: string;
  target_user_id: string;
  action_type: "warning" | "restrict" | "suspend" | "ban";
  reason: string;
  duration_days: number | null;
  expires_at: string | null;
  overturned_at: string | null;
  created_at: string;
  reviewer_username: string;
};

/** admin_user_moderation_history VIEW (WYN-051) -- newest first. */
export async function fetchModerationHistory(userId: string): Promise<ModerationHistoryRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_user_moderation_history")
    .select("*")
    .eq("target_user_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

/** The single currently-active restrict/suspend/ban row (if any) --
 * derived client-side from the history list rather than a separate
 * RPC, per the Design spec's Screen 2 header requirement. */
export function currentActiveAction(
  history: ModerationHistoryRow[],
): ModerationHistoryRow | null {
  const now = Date.now();
  return (
    history.find(
      (row) =>
        row.overturned_at === null &&
        (row.action_type === "ban" ||
          (["restrict", "suspend"].includes(row.action_type) &&
            row.expires_at !== null &&
            new Date(row.expires_at).getTime() > now)),
    ) ?? null
  );
}

export type DirectorySort = "newest" | "oldest" | "most_active" | "dormant";
export type DirectoryStatus = "normal" | "restrict" | "suspend" | "ban";

export type DirectoryUser = {
  id: string;
  username: string;
  display_name: string | null;
  platform_role: "user" | "moderator" | "admin";
  created_at: string;
  last_active_at: string | null;
  activity_count: number;
  current_status: DirectoryStatus;
};

/**
 * The "wide-angle" view -- rank/filter every user by activity or
 * status, no username typed. Mirrors admin_user_directory()'s
 * RETURNS TABLE column list exactly (supabase/schema.sql). Separate
 * from searchUsers() on purpose: that one is a plain `profiles` select
 * (its own SELECT policy already allows it, no RPC needed) with no
 * activity/status computed, so keeping this as its own RPC+fetcher
 * avoids overloading searchUsers()'s simpler contract.
 */
export async function fetchUserDirectory(params: {
  sort?: DirectorySort;
  role?: "user" | "moderator" | "admin";
  status?: DirectoryStatus;
}): Promise<DirectoryUser[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_user_directory", {
    p_sort: params.sort ?? "newest",
    p_role: params.role ?? null,
    p_status: params.status ?? null,
  });

  if (error) throw error;
  return data ?? [];
}

export type ReportRow = {
  id: string;
  category: string;
  detail: string | null;
  status: "pending" | "reviewing" | "actioned" | "dismissed";
  created_at: string;
};

/** Reuses the existing moderation_queue VIEW (WYN-029) filtered to
 * this one user as target -- reporter identity is structurally
 * unreachable there already, see the Product spec's Requirement 1. */
export async function fetchReportsAgainstUser(userId: string): Promise<ReportRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("moderation_queue")
    .select("id, category, detail, status, created_at")
    .eq("target_type", "user")
    .eq("target_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}
