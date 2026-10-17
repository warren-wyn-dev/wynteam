import { AdminMerchantMenuEditor } from "@/components/admin/merchant-menu-editor";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { fetchAdminMerchantMenuCatalog } from "@/lib/admin-merchant-menu";

export default async function MerchantMenuPage(){
  const ctx=await requireAdminRole();
  if(!adminCan(ctx,"merchant"))return <NoAccess what="ดูเมนู WYNOS Merchant"/>;
  let rows;
  try { rows=await fetchAdminMerchantMenuCatalog(); }
  catch(err){
    const code=(err as {code?:string}|null)?.code;
    return <div className="p-6 space-y-4">
      <h1 className="text-xl font-semibold">จัดการเมนูอาหาร</h1>
      <p role="alert" className="rounded-xl border border-dashed p-6 text-sm text-muted-foreground">
        {code==="PGRST202"||code==="42883"?"กำลังรอติดตั้ง Backend สำหรับจัดการเมนู ยังไม่พร้อมใช้งาน":"โหลดเมนูไม่ได้ โปรดตรวจสอบสิทธิ์และลองอีกครั้ง"}
      </p>
    </div>;
  }
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-1">
      <p className="text-xs text-muted-foreground">WYNOS Merchant / จัดการเมนู</p>
      <h1 className="text-2xl font-semibold">เมนูอาหารทุกร้าน</h1>
      <p className="text-sm text-muted-foreground">แก้ข้อมูลเมนูที่ลูกค้าเห็นได้จากศูนย์กลาง พร้อมตรวจสิทธิ์และประวัติการเปลี่ยนแปลง</p>
    </header>
    <AdminMerchantMenuEditor original={rows} canEdit={adminCan(ctx,"merchant","edit")} />
  </div>;
}
