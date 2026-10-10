import { requireAdminRole } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { AuditLogSafeRow } from "@/lib/admin-audit-log";

/**
 * Historical announcement/reminder screens need their own message metadata.
 * NEVER reuse this detail-bearing projection for the general Audit Log UI.
 * The event-type allowlist is enforced at runtime in addition to TypeScript.
 */
export type AdminMessageHistoryType = "admin_announcement_sent" | "admin_inactive_reminder_sent";

export type AdminMessageHistoryRow = AuditLogSafeRow & {
  detail: Record<string, unknown> | null;
};

export async function fetchAdminMessageHistory(
  eventType: AdminMessageHistoryType,
): Promise<AdminMessageHistoryRow[]> {
  await requireAdminRole();
  if (eventType !== "admin_announcement_sent" && eventType !== "admin_inactive_reminder_sent") {
    throw new Error("Unsupported staff history type");
  }
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("admin_audit_log")
    .select("id, actor_id, actor_username_snapshot, event_type, target_id, detail, created_at")
    .eq("event_type", eventType)
    .order("created_at", { ascending: false })
    .limit(200);

  if (error) throw error;
  return (data ?? []) as AdminMessageHistoryRow[];
}
