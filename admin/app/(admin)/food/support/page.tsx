import { FoodSupportManager } from "@/components/admin/food-support-manager";
import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { fetchFoodSupportCases, type FoodSupportCase } from "@/lib/admin-food-support";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function FoodSupportPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="ศูนย์ช่วยเหลือ Food" />;
  let initial: FoodSupportCase[];
  try { initial = await fetchFoodSupportCases(); }
  catch {
    return <div className="space-y-3 p-6"><h1 className="text-2xl font-semibold">ศูนย์ช่วยเหลือลูกค้า</h1>
      <p role="alert" className="rounded-xl border p-4 text-sm">โหลดเคสไม่สำเร็จ กรุณาลองใหม่หรือตรวจสอบการติดตั้ง API</p><RefreshButton /></div>;
  }
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-1"><p className="text-xs text-muted-foreground">WYNOS Food / บริการลูกค้า</p>
      <h1 className="text-2xl font-semibold">ศูนย์ช่วยเหลือลูกค้า</h1>
      <p className="text-sm text-muted-foreground">รับเคส ผูกหลักฐานกับรายการอาหาร ตอบลูกค้า และทบทวนคำอุทธรณ์ โดยมีประวัติทุกการเปลี่ยนสถานะ</p></header>
    <FoodSupportManager initial={initial} canEdit={adminCan(ctx, "food", "edit")} />
  </div>;
}
