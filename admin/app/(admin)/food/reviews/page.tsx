import { NoAccess } from "@/components/admin/no-access";
import { FoodReviewModeration } from "@/components/admin/food-review-moderation";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { fetchFoodReviewModerationRows } from "@/lib/admin-food-reviews";
import type { FoodReviewModerationRow } from "@/lib/admin-food-reviews";

export default async function FoodReviewsPage() {
  const ctx=await requireAdminRole();
  if(!adminCan(ctx,"food"))return <NoAccess what="จัดการรีวิว Food"/>;
  let rows:FoodReviewModerationRow[]=[];
  let loadError:unknown=null;
  try{rows=await fetchFoodReviewModerationRows();}
  catch(error){loadError=error;}
  if(loadError)return <div className="p-6 space-y-3">
    <h1 className="text-xl font-semibold">ตรวจสอบรีวิวร้านอาหาร</h1>
    <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
      {((loadError as {code?:string}|null)?.code==="PGRST202")?"กำลังรอติดตั้ง API ตรวจสอบรีวิว":
       "โหลดรีวิวไม่สำเร็จ กรุณาตรวจสอบสิทธิ์หรือการเชื่อมต่อ"}
    </p>
  </div>;
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-1">
      <p className="text-xs text-muted-foreground">WYNOS Food / ตรวจสอบเนื้อหา</p>
      <h1 className="text-2xl font-semibold">รีวิวร้านอาหาร</h1>
      <p className="text-sm text-muted-foreground">
        ดูรีวิวล่าสุด 200 รายการ ซ่อนหรือคืนการแสดงผลโดยระบุเหตุผล พร้อม Audit Log โดยไม่แก้ข้อความหรือคะแนนที่ลูกค้าให้
      </p>
    </header>
    <FoodReviewModeration initial={rows} canEdit={adminCan(ctx,"food","edit")}/>
  </div>;
}
