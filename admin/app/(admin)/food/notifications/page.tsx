import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireAdminRole } from "@/lib/auth";
import { FoodPromotionBroadcastManager, type BroadcastRow, type CouponChoice } from "@/components/admin/food-promotion-broadcast-manager";

export default async function FoodNotificationAdminPage() {
  const { role } = await requireAdminRole();
  const client = await createClient();
  const [list, coupons, scheduler] = await Promise.all([
    client.rpc("admin_food_promo_list"),
    role === "admin" ? client.rpc("admin_food_coupon_list") : Promise.resolve({ data: [], error: null }),
    client.rpc("admin_food_promo_scheduler_status"),
  ]);
  const unavailable = list.error?.code === "PGRST202" || list.error?.code === "42883";
  if (list.error && !unavailable) throw new Error(list.error.message);
  if (coupons.error && coupons.error.code !== "PGRST202" && coupons.error.code !== "42883") throw new Error(coupons.error.message);
  // Fail closed until the Admin-only health RPC is deployed and confirms the job is active.
  const schedulerState = scheduler.error ? "unknown" : (scheduler.data as { active?: boolean } | null)?.active === true ? "active" : "paused";
  return <main className="flex flex-col gap-5 p-6">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold">Food · การแจ้งเตือนโปรโมชัน</h1>
        <p className="mt-1 text-sm text-muted-foreground">สื่อสารเฉพาะ WYNOS Food; Push เฉพาะลูกค้าที่ยินยอมและมีอุปกรณ์ Food</p>
      </div>
      <Link href="/food/campaigns" className="rounded-lg border px-4 py-2 text-sm">แคมเปญ WYNOS</Link>
    </div>
    {unavailable && <p className="rounded-lg border p-4">Backend สำหรับโปรโมชันยังไม่ได้เปิดใช้งาน</p>}
    <FoodPromotionBroadcastManager canManage={role === "admin" && !unavailable} schedulerState={schedulerState}
      coupons={Array.isArray(coupons.data) ? (coupons.data as CouponChoice[]).filter(c => c.is_active) : []}
      initialRows={Array.isArray(list.data) ? list.data as BroadcastRow[] : []} />
  </main>;
}
