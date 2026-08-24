import { notFound } from "next/navigation";

import { Badge } from "@/components/ui/badge";
import { UserActionsBar } from "@/components/admin/user-actions-bar";
import {
  currentActiveAction,
  fetchModerationHistory,
  fetchReportsAgainstUser,
  fetchUserProfile,
} from "@/lib/admin-users";

const ROLE_LABEL: Record<string, string> = {
  admin: "Admin",
  moderator: "Moderator",
  user: "User",
};

const ACTION_LABEL: Record<string, string> = {
  warning: "Warn",
  restrict: "Restrict",
  suspend: "Suspend",
  ban: "Ban",
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

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("th-TH", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;

  const [profile, history, reports] = await Promise.all([
    fetchUserProfile(id),
    fetchModerationHistory(id),
    fetchReportsAgainstUser(id),
  ]);

  if (!profile) notFound();

  const active = currentActiveAction(history);

  return (
    <div className="flex flex-col gap-6 p-6">
      <div className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <h2 className="text-2xl font-bold">{profile.username}</h2>
          <Badge variant="outline">{ROLE_LABEL[profile.platform_role]}</Badge>
          {active ? (
            <Badge variant="destructive">
              {active.action_type === "ban"
                ? "Banned"
                : `${ACTION_LABEL[active.action_type]} ถึง ${formatDate(active.expires_at!)}`}
            </Badge>
          ) : null}
        </div>
        {profile.display_name ? (
          <p className="text-muted-foreground">{profile.display_name}</p>
        ) : null}
      </div>

      <UserActionsBar userId={profile.id} username={profile.username} isCurrentlyBlocked={active !== null} />

      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">รายงานที่มีต่อผู้ใช้นี้</h3>
        {reports.length === 0 ? (
          <p className="text-sm text-muted-foreground">ไม่มีรายงานต่อผู้ใช้นี้</p>
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
                  <th className="px-4 py-2 font-medium">ระยะเวลา</th>
                  <th className="px-4 py-2 font-medium">ผู้ดำเนินการ</th>
                  <th className="px-4 py-2 font-medium">วันที่</th>
                  <th className="px-4 py-2 font-medium">สถานะ</th>
                </tr>
              </thead>
              <tbody>
                {history.map((h) => (
                  <tr key={h.id} className="border-b last:border-0">
                    <td className="px-4 py-2">{ACTION_LABEL[h.action_type]}</td>
                    <td className="px-4 py-2 text-muted-foreground">{h.reason}</td>
                    <td className="px-4 py-2 text-muted-foreground">
                      {h.duration_days ? `${h.duration_days} วัน` : "—"}
                    </td>
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
