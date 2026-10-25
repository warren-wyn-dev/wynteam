import { UserCog } from "lucide-react";

import { NoAccess } from "@/components/admin/no-access";
import { ZokyTeamManager } from "@/components/admin/zoky-team-manager";
import { canManageZokyTeam, requireAdminRole } from "@/lib/auth";
import { fetchZokyTeam } from "@/lib/zoky-team";

/**
 * ทีม ZOKY (ZOKY-ADMIN-001): ZOKY Team Leads and the super admin grant and
 * revoke food/merchant permissions. Every write goes through the
 * admin_zoky_* RPCs, which re-check the caller and refuse other systems,
 * the caller's own rows, other Leads and the super admin.
 */
export default async function ZokyTeamPage() {
  const { userId, access } = await requireAdminRole();
  if (!canManageZokyTeam(access)) return <NoAccess what="จัดการทีม ZOKY" />;

  const members = await fetchZokyTeam();

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
      <section className="flex flex-col gap-1">
        <div className="flex items-center gap-2">
          <UserCog className="size-5" aria-hidden />
          <h2 className="text-xl font-semibold">สมาชิกและสิทธิ์ทีม ZOKY</h2>
        </div>
        <p className="text-sm text-muted-foreground">
          ให้หรือถอนสิทธิ์ ZOKY Food และ ZOKY Merchant แยกระดับ ดูอย่างเดียว / แก้ไขได้ ทุกการเปลี่ยนแปลงถูกบันทึกใน Audit Log
          — สิทธิ์ของหัวหน้าทีมและการแต่งตั้งหัวหน้าทีมทำได้เฉพาะ super admin ใน WYNOS Admin
        </p>
      </section>

      <ZokyTeamManager members={members} currentUserId={userId} superAdmin={access.superAdmin} />
    </div>
  );
}
