import Link from "next/link";
import { Ban, Gift, MapPinned, Megaphone, ReceiptText, ShoppingBag, Store, Wallet } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { StatCard } from "@/components/admin/stat-card";
import {
  fetchAdminFoodOverview,
  fetchAdminFoodStores,
  formatBaht,
  formatThaiDate,
  type AdminFoodStore,
} from "@/lib/admin-food";
import { requireAdminRole } from "@/lib/auth";

function storeStatus(store: AdminFoodStore) {
  if (store.admin_suspended_at) return <Badge variant="destructive">ระงับโดย WYNOS</Badge>;
  if (!store.is_published) return <Badge variant="outline">ยังไม่เผยแพร่</Badge>;
  return <Badge variant={store.is_open ? "ink-solid" : "gray-tonal"}>{store.is_open ? "เปิดรับออเดอร์" : "ปิดอยู่"}</Badge>;
}

/** WYN-203: overview of every WYNOS Food store (admin + moderator). */
export default async function FoodStoresPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { role } = await requireAdminRole();
  const { q } = await searchParams;
  const [overview, stores] = await Promise.all([fetchAdminFoodOverview(), fetchAdminFoodStores(q)]);

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-col gap-1">
        <h2 className="text-xl font-semibold">ร้านค้า WYNOS Food</h2>
        <p className="text-sm text-muted-foreground">ภาพรวมร้าน ออเดอร์ และยอดขาย ระงับร้านที่มีปัญหา และดูออเดอร์เมื่อมีเรื่องร้องเรียน</p>
      </section>

      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatCard label="ร้านทั้งหมด" value={overview.stores_total} icon={Store} sublabel={`เผยแพร่ ${overview.stores_published} · เปิดอยู่ ${overview.stores_open}`} />
        <StatCard label="ออเดอร์วันนี้" value={overview.orders_today} icon={ReceiptText} sublabel={`กำลังดำเนินการ ${overview.active_orders}`} />
        <StatCard label="ยอดขายวันนี้ (บาท)" value={Number(overview.sales_today)} icon={Wallet} sublabel="นับเฉพาะออเดอร์ที่ส่งแล้ว" />
        <StatCard label="ร้านที่ถูกระงับ" value={overview.stores_suspended} icon={Ban} />
      </section>

      <section className="rounded-xl border p-4">
        <h3 className="mb-3 text-sm font-semibold">7 วันล่าสุด</h3>
        <div className="grid grid-cols-7 gap-2 text-center text-xs">
          {overview.days.map((day) => (
            <div key={day.day} className="flex flex-col gap-1 rounded-lg bg-muted/50 p-2">
              <span className="text-muted-foreground">{new Intl.DateTimeFormat("th-TH", { day: "numeric", month: "short" }).format(new Date(`${day.day}T00:00:00`))}</span>
              <strong className="text-sm">{day.orders.toLocaleString("th-TH")}</strong>
              <span className="text-muted-foreground">{formatBaht(day.sales)}</span>
            </div>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <form className="flex w-full max-w-md gap-2" action="/food">
            <input
              name="q"
              defaultValue={q ?? ""}
              placeholder="ค้นหาชื่อร้าน"
              aria-label="ค้นหาชื่อร้าน"
              className="h-11 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm"
            />
            <button type="submit" className="h-11 rounded-md border px-4 text-sm font-medium hover:bg-accent">ค้นหา</button>
          </form>
          <div className="flex flex-wrap gap-2">
            <Link href="/food/places" className="inline-flex h-11 items-center gap-2 rounded-md border px-4 text-sm font-medium hover:bg-accent">
              <MapPinned className="size-4" /> WYNOS Places
            </Link>
            <Link href="/food/campaigns" className="inline-flex h-11 items-center gap-2 rounded-md border px-4 text-sm font-medium hover:bg-accent">
              <Gift className="size-4" /> แคมเปญ WYNOS
            </Link>
            {role === "admin" && process.env.NEXT_PUBLIC_SUPABASE_URL === "https://pcatuxtenluqzjzzwsvl.supabase.co" ? (
              <Link href="/food/gp" className="inline-flex h-11 items-center gap-2 rounded-md border px-4 text-sm font-medium hover:bg-accent">
                <Wallet className="size-4" /> GP แบบร่าง (Sandbox)
              </Link>
            ) : null}
            {role === "admin" ? (
              <Link href="/food/ads" className="inline-flex h-11 items-center gap-2 rounded-md border px-4 text-sm font-medium hover:bg-accent">
                <Megaphone className="size-4" /> โฆษณา
              </Link>
            ) : null}
            {role === "admin" ? (
              <Link href="/food/orders" className="inline-flex h-11 items-center gap-2 rounded-md border px-4 text-sm font-medium hover:bg-accent">
                <ShoppingBag className="size-4" /> ออเดอร์ทุกร้าน
              </Link>
            ) : null}
          </div>
        </div>

        {stores.length >= 500 ? (
          <p className="text-sm text-muted-foreground">แสดง 500 ร้านแรก ใช้ช่องค้นหาเพื่อหาร้านที่ไม่อยู่ในรายการ</p>
        ) : null}
        {stores.length === 0 ? (
          <div className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">ไม่พบร้าน</div>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {stores.map((store) => (
              <Link key={store.id} href={`/food/stores/${store.id}`} className="flex flex-col gap-2 px-4 py-3 hover:bg-accent sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium">{store.name}</p>
                    {storeStatus(store)}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {store.owner_username ? `เจ้าของ @${store.owner_username}` : "ยังไม่มีเจ้าของ"} · ทีม {store.staff_count} คน · ออเดอร์ล่าสุด {formatThaiDate(store.last_order_at)}
                  </p>
                </div>
                <div className="flex gap-4 text-sm sm:text-right">
                  <div><p className="text-muted-foreground">กำลังดำเนินการ</p><p className={store.active_orders > 0 ? "font-semibold text-primary" : "font-medium"}>{store.active_orders.toLocaleString("th-TH")} ออเดอร์</p></div>
                  <div><p className="text-muted-foreground">30 วัน</p><p className="font-medium">{store.orders_30d.toLocaleString("th-TH")} ออเดอร์</p></div>
                  <div><p className="text-muted-foreground">ยอดขาย 30 วัน</p><p className="font-medium">{formatBaht(store.sales_30d)}</p></div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
