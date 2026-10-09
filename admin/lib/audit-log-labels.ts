import type { AuditLogEventType } from "@/lib/admin-audit-log";

export const AUDIT_EVENT_LABELS: Record<AuditLogEventType, string> = {
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
  admin_inactive_reminder_sent: "เตือนผู้ใช้ที่ไม่ได้ใช้งาน",
};
