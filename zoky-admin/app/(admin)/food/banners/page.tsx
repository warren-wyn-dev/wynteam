import { FoodBannerManager } from "@/components/admin/food-banner-manager";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { fetchAdminFoodBanners, fetchAdminBannerStores } from "@/lib/admin-food-banners";

export default async function FoodBannersPage(){
  const ctx=await requireAdminRole();
  if(!adminCan(ctx,"food")) return <NoAccess what="จัดการแบนเนอร์ WYNOS Food"/>;
  let banners,stores;
  try {
    [banners,stores]=await Promise.all([fetchAdminFoodBanners(),fetchAdminBannerStores()]);
  }catch(error){
    const code=(error as {code?:string}|null)?.code;
    return <div className="p-6 space-y-3">
      <h1 className="text-xl font-semibold">แบนเนอร์หน้าแรก Food</h1>
      <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
        {code==="PGRST202"||code==="42883"
          ?"ระบบแบนเนอร์ยังไม่พร้อมเชื่อมต่อฐานข้อมูล"
          :"ดึงรายการแบนเนอร์ไม่สำเร็จ กรุณาตรวจสอบสิทธิ์หรือการเชื่อมต่อ"}
      </p>
    </div>;
  }
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-1">
      <p className="text-xs text-muted-foreground">WYNOS Food / การจัดหน้าแรก</p>
      <h1 className="text-2xl font-semibold">แบนเนอร์หน้าแรก Food</h1>
      <p className="text-sm text-muted-foreground">
        อัปโหลดภาพ จัดลำดับ ตั้งเวลา เปิด/ปิด และเชื่อมไปร้านอาหาร ข้อมูลมีผลกับหน้า Food หลังบันทึก
      </p>
    </header>
    <FoodBannerManager initial={banners} stores={stores} canEdit={adminCan(ctx,"food","edit")}/>
  </div>;
}
