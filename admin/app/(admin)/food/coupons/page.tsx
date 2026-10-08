import Link from "next/link";
import { requireAdminRole } from "@/lib/auth";
import { fetchAdminPlatformCampaigns } from "@/lib/admin-platform-campaigns";
import { createClient } from "@/lib/supabase/server";
import { FoodCouponManager, type FoodCouponRow } from "@/components/admin/food-coupon-manager";

export default async function FoodCouponsPage() {
  const { role } = await requireAdminRole();
  const supabase = await createClient();
  const [campaigns, res] = await Promise.all([
    fetchAdminPlatformCampaigns(),
    supabase.rpc("admin_food_coupon_list"),
  ]);
  if (res.error && res.error.code !== "PGRST202" && res.error.code !== "42883") {
    throw new Error(res.error.message);
  }
  return (
    <main className="flex flex-col gap-5 p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Food · โค้ดส่วนลด</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            ผูกโค้ดกับแคมเปญ WYNOS เดิม ไม่เปลี่ยนโครงสร้างราคาและการจ่ายเงินของร้าน
          </p>
        </div>
        <Link href="/food/campaigns" className="rounded-lg border px-4 py-2 text-sm">กลับไปแคมเปญ</Link>
      </div>
      {res.error ? <p className="rounded-lg border px-4 py-3 text-sm">ระบบคูปองยังไม่เปิดในฐานข้อมูล Production</p> : null}
      <FoodCouponManager canManage={role === "admin"} campaigns={campaigns.map(c => ({
        id: c.id, name: c.name, starts_at: c.starts_at, ends_at: c.ends_at,
        joined_stores: c.joined_stores, delivered_orders: c.delivered_orders,
      }))} initialCoupons={Array.isArray(res.data) ? res.data as FoodCouponRow[] : []} />
    </main>
  );
}
