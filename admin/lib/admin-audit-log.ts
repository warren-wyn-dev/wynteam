import { createClient } from "@/lib/supabase/server";

export type AuditLogEventType =
  | "moderation_action_applied"
  | "appeal_decided"
  | "system_notification_sent"
  | "account_deleted"
  | "data_exported"
  | "admin_user_action_applied"
  | "admin_user_unbanned"
  | "admin_content_removed"
  | "admin_content_restored"
  | "admin_announcement_sent"
  | "admin_inactive_reminder_sent";

export type AuditLogRow = {
  id: string;
  actor_id: string | null;
  actor_username_snapshot: string | null;
  event_type: AuditLogEventType;
  target_id: string | null;
  detail: Record<string, unknown> | null;
  created_at: string;
};

/** admin_audit_log VIEW (WYN-054) -- newest first, optionally filtered
 * to one event type. No pagination this round (Product spec's
 * Requirement 4) -- capped at 200 rows, same ceiling-precedent shape
 * as WYN-051/052's own search result limits, just scaled up since this
 * is a log meant to be skimmed chronologically. */
export async function fetchAuditLog(eventType?: AuditLogEventType): Promise<AuditLogRow[]> {
  const supabase = await createClient();
  let query = supabase
    .from("admin_audit_log")
    .select("id, actor_id, actor_username_snapshot, event_type, target_id, detail, created_at")
    .order("created_at", { ascending: false })
    .limit(200);

  if (eventType) query = query.eq("event_type", eventType);

  const { data, error } = await query;
  if (error) throw error;
  return data ?? [];
}

/**
 * Audit rows about one store (Store Detail -> Activity Logs): rows whose
 * target is the store (suspend/unsuspend) or whose detail names it (team
 * changes). Same super-admin-only view as the Audit Log page.
 */
export async function fetchStoreAuditLog(storeId: string): Promise<Array<Omit<AuditLogRow, "event_type"> & { event_type: string }>> {
  if (!/^[0-9a-f-]{36}$/i.test(storeId)) return [];
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_audit_log")
    .select("id, actor_id, actor_username_snapshot, event_type, target_id, detail, created_at")
    .or(`target_id.eq.${storeId},detail->>store_id.eq.${storeId}`)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return data ?? [];
}
