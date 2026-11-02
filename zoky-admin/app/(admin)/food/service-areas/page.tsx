import { NoAccess } from "@/components/admin/no-access";
import { ServiceAreaManager } from "@/components/admin/service-area-manager";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { getServiceAreas, type ServiceAreaData } from "@/lib/admin-service-areas";

export default async function FoodServiceAreasPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="พื้นที่ให้บริการ ZOKY" />;

  let data: ServiceAreaData | null = null;
  let loadError: unknown = null;
  try {
    data = await getServiceAreas();
  } catch (error) {
    loadError = error;
  }

  return (
    <div className="space-y-5 p-4 sm:p-6">
      <header className="space-y-1">
        <p className="text-xs text-muted-foreground">ZOKY Food / การปฏิบัติการ</p>
        <h1 className="text-2xl font-semibold">พื้นที่ให้บริการ</h1>
        <p className="text-sm text-muted-foreground">
          เลือกว่าลูกค้าสั่งอาหารและร้านเปิดขายได้ที่ไหน: ทั้งประเทศ หรือเฉพาะจังหวัดที่เปิดไว้ ร้านยังส่งได้เฉพาะในรัศมีของร้านเองเหมือนเดิม
        </p>
      </header>
      {loadError || !data ? (
        <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
          {(loadError as { code?: string } | null)?.code === "PGRST202" || (loadError as { code?: string } | null)?.code === "42883"
            ? "รอการติดตั้งฐานข้อมูลพื้นที่ให้บริการ"
            : "โหลดข้อมูลไม่สำเร็จ ตรวจสอบสิทธิ์และการเชื่อมต่ออีกครั้ง"}
        </p>
      ) : (
        <ServiceAreaManager initial={data} />
      )}
    </div>
  );
}
