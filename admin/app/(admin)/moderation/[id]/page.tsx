import { notFound } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { DropModerationActions } from "@/components/admin/drop-moderation-actions";
import {
  currentActiveRemoval,
  fetchDrop,
  fetchModerationHistoryForDrop,
  fetchReportsAgainstDrop,
} from "@/lib/admin-moderation";

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

const ACTION_LABEL: Record<string, string> = {
  no_action: "ไม่ดำเนินการ",
  warning: "ตักเตือน",
  remove_content: "ลบเนื้อหา",
  restrict: "จำกัดสิทธิ์",
  suspend: "ระงับบัญชี",
  ban: "แบน",
};

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default async function DropModerationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [drop, history, reports] = await Promise.all([
    fetchDrop(id),
    fetchModerationHistoryForDrop(id),
    fetchReportsAgainstDrop(id),
  ]);

  if (!drop) notFound();

  const isDeleted = drop.deleted_at !== null;
  const activeRemoval = isDeleted ? currentActiveRemoval(history) : null;

  return (
    <div className="flex flex-col gap-6 p-6">
      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-2xl font-bold">{drop.author_username}</h2>
          {isDeleted ? <Badge variant="destructive">ลบแล้ว</Badge> : null}
        </div>
      </div>

      <div className="flex justify-center overflow-hidden rounded-lg border bg-muted/40">
        {/* eslint-disable-next-line @next/next/no-img-element -- drop.image_url
            is a per-project Supabase storage URL; there is no real project
            yet to pin into next.config's images.remotePatterns. */}
        <img
          src={drop.image_url}
          alt={`Drop โดย ${drop.author_username}`}
          className="max-h-[32rem] w-full max-w-md object-contain"
        />
      </div>
      {drop.caption ? <p>{drop.caption}</p> : null}

      <div className="flex flex-col gap-2">
        <DropModerationActions dropId={drop.id} isDeleted={isDeleted} />
        {isDeleted ? (
          <p className="text-sm text-muted-foreground">
            {activeRemoval ? "ลบโดยผู้ดูแลระบบ" : "ลบโดยเจ้าของเอง"}
          </p>
        ) : null}
      </div>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">รายงานที่มีต่อ Drop นี้</h3>
        {reports.length === 0 ? (
          <p className="text-sm text-muted-foreground">ไม่มีรายงานต่อ Drop นี้</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead className="border-b bg-muted/40 text-left text-muted-foreground">
                <tr>
                  <th className="px-4 py-2 font-medium">หมวดหมู่</th>
                  <th className="px-4 py-2 font-medium">รายละเอียด</th>
                  <th className="px-4 py-2 font-medium">สถานะ</th>
                  <th className="px-4 py-2 font-medium">วันที่</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((r) => (
                  <tr key={r.id} className="border-b last:border-0">
                    <td className="px-4 py-2">{CATEGORY_LABEL[r.category] ?? r.category}</td>
                    <td className="px-4 py-2 text-muted-foreground">{r.detail ?? "—"}</td>
                    <td className="px-4 py-2">{r.status}</td>
                    <td className="px-4 py-2 text-muted-foreground">{formatDate(r.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">ประวัติการดำเนินการ</h3>
        {history.length === 0 ? (
          <p className="text-sm text-muted-foreground">ยังไม่มีประวัติการดำเนินการ</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead className="border-b bg-muted/40 text-left text-muted-foreground">
                <tr>
                  <th className="px-4 py-2 font-medium">การดำเนินการ</th>
                  <th className="px-4 py-2 font-medium">เหตุผล</th>
                  <th className="px-4 py-2 font-medium">ผู้ดำเนินการ</th>
                  <th className="px-4 py-2 font-medium">วันที่</th>
                  <th className="px-4 py-2 font-medium">สถานะ</th>
                </tr>
              </thead>
              <tbody>
                {history.map((h) => (
                  <tr key={h.id} className="border-b last:border-0">
                    <td className="px-4 py-2">{ACTION_LABEL[h.action_type] ?? h.action_type}</td>
                    <td className="px-4 py-2 text-muted-foreground">{h.reason}</td>
                    <td className="px-4 py-2 text-muted-foreground">{h.reviewer_username}</td>
                    <td className="px-4 py-2 text-muted-foreground">{formatDate(h.created_at)}</td>
                    <td className="px-4 py-2">
                      {h.overturned_at ? <Badge variant="secondary">ถูกยกเลิกแล้ว</Badge> : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
