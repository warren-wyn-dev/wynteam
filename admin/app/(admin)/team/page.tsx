import { KeyRound } from "lucide-react";

import { TeamPermissionsManager, type TeamMember } from "@/components/admin/team-permissions-manager";
import { fetchAdminAccess, fetchAdminPermissions } from "@/lib/admin-permissions";
import { searchUsers } from "@/lib/admin-users";
import { requireAdminRole } from "@/lib/auth";

/**
 * WYN-219 Phase 2 step 3: the super admin grants and revokes per-system
 * admin permissions. Every write goes through admin_grant_permission /
 * admin_revoke_permission, which re-check the super admin server-side.
 */
export default async function TeamPermissionsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  await requireAdminRole();
  const access = await fetchAdminAccess();

  if (!access.available || !access.superAdmin) {
    return (
      <div className="p-6">
        <p className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">
          {access.available
            ? "หน้านี้จัดการได้เฉพาะ super admin"
            : "ระบบสิทธิ์ทีมงานยังไม่ได้ติดตั้งในฐานข้อมูล (WYN-219)"}
        </p>
      </div>
    );
  }

  // Plain characters only: the search is passed into a PostgREST or() filter.
  const query = ((await searchParams).q ?? "").replace(/[^\p{L}\p{N}_.\s-]/gu, "").trim().slice(0, 40);
  const [rows, results] = await Promise.all([fetchAdminPermissions(), query ? searchUsers(query) : Promise.resolve([])]);

  const byUser = new Map<string, TeamMember>();
  for (const row of rows) {
    const member = byUser.get(row.user_id) ?? { userId: row.user_id, username: row.username, permissions: [] };
    member.permissions.push({ system: row.system, level: row.level });
    byUser.set(row.user_id, member);
  }

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-col gap-1">
        <div className="flex items-center gap-2">
          <KeyRound className="size-5" />
          <h2 className="text-xl font-semibold">สิทธิ์ทีมงาน</h2>
        </div>
        <p className="text-sm text-muted-foreground">
          ให้หรือถอนสิทธิ์ดูแลแต่ละระบบของ WYNOS แยกระดับ ดูอย่างเดียว / แก้ไขได้ เฉพาะ super admin เท่านั้นที่เห็นหน้านี้
        </p>
      </section>

      <TeamPermissionsManager
        members={[...byUser.values()]}
        candidates={results.map((u) => ({ userId: u.id, username: u.username, displayName: u.display_name }))}
        searched={query.length > 0}
      />
    </div>
  );
}
