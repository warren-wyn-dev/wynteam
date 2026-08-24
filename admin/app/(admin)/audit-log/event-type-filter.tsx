"use client";

import { useRouter, useSearchParams } from "next/navigation";

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

const EVENT_TYPES = [
  { value: "all", label: "ทุกประเภท" },
  { value: "moderation_action_applied", label: "ดำเนินการตาม Report" },
  { value: "appeal_decided", label: "ตัดสินการอุทธรณ์" },
  { value: "system_notification_sent", label: "ส่งแจ้งเตือนระบบ (รายคน)" },
  { value: "account_deleted", label: "ลบบัญชี" },
  { value: "data_exported", label: "ส่งออกข้อมูล" },
  { value: "admin_user_action_applied", label: "ดำเนินการผู้ใช้โดยตรง" },
  { value: "admin_user_unbanned", label: "ยกเลิกบล็อกผู้ใช้" },
  { value: "admin_content_removed", label: "ลบเนื้อหา (Admin)" },
  { value: "admin_content_restored", label: "กู้คืนเนื้อหา (Admin)" },
  { value: "admin_announcement_sent", label: "ส่งประกาศ" },
];

export function EventTypeFilter() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const current = searchParams.get("event_type") ?? "all";

  return (
    <Select
      value={current}
      onValueChange={(value) => {
        router.push(value === "all" ? "/audit-log" : `/audit-log?event_type=${value}`);
      }}
    >
      <SelectTrigger className="w-64" aria-label="กรองตามประเภทเหตุการณ์">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {EVENT_TYPES.map((opt) => (
          <SelectItem key={opt.value} value={opt.value}>
            {opt.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
