import Link from "next/link";
import { NoAccess } from "@/components/admin/no-access";
import { FoodObservationError, FoodObservationPagination, FoodOrderState } from "@/components/admin/food-observability";
import { formatBaht, formatThaiDate } from "@/lib/admin-food";
import { fetchFoodCustomerHistory, foodHistoryBuyer, foodObservationError, observationPage, observationText, type FoodCustomerHistory, type FoodObservationSearch } from "@/lib/admin-food-payments";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function FoodCustomersPage({ searchParams }: { searchParams: Promise<FoodObservationSearch> }) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food", "edit")) return <NoAccess what="ดูประวัติลูกค้า Food" />;
  const search = await searchParams;
  const rawBuyer = observationText(search.buyer);
  const buyerId = foodHistoryBuyer(rawBuyer);
  if (rawBuyer && !buyerId) return <div className="p-6"><FoodObservationError message="รหัสลูกค้าไม่ถูกต้อง" href="/food/customers" /></div>;
  const query = observationText(search.q);
  const page = observationPage(search.page);
  const href = (nextPage: number) => `/food/customers?${new URLSearchParams({ q: query, ...(buyerId ? { buyer: buyerId } : {}), page: String(nextPage) })}`;
  let result: FoodCustomerHistory;
  try { result = await fetchFoodCustomerHistory({ buyerId, query, page }); }
  catch (error) { return <div className="p-6 space-y-4"><h1 className="text-2xl font-semibold">ลูกค้า Food</h1><FoodObservationError message={foodObservationError(error)} href={href(page)} /></div>; }
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-2">
      <p className="text-xs text-muted-foreground">WYNOS Food / ลูกค้า</p>
      <h1 className="text-2xl font-semibold">{buyerId ? `ประวัติ ${result.customer_label ?? "ลูกค้า"}` : "ลูกค้า Food"}</h1>
      <p className="text-sm text-muted-foreground">ประวัติจากออเดอร์จริง ใช้รหัสแทนชื่อเพื่อจำกัดข้อมูลส่วนตัว ออเดอร์ที่ไม่มีบัญชีผู้ซื้อจะไม่ถูกรวมเป็นประวัติลูกค้า</p>
      <p className="text-xs text-muted-foreground">ข้อมูล ณ {formatThaiDate(result.as_of)}</p>
      {buyerId ? <Link href="/food/customers" className="inline-flex min-h-11 items-center text-sm underline">กลับรายชื่อลูกค้า</Link> : null}
    </header>
    <form action="/food/customers" className="flex max-w-xl flex-wrap items-end gap-2">
      {buyerId ? <input name="buyer" type="hidden" value={buyerId} /> : null}
      <label className="flex min-w-0 flex-1 flex-col gap-1 text-sm">{buyerId ? "ค้นหาเลขออเดอร์" : "ค้นหาเลขออเดอร์ หรือรหัสบัญชีเต็ม"}<input name="q" defaultValue={query} maxLength={100} className="h-11 min-w-0 rounded-md border bg-background px-3" /></label>
      <button className="h-11 rounded-md border px-4 text-sm">ค้นหา</button>
    </form>
    {result.total_count === 0 ? <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">ไม่พบประวัติที่ตรงกับการค้นหา</p> : buyerId ? <div className="space-y-3">{result.orders.map(order => <article key={order.order_id} className="space-y-3 rounded-xl border p-4">
      <div className="flex flex-wrap items-center justify-between gap-3"><div><h2 className="font-medium">#{order.order_number} · {order.store_name}</h2><p className="text-xs text-muted-foreground">{formatThaiDate(order.created_at)}</p></div><span className="font-medium tabular-nums">{formatBaht(order.total)}</span></div>
      <FoodOrderState order={order.order_status} payment={order.payment_status} refund={order.refund_status} />
      <Link href={`/food/orders/${order.order_id}`} className="inline-flex min-h-11 items-center rounded-md border px-3 text-sm">เปิดรายละเอียดออเดอร์</Link>
    </article>)}</div> : <div className="space-y-3">{result.customers.map(customer => <article key={customer.buyer_id} className="space-y-3 rounded-xl border p-4">
      <div className="flex flex-wrap items-center justify-between gap-3"><h2 className="font-medium">{customer.customer_label}</h2><Link href={`/food/customers?buyer=${customer.buyer_id}`} className="inline-flex min-h-11 items-center rounded-md border px-3 text-sm">ดูประวัติออเดอร์</Link></div>
      <dl className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
        <div><dt className="text-muted-foreground">ออเดอร์ทั้งหมด</dt><dd>{customer.order_count}</dd></div>
        <div><dt className="text-muted-foreground">ชำระแล้ว / คืนเงินแล้ว</dt><dd>{customer.paid_order_count} / {customer.refunded_order_count}</dd></div>
        <div><dt className="text-muted-foreground">ยกเลิก</dt><dd>{customer.cancelled_order_count}</dd></div>
        <div><dt className="text-muted-foreground">สั่งซื้อล่าสุด</dt><dd>{formatThaiDate(customer.last_order_at)}</dd></div>
      </dl>
    </article>)}</div>}
    <FoodObservationPagination page={page} total={result.total_count} href={href} />
  </div>;
}
