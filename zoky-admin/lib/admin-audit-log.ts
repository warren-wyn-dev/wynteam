import { createClient } from "@/lib/supabase/server";

export type AuditLogRow = {
  id: string;
  actor_id: string | null;
  actor_username_snapshot: string | null;
  event_type: string;
  target_id: string | null;
  detail: Record<string, unknown> | null;
  created_at: string;
};

/**
 * Audit rows about one store (Store Detail -> Activity Logs): rows whose
 * target is the store (suspend/unsuspend) or whose detail names it (team
 * changes). Same super-admin-only view as the Audit Log page in WYNOS Admin.
 */
export async function fetchStoreAuditLog(storeId: string): Promise<AuditLogRow[]> {
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
