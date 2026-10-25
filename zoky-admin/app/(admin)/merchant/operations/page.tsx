import { MerchantStoreOperations } from "@/components/admin/merchant-store-operations";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan,requireAdminRole } from "@/lib/auth";
import { fetchMerchantStoreOps } from "@/lib/admin-merchant-store-ops";
import type { MerchantStoreOps } from "@/lib/admin-merchant-store-ops";

export default async function MerchantOperationsPage(){
 const ctx=await requireAdminRole();
 if(!adminCan(ctx,"merchant"))return <NoAccess what="จัดการสถานะร้านอาหาร"/>;
 let stores:MerchantStoreOps[]=[];
 let loadError:unknown=null;
 try { stores=await fetchMerchantStoreOps(); } catch(err){ loadError=err; }
 if(loadError){
  const code=(loadError as {code?:string}|null)?.code;
  return <div className="space-y-3 p-6">
   <h1 className="text-xl font-semibold">สถานะร้านและการเตรียมอาหาร</h1>
   <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
    {code==="PGRST202"||code==="42883"?"ระบบตั้งค่าร้านยังไม่พร้อมเชื่อม Backend":"ไม่สามารถโหลดข้อมูลร้านได้ กรุณาตรวจสอบสิทธิ์และลองอีกครั้ง"}
   </p>
  </div>;
 }
 return <div className="space-y-5 p-4 sm:p-6">
  <header className="space-y-1">
   <p className="text-xs text-muted-foreground">WYNOS Merchant / การดำเนินงาน</p>
   <h1 className="text-2xl font-semibold">เปิด–ปิดร้านและเวลาการเตรียมอาหาร</h1>
   <p className="text-sm text-muted-foreground">ควบคุมการเปิดรับออเดอร์ใหม่ การปิดร้านชั่วคราว และเวลาเตรียมอาหารผ่าน Backend เดียวกับร้านค้า โดยไม่กระทบคำสั่งซื้อเดิม</p>
  </header>
  <MerchantStoreOperations initial={stores} canEdit={adminCan(ctx,"merchant","edit")}/>
 </div>;
}
