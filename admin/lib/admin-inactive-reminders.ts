import { fetchAuditLog } from "@/lib/admin-audit-log";

export { INACTIVE_DAY_OPTIONS } from "@/lib/admin-inactive-reminder-options";

export type InactiveReminderHistoryRow = {
  id: string;
  inactiveDays: number;
  message: string;
  recipientCount: number;
  createdAt: string;
  sentBy: string | null;
};

/** Sent reminders, read from admin_audit_log like the announcement history. */
export async function fetchInactiveReminderHistory(): Promise<InactiveReminderHistoryRow[]> {
  const rows = await fetchAuditLog("admin_inactive_reminder_sent");
  return rows.map((row) => {
    const detail = (row.detail ?? {}) as Record<string, unknown>;
    return {
      id: row.id,
      inactiveDays: Number(detail.inactive_days ?? 0),
      message: String(detail.message ?? ""),
      recipientCount: Number(detail.recipient_count ?? 0),
      createdAt: row.created_at,
      sentBy: row.actor_username_snapshot,
    };
  });
}
