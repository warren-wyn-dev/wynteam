import { FoodFeaturedManager } from "@/components/admin/food-featured-manager";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { getFoodFeaturedAdminData } from "@/lib/admin-food-featured";
import type { AdminFeaturedStore, AdminStoreOption } from "@/lib/admin-food-featured";

export default async function FoodFeaturedPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="จัดลำดับร้านแนะนำ Food" />;

  let rows: AdminFeaturedStore[] = [];
  let stores: AdminStoreOption[] = [];
  let loadError: unknown = null;
  try {
    const fetched = await getFoodFeaturedAdminData();
    rows = fetched.rows;
    stores = fetched.stores;
  } catch (error) {
    loadError = error;
  }

  if (loadError) {
    const code = (loadError as { code?: string } | null)?.code;
    return (
      <div className="space-y-3 p-6">
        <h1 className="text-xl font-semibold">ร้านแนะนำ Food</h1>
        <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
          {code === "PGRST202" || code === "42883"
            ? "รอการติดตั้งฐานข้อมูลร้านแนะนำ"
            : "โหลดข้อมูลไม่สำเร็จ ตรวจสอบสิทธิ์และการเชื่อมต่ออีกครั้ง"}
        </p>
      </div>
    );
  }
  return (
    <div className="space-y-5 p-4 sm:p-6">
      <header className="space-y-1">
        <p className="text-xs text-muted-foreground">WYNOS Food / หน้าแรก</p>
        <h1 className="text-2xl font-semibold">ร้านแนะนำและลำดับการแสดงผล</h1>
        <p className="text-sm text-muted-foreground">
          กำหนดร้านแนะนำที่จะปรากฏบนหน้าแรก Food เฉพาะในพื้นที่บริการที่ผู้ใช้มองเห็น ตามลำดับและช่วงเวลาที่ตั้งไว้
        </p>
      </header>
      <FoodFeaturedManager initial={rows} stores={stores} canEdit={adminCan(ctx, "food", "edit")} />
    </div>
  );
}
