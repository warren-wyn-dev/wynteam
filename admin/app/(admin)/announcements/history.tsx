import { fetchAnnouncementHistory } from "@/lib/admin-announcements";
import type { AnnouncementAudience, AnnouncementCategory } from "@/lib/admin-announcements";

const CATEGORY_LABEL: Record<AnnouncementCategory, string> = {
  system_update: "อัปเดตระบบ",
  policy_update: "อัปเดตนโยบาย",
  maintenance: "แจ้งปิดปรับปรุงระบบ",
  important: "ประกาศสำคัญ",
};

const AUDIENCE_LABEL: Record<AnnouncementAudience, string> = {
  all: "ทุกคน",
  users: "ผู้ใช้ทั่วไป",
  staff: "ทีมงาน",
};

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export async function AnnouncementHistory() {
  const rows = await fetchAnnouncementHistory();

  if (rows.length === 0) {
    return <p className="text-sm text-muted-foreground">ยังไม่เคยส่งประกาศ</p>;
  }

  return (
    <div className="overflow-x-auto rounded-lg border">
      <table className="w-full text-sm">
        <thead className="border-b bg-muted/40 text-left text-muted-foreground">
          <tr>
            <th className="px-4 py-2 font-medium">ประเภท</th>
            <th className="px-4 py-2 font-medium">กลุ่มผู้รับ</th>
            <th className="px-4 py-2 font-medium">ข้อความ</th>
            <th className="px-4 py-2 font-medium">จำนวนผู้รับ</th>
            <th className="px-4 py-2 font-medium">ผู้ส่ง</th>
            <th className="px-4 py-2 font-medium">วันที่</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.id} className="border-b last:border-0">
              <td className="px-4 py-2">{CATEGORY_LABEL[row.category] ?? row.category}</td>
              <td className="px-4 py-2">{AUDIENCE_LABEL[row.audience] ?? row.audience}</td>
              <td className="px-4 py-2 max-w-xs truncate">{row.message}</td>
              <td className="px-4 py-2">{row.recipientCount}</td>
              <td className="px-4 py-2 text-muted-foreground">{row.sentBy ?? "—"}</td>
              <td className="px-4 py-2 text-muted-foreground">{formatDate(row.createdAt)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
