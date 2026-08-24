import { fetchAuditLog, type AuditLogEventType } from "@/lib/admin-audit-log";

const EVENT_TYPE_LABEL: Record<AuditLogEventType, string> = {
  moderation_action_applied: "ดำเนินการตาม Report",
  appeal_decided: "ตัดสินการอุทธรณ์",
  system_notification_sent: "ส่งแจ้งเตือนระบบ (รายคน)",
  account_deleted: "ลบบัญชี",
  data_exported: "ส่งออกข้อมูล",
  admin_user_action_applied: "ดำเนินการผู้ใช้โดยตรง",
  admin_user_unbanned: "ยกเลิกบล็อกผู้ใช้",
  admin_content_removed: "ลบเนื้อหา (Admin)",
  admin_content_restored: "กู้คืนเนื้อหา (Admin)",
  admin_announcement_sent: "ส่งประกาศ",
};

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export async function AuditLogResults({ eventType }: { eventType?: AuditLogEventType }) {
  const rows = await fetchAuditLog(eventType);

  if (rows.length === 0) {
    return <p className="p-6 text-center text-muted-foreground">ไม่มีรายการในหมวดนี้</p>;
  }

  return (
    <div className="overflow-x-auto rounded-lg border">
      <table className="w-full text-sm">
        <thead className="border-b bg-muted/40 text-left text-muted-foreground">
          <tr>
            <th className="px-4 py-2 font-medium">ผู้ดำเนินการ</th>
            <th className="px-4 py-2 font-medium">เหตุการณ์</th>
            <th className="px-4 py-2 font-medium">Target ID</th>
            <th className="px-4 py-2 font-medium">รายละเอียด</th>
            <th className="px-4 py-2 font-medium">เวลา</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id} className="border-b align-top last:border-0">
              <td className="px-4 py-2">{row.actor_username_snapshot ?? "—"}</td>
              <td className="px-4 py-2">{EVENT_TYPE_LABEL[row.event_type] ?? row.event_type}</td>
              <td className="px-4 py-2 font-mono text-xs text-muted-foreground">
                {row.target_id ?? "—"}
              </td>
              <td className="px-4 py-2">
                {row.detail ? (
                  <pre className="max-w-md overflow-x-auto whitespace-pre-wrap break-words font-mono text-xs text-muted-foreground">
                    {JSON.stringify(row.detail, null, 2)}
                  </pre>
                ) : (
                  "—"
                )}
              </td>
              <td className="px-4 py-2 whitespace-nowrap text-muted-foreground">
                {formatDate(row.created_at)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
