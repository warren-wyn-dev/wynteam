import { createClient } from "@/lib/supabase/server";
import { encodeAuditCursor, nextBangkokDay, toBangkokMidnightIso } from "@/lib/audit-log-filters.mjs";

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
  created_at: string;
};

/** Read-only, minimal audit projection: do not serialize raw detail JSON (PII). */
export type AuditLogSafeRow = AuditLogRow;

export type AuditLogFilters = {
  eventType: string;
  actorId: string;
  from: string;
  to: string;
  cursor: { createdAt: string; id: string } | null;
};

export type AuditLogPageData = {
  rows: AuditLogSafeRow[];
  nextCursor: string | null;
};

export const AUDIT_LOG_PAGE_SIZE = 50;

/** Bounded keyset paging with deterministic timestamp+UUID order. */
export async function fetchAuditLogPage(filters: AuditLogFilters): Promise<AuditLogPageData> {
  const supabase = await createClient();
  let query = supabase
    .from("admin_audit_log")
    .select("id, actor_id, actor_username_snapshot, event_type, target_id, created_at")
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .limit(AUDIT_LOG_PAGE_SIZE + 1);

  if (filters.eventType) query = query.eq("event_type", filters.eventType);
  if (filters.actorId) query = query.eq("actor_id", filters.actorId);
  if (filters.from) query = query.gte("created_at", toBangkokMidnightIso(filters.from));
  if (filters.to) query = query.lt("created_at", toBangkokMidnightIso(nextBangkokDay(filters.to)));
  if (filters.cursor) {
    // Both values are strictly validated by parseAuditFilters(). Never use
    // arbitrary user strings inside an OR filter.
    const { createdAt, id } = filters.cursor;
    query = query.or(`created_at.lt.${createdAt},and(created_at.eq.${createdAt},id.lt.${id})`);
  }

  const { data, error } = await query;
  if (error) throw error;

  const rows = ((data ?? []) as AuditLogSafeRow[]).slice(0, AUDIT_LOG_PAGE_SIZE);
  return {
    rows,
    nextCursor: (data ?? []).length > AUDIT_LOG_PAGE_SIZE && rows.length > 0
      ? encodeAuditCursor({ created_at: rows[rows.length - 1].created_at, id: rows[rows.length - 1].id })
      : null,
  };
}
