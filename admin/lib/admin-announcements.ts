import { fetchAuditLog } from "@/lib/admin-audit-log";

export type AnnouncementCategory = "system_update" | "policy_update" | "maintenance" | "important";
export type AnnouncementAudience = "all" | "users" | "staff";

export type AnnouncementHistoryRow = {
  id: string;
  category: AnnouncementCategory;
  audience: AnnouncementAudience;
  message: string;
  recipientCount: number;
  createdAt: string;
  sentBy: string | null;
};

/** History reads straight from admin_audit_log (WYN-054) filtered to
 * this one event type -- no parallel storage, per the Product spec's
 * Requirement 4. */
export async function fetchAnnouncementHistory(): Promise<AnnouncementHistoryRow[]> {
  const rows = await fetchAuditLog("admin_announcement_sent");
  return rows.map((row) => {
    const detail = (row.detail ?? {}) as Record<string, unknown>;
    return {
      id: row.id,
      category: detail.category as AnnouncementCategory,
      audience: detail.audience as AnnouncementAudience,
      message: String(detail.message ?? ""),
      recipientCount: Number(detail.recipient_count ?? 0),
      createdAt: row.created_at,
      sentBy: row.actor_username_snapshot,
    };
  });
}

