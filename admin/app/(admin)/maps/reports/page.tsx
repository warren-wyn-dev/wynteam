import { MapsReportsManager } from "@/components/admin/maps-reports-manager";
import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { fetchAdminMapReports, type AdminMapReport } from "@/lib/admin-maps-reports";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function MapsReportsPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "maps")) return <NoAccess what="รายงานสถานที่ WYNOS Maps" />;
  let reports: AdminMapReport[];
  try { reports = await fetchAdminMapReports(); }
  catch { return <div className="space-y-3 p-6"><h1 className="text-2xl font-semibold">รายงานสถานที่</h1>
    <p role="alert" className="rounded-xl border p-4 text-sm">โหลดรายงานไม่สำเร็จ กรุณาลองใหม่หรือตรวจสอบการติดตั้ง API</p><RefreshButton /></div>; }
  return <div className="space-y-5 p-4 sm:p-6"><header className="space-y-1"><p className="text-xs text-muted-foreground">WYNOS Maps / ตรวจสอบรายงาน</p>
    <h1 className="text-2xl font-semibold">รายงานสถานที่</h1><p className="text-sm text-muted-foreground">ตรวจข้อมูลจากผู้ใช้ รับเรื่อง และบันทึกผลการตรวจสอบโดยเจ้าหน้าที่</p></header>
    <MapsReportsManager initial={reports} canEdit={adminCan(ctx, "maps", "edit")} />
  </div>;
}
