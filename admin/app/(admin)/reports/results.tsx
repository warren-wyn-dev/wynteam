import { Badge } from "@/components/ui/badge";
import { fetchQueue, type ReportStatus, type ReportTargetType } from "@/lib/admin-reports";

import { ClickableRow } from "./clickable-row";

const TARGET_TYPE_LABEL: Record<ReportTargetType, string> = {
  user: "ผู้ใช้",
  drop: "Drop",
  drop_comment: "คอมเมนต์ Drop",
  club: "Club",
  club_post: "โพสต์ Club",
  club_post_comment: "คอมเมนต์โพสต์ Club",
  message: "ข้อความ",
  redrop: "ReDrop",
};

const CATEGORY_LABEL: Record<string, string> = {
  spam: "สแปม",
  scam: "หลอกลวง",
  harassment: "คุกคาม",
  hate: "แสดงความเกลียดชัง",
  sexual_content: "เนื้อหาทางเพศ",
  violence: "ความรุนแรง",
  privacy: "ละเมิดความเป็นส่วนตัว",
  illegal_content: "เนื้อหาผิดกฎหมาย",
  copyright: "ละเมิดลิขสิทธิ์",
  other: "อื่นๆ",
};

const STATUS_LABEL: Record<ReportStatus, string> = {
  pending: "รอตรวจสอบ",
  reviewing: "กำลังตรวจสอบ",
  actioned: "ดำเนินการแล้ว",
  dismissed: "ยกเลิกแล้ว",
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

/** Row's destination: user/drop reports go to the existing dedicated
 * pages (WYN-051/052, which already show this exact report in their
 * own Reports table and offer full action UI there) -- everything else
 * goes to the generic /reports/[id] detail page. */
function hrefFor(row: { id: string; target_type: ReportTargetType; target_id: string }) {
  if (row.target_type === "user") return `/users/${row.target_id}`;
  if (row.target_type === "drop") return `/moderation/${row.target_id}`;
  return `/reports/${row.id}`;
}

export async function QueueResults({ status }: { status: string }) {
  const statuses: ReportStatus[] =
    status === "all"
      ? ["pending", "reviewing", "actioned", "dismissed"]
      : status === "actioned"
        ? ["actioned"]
        : status === "dismissed"
          ? ["dismissed"]
          : ["pending", "reviewing"];

  const rows = await fetchQueue(statuses);

  if (rows.length === 0) {
    return <p className="p-6 text-center text-muted-foreground">ไม่มีรายงานในหมวดนี้</p>;
  }

  return (
    <div className="overflow-x-auto rounded-lg border">
      <table className="w-full text-sm">
        <thead className="border-b bg-muted/40 text-left text-muted-foreground">
          <tr>
            <th className="px-4 py-2 font-medium">ประเภท</th>
            <th className="px-4 py-2 font-medium">หมวดหมู่</th>
            <th className="px-4 py-2 font-medium">รายละเอียด</th>
            <th className="px-4 py-2 font-medium">สถานะ</th>
            <th className="px-4 py-2 font-medium">วันที่</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <ClickableRow key={row.id} href={hrefFor(row)}>
              <td className="px-4 py-2">
                <Badge variant="outline">{TARGET_TYPE_LABEL[row.target_type]}</Badge>
              </td>
              <td className="px-4 py-2">{CATEGORY_LABEL[row.category] ?? row.category}</td>
              <td className="px-4 py-2 text-muted-foreground">{row.detail ?? "—"}</td>
              <td className="px-4 py-2">{STATUS_LABEL[row.status]}</td>
              <td className="px-4 py-2 text-muted-foreground">{formatDate(row.created_at)}</td>
            </ClickableRow>
          ))}
        </tbody>
      </table>
    </div>
  );
}
