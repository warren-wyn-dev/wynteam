import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { FoodStoreSuspensionActions, FoodTeamMemberToggle } from "@/components/admin/food-store-actions";
import {
  FOOD_ORDER_STATUS_LABEL,
  FOOD_TEAM_ROLE_LABEL,
  fetchAdminFoodOrders,
  fetchAdminFoodStoreDetail,
  fetchAdminWynosPlaceForStore,
  formatBaht,
  formatThaiDate,
} from "@/lib/admin-food";
import { requireAdminRole } from "@/lib/auth";

/** WYN-203: one store — status, numbers, suspension, team, recent orders. */
export default async function FoodStoreDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { role } = await requireAdminRole();
  const { id } = await params;
  const store = await fetchAdminFoodStoreDetail(id);
  if (!store) notFound();
  const mapPlace = await fetchAdminWynosPlaceForStore(store.id);
  // Orders carry customer data: admins only.
  const orders = role === "admin" ? await fetchAdminFoodOrders({ storeId: store.id, limit: 20 }) : [];
  const suspended = Boolean(store.admin_suspended_at);

  return (
    <div className="flex flex-col gap-6 p-6">
      <Link href="/food" className="inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" /> ร้านค้าทั้งหมด
      </Link>

      <section className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="min-w-0 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-xl font-semibold">{store.name}</h2>
            {suspended ? <Badge variant="destructive">ระงับโดย WYNOS</Badge> : (
              <Badge variant={store.is_published ? "ink-solid" : "outline"}>{store.is_published ? (store.is_open ? "เปิดรับออเดอร์" : "เผยแพร่ · ปิดอยู่") : "ยังไม่เผยแพร่"}</Badge>
            )}
          </div>
          <p className="text-sm text-muted-foreground">{[store.phone, store.address, store.business_hours].filter(Boolean).join(" · ") || "ยังไม่ได้ใส่ข้อมูลติดต่อ"}</p>
          <p className="text-xs text-muted-foreground">สร้างเมื่อ {formatThaiDate(store.created_at)}</p>
        </div>
        {role === "admin" ? <FoodStoreSuspensionActions storeId={store.id} storeName={store.name} suspended={suspended} /> : null}
      </section>

      <section className="rounded-xl border p-4 text-sm">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="font-medium">WYNOS Maps</p>
            {mapPlace ? (
              <p className="mt-1 text-muted-foreground">
                {mapPlace.id} · {mapPlace.latitude.toFixed(5)}, {mapPlace.longitude.toFixed(5)} · {mapPlace.is_active ? "แสดงบนแผนที่" : "ยังไม่แสดง"}
              </p>
            ) : (
              <p className="mt-1 text-muted-foreground">ร้านนี้ยังไม่มี WYNOS Place — Merchant ต้องปักหมุดก่อนเผยแพร่</p>
            )}
          </div>
          <Link href="/food/places?category=restaurant" className="rounded-md border px-3 py-2 text-xs font-medium hover:bg-accent">เปิด Places Manager</Link>
        </div>
      </section>

      {suspended ? (
        <section className="rounded-xl border border-destructive/40 bg-destructive/5 p-4 text-sm">
          <p className="font-medium">ระงับเมื่อ {formatThaiDate(store.admin_suspended_at)}{store.admin_suspended_by_username ? ` โดย @${store.admin_suspended_by_username}` : ""}</p>
          <p className="mt-1 text-muted-foreground">เหตุผล: {store.admin_suspended_reason}</p>
        </section>
      ) : null}

      <section className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        {[
          ["ออเดอร์ทั้งหมด", store.orders_total.toLocaleString("th-TH")],
          ["ออเดอร์ 30 วัน", store.orders_30d.toLocaleString("th-TH")],
          ["ยอดขาย 30 วัน", formatBaht(store.sales_30d)],
          ["ยกเลิก 30 วัน", store.cancelled_30d.toLocaleString("th-TH")],
          ["กำลังดำเนินการ", store.active_orders.toLocaleString("th-TH")],
        ].map(([label, value]) => (
          <div key={label} className="rounded-xl border p-4">
            <p className="text-xs text-muted-foreground">{label}</p>
            <p className="mt-1 text-lg font-semibold tabular-nums">{value}</p>
          </div>
        ))}
      </section>

      <section className="flex flex-col gap-3">
        <h3 className="text-base font-semibold">ทีมของร้าน</h3>
        {store.team.length === 0 ? (
          <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">ยังไม่มีสมาชิก</p>
        ) : (
          <div className="flex flex-col divide-y rounded-xl border">
            {store.team.map((member) => (
              <div key={member.user_id} className="flex items-center justify-between gap-3 px-4 py-3">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <Link href={`/users/${member.user_id}`} className="font-medium hover:underline">@{member.username ?? "ไม่ทราบชื่อ"}</Link>
                    <Badge variant={member.role === "owner" ? "ink-solid" : "gray-tonal"}>{FOOD_TEAM_ROLE_LABEL[member.role] ?? member.role}</Badge>
                    {!member.active ? <Badge variant="outline">ปิดสิทธิ์อยู่</Badge> : null}
                  </div>
                  {member.display_name ? <p className="text-sm text-muted-foreground">{member.display_name}</p> : null}
                </div>
                {role === "admin" ? (
                  <FoodTeamMemberToggle storeId={store.id} userId={member.user_id} active={member.active} label={`@${member.username ?? "สมาชิก"}`} />
                ) : null}
              </div>
            ))}
          </div>
        )}
      </section>

      {role === "admin" ? (
        <section className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-semibold">ออเดอร์ล่าสุด</h3>
            <Link href={`/food/orders?store=${store.id}`} className="text-sm text-muted-foreground hover:text-foreground">ดูทั้งหมด</Link>
          </div>
          {orders.length === 0 ? (
            <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">ยังไม่มีออเดอร์</p>
          ) : (
            <div className="flex flex-col divide-y rounded-xl border">
              {orders.map((order) => (
                <Link key={order.id} href={`/food/orders/${order.id}`} className="flex items-center justify-between gap-3 px-4 py-3 hover:bg-accent">
                  <div>
                    <p className="font-medium">#{order.order_number} · {order.recipient_name}</p>
                    <p className="text-sm text-muted-foreground">{formatThaiDate(order.created_at)}</p>
                  </div>
                  <div className="text-right text-sm">
                    <p className="font-medium">{formatBaht(order.total)}</p>
                    <p className="text-muted-foreground">{FOOD_ORDER_STATUS_LABEL[order.status] ?? order.status}</p>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </section>
      ) : (
        <p className="text-sm text-muted-foreground">ข้อมูลออเดอร์และลูกค้าดูได้เฉพาะ Admin</p>
      )}
    </div>
  );
}
