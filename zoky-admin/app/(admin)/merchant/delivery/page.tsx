import { MerchantDeliverySettings } from "@/components/admin/merchant-delivery-settings";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { fetchMerchantDeliveryStores } from "@/lib/admin-merchant-delivery";

export default async function MerchantDeliveryPage() {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "merchant")) return <NoAccess what="ดูค่าส่ง WYNOS Merchant" />;
  let stores;
  try {
    stores = await fetchMerchantDeliveryStores();
  } catch (error) {
    const code = (error as { code?: string } | null)?.code;
    return <div className="p-6">
      <h1 className="text-xl font-semibold">ค่าส่งและรัศมีร้านอาหาร</h1>
      <p role="alert" className="mt-4 rounded-xl border border-dashed p-6 text-sm text-muted-foreground">
        {code === "PGRST202" || code === "42883"
          ? "เครื่องมือกำลังรอติดตั้งการอัปเดตฐานข้อมูล ยังไม่สามารถใช้ตั้งค่าจริงได้"
          : "โหลดข้อมูลร้านไม่สำเร็จ กรุณาลองใหม่หรือตรวจสอบสิทธิ์"}
      </p>
    </div>;
  }
  return (
    <div className="space-y-5 p-4 sm:p-6">
      <header className="space-y-1">
        <p className="text-xs text-muted-foreground">WYNOS Merchant / การจัดส่ง</p>
        <h1 className="text-2xl font-semibold">ค่าส่งและรัศมีรายร้าน</h1>
        <p className="text-sm text-muted-foreground">กำหนดค่าแบบเฉพาะร้านบน Backend จริง พร้อมสิทธิ์และประวัติการเปลี่ยนแปลง</p>
      </header>
      <MerchantDeliverySettings stores={stores} canEdit={adminCan(ctx,"merchant","edit")} />
    </div>
  );
}
