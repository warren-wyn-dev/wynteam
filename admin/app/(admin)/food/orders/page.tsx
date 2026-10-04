import Link from "next/link";
import { ArrowLeft } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  FOOD_ORDER_STATUS_LABEL,
  FOOD_PAYMENT_STATUS_LABEL,
  FOOD_REFUND_STATUS_LABEL,
  fetchAdminFoodOrders,
  formatBaht,
  formatThaiDate,
  type AdminFoodOrderStatusFilter,
} from "@/lib/admin-food";
import { requireAdminRole } from "@/lib/auth";
import { cn } from "@/lib/utils";

const FILTERS: Array<{ value: "all" | AdminFoodOrderStatusFilter; label: string }> = [
  { value: "all", label: "ทั้งหมด" },
  { value: "active", label: "กำลังดำเนินการ" },
  { value: "delivered", label: "ส่งแล้ว" },
  { value: "cancelled", label: "ยกเลิก" },
  { value: "payment_review", label: "รอตรวจการชำระ" },
  { value: "refund_pending", label: "รอคืนเงิน" },
];
const ORDER_LIMIT = 300;

/** WYN-203: orders across every store, for complaints (admin only: customer data). */
export default async function FoodOrdersPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; q?: string; store?: string }>;
}) {
  const { role } = await requireAdminRole();
  if (role !== "admin") {
    return (
      <div className="p-6">
        <p className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">ออเดอร์มีข้อมูลลูกค้า ดูได้เฉพาะ Admin</p>
      </div>
    );
  }
  const { status, q, store } = await searchParams;
  const resolved = FILTERS.some((item) => item.value === status) ? (status as "all" | AdminFoodOrderStatusFilter) : "all";
  const orders = await fetchAdminFoodOrders({
    status: resolved === "all" ? undefined : resolved,
    query: q,
    storeId: store,
    limit: ORDER_LIMIT,
  });
  const keep = (next: Record<string, string | undefined>) => {
    const params = new URLSearchParams();
    const merged = { status: resolved === "all" ? undefined : resolved, q, store, ...next };
    for (const [key, value] of Object.entries(merged)) if (value) params.set(key, value);
    const text = params.toString();
    return text ? `/food/orders?${text}` : "/food/orders";
  };

  return (
    <div className="flex flex-col gap-5 p-6">
      <Link href="/food" className="inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" /> ร้านค้าทั้งหมด
      </Link>
      <section className="flex flex-col gap-1">
        <h2 className="text-xl font-semibold">ออเดอร์ทุกร้าน</h2>
        <p className="text-sm text-muted-foreground">ค้นหาด้วยเลขออเดอร์ ชื่อ หรือเบอร์ลูกค้า การเปิดดูรายละเอียดจะถูกบันทึกใน Audit Log</p>
      </section>

      <form className="flex w-full max-w-md gap-2" action="/food/orders">
        {resolved !== "all" ? <input type="hidden" name="status" value={resolved} /> : null}
        {store ? <input type="hidden" name="store" value={store} /> : null}
        <input name="q" defaultValue={q ?? ""} placeholder="เลขออเดอร์ · ชื่อ · เบอร์โทร" aria-label="ค้นหาออเดอร์" className="h-11 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm" />
        <button type="submit" className="h-11 rounded-md border px-4 text-sm font-medium hover:bg-accent">ค้นหา</button>
      </form>

      <div className="flex flex-wrap gap-2">
        {FILTERS.map((filter) => (
          <Link
            key={filter.value}
            href={keep({ status: filter.value === "all" ? undefined : filter.value })}
            className={cn(
              "inline-flex min-h-11 items-center rounded-full border px-4 text-sm font-medium transition-colors",
              resolved === filter.value ? "border-foreground bg-foreground text-background" : "bg-background text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {filter.label}
          </Link>
        ))}
        {store ? <Link href={keep({ store: undefined })} className="inline-flex min-h-11 items-center rounded-full border px-4 text-sm text-muted-foreground hover:bg-muted">เฉพาะร้านนี้ ✕</Link> : null}
      </div>

      {orders.length >= ORDER_LIMIT ? (
        <p className="text-sm text-muted-foreground">{`แสดง ${ORDER_LIMIT} รายการล่าสุด ใช้ตัวกรองหรือค้นหาเพื่อดูรายการที่เก่ากว่า`}</p>
      ) : null}
      {orders.length === 0 ? (
        <div className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">ไม่พบออเดอร์</div>
      ) : (
        <div className="flex flex-col divide-y rounded-xl border">
          {orders.map((order) => (
            <Link key={order.id} href={`/food/orders/${order.id}`} className="flex flex-col gap-2 px-4 py-3 hover:bg-accent sm:flex-row sm:items-center sm:justify-between">
              <div className="min-w-0">
                <p className="font-medium">#{order.order_number} · {order.store_name}</p>
                <p className="text-sm text-muted-foreground">{order.recipient_name} · {order.recipient_phone} · {formatThaiDate(order.created_at)}</p>
              </div>
              <div className="flex flex-wrap items-center gap-2 sm:justify-end">
                <Badge variant="gray-tonal">{FOOD_ORDER_STATUS_LABEL[order.status] ?? order.status}</Badge>
                <Badge variant="outline">{FOOD_PAYMENT_STATUS_LABEL[order.payment_status] ?? order.payment_status}</Badge>
                {order.refund_status !== "none" ? <Badge variant="destructive">{FOOD_REFUND_STATUS_LABEL[order.refund_status] ?? order.refund_status}</Badge> : null}
                <span className="font-medium tabular-nums">{formatBaht(order.total)}</span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
