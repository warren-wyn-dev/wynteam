import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import {
  fetchUserDirectory,
  type DirectorySort,
  type DirectoryStatus,
} from "@/lib/admin-users";

const ROLE_LABEL: Record<string, string> = {
  admin: "Admin",
  moderator: "Moderator",
  user: "User",
};

// Same weight-based hierarchy as results.tsx / [id]/page.tsx -- per
// wyn-admin-design-system.md section 6.2.
const ROLE_BADGE_VARIANT: Record<string, "ink-solid" | "gray-tonal" | "outline"> = {
  admin: "ink-solid",
  moderator: "gray-tonal",
  user: "outline",
};

const STATUS_LABEL: Record<DirectoryStatus, string> = {
  normal: "ปกติ",
  restrict: "ถูกจำกัด",
  suspend: "ถูกระงับ",
  ban: "ถูกแบน",
};

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("th-TH", { year: "numeric", month: "short", day: "numeric" });
}

export async function UserDirectory({
  sort,
  role,
  status,
}: {
  sort: DirectorySort;
  role?: "user" | "moderator" | "admin";
  status?: DirectoryStatus;
}) {
  const users = await fetchUserDirectory({ sort, role, status });

  if (users.length === 0) {
    return <p className="p-6 text-center text-muted-foreground">ไม่มีผู้ใช้ที่ตรงกับตัวกรองนี้</p>;
  }

  return (
    <div className="overflow-x-auto rounded-lg border">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b bg-muted/40 text-left text-xs font-medium text-muted-foreground">
            <th className="px-4 py-2">ผู้ใช้</th>
            <th className="px-4 py-2">สิทธิ์</th>
            <th className="px-4 py-2">สถานะ</th>
            <th className="px-4 py-2">สมัครเมื่อ</th>
            <th className="px-4 py-2">ใช้งานล่าสุด</th>
            <th className="px-4 py-2 text-right">กิจกรรมทั้งหมด</th>
          </tr>
        </thead>
        <tbody className="divide-y">
          {users.map((u) => (
            <tr key={u.id} className="hover:bg-accent">
              <td className="px-4 py-3">
                <Link href={`/users/${u.id}`} className="hover:underline">
                  <p className="font-medium">{u.username}</p>
                  {u.display_name ? (
                    <p className="text-xs text-muted-foreground">{u.display_name}</p>
                  ) : null}
                </Link>
              </td>
              <td className="px-4 py-3">
                <Badge variant={ROLE_BADGE_VARIANT[u.platform_role] ?? "outline"}>
                  {ROLE_LABEL[u.platform_role]}
                </Badge>
              </td>
              <td className="px-4 py-3">
                {u.current_status === "normal" ? (
                  <span className="text-muted-foreground">ปกติ</span>
                ) : (
                  <Badge variant="destructive">{STATUS_LABEL[u.current_status]}</Badge>
                )}
              </td>
              <td className="px-4 py-3 text-muted-foreground">{formatDate(u.created_at)}</td>
              <td className="px-4 py-3 text-muted-foreground">
                {u.last_active_at ? formatDate(u.last_active_at) : "ยังไม่เคย"}
              </td>
              <td className="px-4 py-3 text-right tabular-nums">
                {u.activity_count.toLocaleString("th-TH")}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {users.length === 50 ? (
        <p className="border-t px-4 py-2 text-xs text-muted-foreground">
          แสดง 50 รายการแรกตามตัวกรอง — ใช้ตัวกรองเพิ่มเติมถ้าต้องการเจาะจงกว่านี้
        </p>
      ) : null}
    </div>
  );
}
