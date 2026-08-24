import { createClient } from "@/lib/supabase/server";

export type DropSearchResult = {
  id: string;
  image_url: string;
  caption: string | null;
  author_id: string;
  author_username: string;
  deleted_at: string | null;
  created_at: string;
};

/** admin_search_drops() RPC (WYN-052) -- SECURITY DEFINER, bypasses
 * drops' own SELECT policy (block/private-account/deleted gating)
 * entirely so Admin/Moderator can search every Drop, per the Product
 * spec's Requirement 3. */
export async function searchDrops(query: string): Promise<DropSearchResult[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_search_drops", { p_query: query });
  if (error) throw error;
  return data ?? [];
}

/** admin_get_drop() RPC (WYN-052) -- same bypass/authorization shape as
 * searchDrops() above, for navigating straight to /moderation/[id]. */
export async function fetchDrop(dropId: string): Promise<DropSearchResult | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_get_drop", { p_drop_id: dropId });
  if (error) throw error;
  return data?.[0] ?? null;
}

export type ReportRow = {
  id: string;
  category: string;
  detail: string | null;
  status: "pending" | "reviewing" | "actioned" | "dismissed";
  created_at: string;
};

/** Reuses the existing moderation_queue VIEW (WYN-029), same pattern as
 * WYN-051's fetchReportsAgainstUser -- reporter identity is
 * structurally unreachable there already. */
export async function fetchReportsAgainstDrop(dropId: string): Promise<ReportRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("moderation_queue")
    .select("id, category, detail, status, created_at")
    .eq("target_type", "drop")
    .eq("target_id", dropId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export type ModerationHistoryRow = {
  id: string;
  action_type: "no_action" | "warning" | "remove_content" | "restrict" | "suspend" | "ban";
  reason: string;
  overturned_at: string | null;
  created_at: string;
  reviewer_username: string;
};

/** admin_user_moderation_history VIEW (WYN-051), extended by WYN-052
 * with target_content_id -- filtered to this one Drop instead of a
 * user, newest first. */
export async function fetchModerationHistoryForDrop(
  dropId: string,
): Promise<ModerationHistoryRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_user_moderation_history")
    .select("id, action_type, reason, overturned_at, created_at, reviewer_username")
    .eq("target_content_id", dropId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

/** Is there a still-active ('overturned_at is null') moderation
 * remove_content action against this Drop? If so it was removed by an
 * Admin/Moderator (restore_drop()'s own guard, WYN-052, rejects the
 * author's self-restore for exactly this reason) -- otherwise a
 * deleted Drop was self-deleted by its own author. Drives Screen 2's
 * "ลบโดยผู้ดูแลระบบ" / "ลบโดยเจ้าของเอง" helper text. */
export function currentActiveRemoval(
  history: ModerationHistoryRow[],
): ModerationHistoryRow | null {
  return (
    history.find((row) => row.action_type === "remove_content" && row.overturned_at === null) ??
    null
  );
}
