import { createClient } from "@/lib/supabase/server";

export type ReportStatus = "pending" | "reviewing" | "actioned" | "dismissed";

export type ReportTargetType =
  | "user"
  | "drop"
  | "drop_comment"
  | "club"
  | "club_post"
  | "club_post_comment"
  | "message"
  | "redrop";

export type QueueRow = {
  id: string;
  target_type: ReportTargetType;
  target_id: string;
  category: string;
  detail: string | null;
  status: ReportStatus;
  created_at: string;
};

/** moderation_queue VIEW (WYN-029) -- unfiltered by target_type, unlike
 * WYN-051's/WYN-052's own per-target reads of the same view. Oldest
 * first ("Priority" for V1, per the Product spec -- there is no
 * severity/risk score anywhere in the schema to sort by instead). */
export async function fetchQueue(statuses: ReportStatus[]): Promise<QueueRow[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("moderation_queue")
    .select("id, target_type, target_id, category, detail, status, created_at")
    .in("status", statuses)
    .order("created_at", { ascending: true });

  if (error) throw error;
  return data ?? [];
}

export async function fetchReport(id: string): Promise<QueueRow | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("moderation_queue")
    .select("id, target_type, target_id, category, detail, status, created_at")
    .eq("id", id)
    .maybeSingle();

  if (error) throw error;
  return data;
}
