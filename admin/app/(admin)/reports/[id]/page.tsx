import { notFound } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { ReportActionsBar } from "@/components/admin/report-actions-bar";
import { fetchReport, type ReportTargetType } from "@/lib/admin-reports";

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

const STATUS_LABEL: Record<string, string> = {
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

/**
 * Generic report detail -- reached only for target types WYN-051/052
 * don't already have a dedicated page for (user/drop route straight
 * there from the queue instead, see reports/results.tsx's hrefFor()).
 * No rich content preview this round (Product spec's explicit
 * Non-goal) -- raw report fields plus the same 6-action bar the
 * Flutter ModerationActionSheet already offers.
 */
export default async function ReportDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const report = await fetchReport(id);

  if (!report) notFound();

  return (
    <div className="flex flex-col gap-6 p-6">
      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-2xl font-bold">รายงาน{TARGET_TYPE_LABEL[report.target_type]}</h2>
          <Badge variant="outline">{STATUS_LABEL[report.status]}</Badge>
        </div>
        <p className="text-sm text-muted-foreground">
          Target ID: <span className="font-mono">{report.target_id}</span>
        </p>
      </div>

      <div className="grid max-w-md grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
        <span className="text-muted-foreground">หมวดหมู่</span>
        <span>{CATEGORY_LABEL[report.category] ?? report.category}</span>
        <span className="text-muted-foreground">รายละเอียด</span>
        <span>{report.detail ?? "—"}</span>
        <span className="text-muted-foreground">วันที่รายงาน</span>
        <span>{formatDate(report.created_at)}</span>
      </div>

      {report.status === "pending" || report.status === "reviewing" ? (
        <ReportActionsBar reportId={report.id} targetType={report.target_type} />
      ) : (
        <p className="text-sm text-muted-foreground">รายงานนี้ถูกดำเนินการไปแล้ว</p>
      )}
    </div>
  );
}
