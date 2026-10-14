import Link from "next/link";
import { NoAccess } from "@/components/admin/no-access";
import { FoodObservationError, FoodObservationPagination, FoodOrderState } from "@/components/admin/food-observability";
import { formatBaht, formatThaiDate } from "@/lib/admin-food";
import {
  fetchFoodPaymentMonitor, foodMonitorDates, foodObservationError, FOOD_MONITOR_FILTERS, FOOD_MONITOR_FLAGS,
  observationPage, observationText, type FoodObservationSearch, type FoodPaymentMonitor,
} from "@/lib/admin-food-payments";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function FoodPaymentsPage({ searchParams }: { searchParams: Promise<FoodObservationSearch> }) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="ตรวจสอบการชำระเงิน Food" />;
  const search = await searchParams;
  const query = observationText(search.q);
  const rawFilter = observationText(search.filter);
  const filter = Object.hasOwn(FOOD_MONITOR_FILTERS, rawFilter) ? rawFilter as keyof typeof FOOD_MONITOR_FILTERS : "all";
  const rawProvider = observationText(search.provider);
  const provider = ["stripe", "manual"].includes(rawProvider) ? rawProvider : "";
  const page = observationPage(search.page);
  let dates: { from: string; to: string };
  try { dates = foodMonitorDates(observationText(search.from), observationText(search.to)); }
  catch { return <div className="p-6 space-y-4"><h1 className="text-2xl font-semibold">การชำระเงินและคืนเงิน</h1><FoodObservationError message="กรุณาระบุวันที่ให้ถูกต้อง เรียงจากวันเริ่มถึงวันสิ้นสุด และห่างกันไม่เกิน 365 วัน" href="/food/payments" /></div>; }
  const href = (nextPage: number) => `/food/payments?${new URLSearchParams({ q: query, filter, provider, from: dates.from, to: dates.to, page: String(nextPage) })}`;
  let result: FoodPaymentMonitor;
  try { result = await fetchFoodPaymentMonitor({ query, filter, provider, ...dates, page }); }
  catch (error) { return <div className="p-6 space-y-4"><h1 className="text-2xl font-semibold">การชำระเงินและคืนเงิน</h1><FoodObservationError message={foodObservationError(error)} href={href(page)} /></div>; }
  const canOpenOrder = adminCan(ctx, "food", "edit");
  return <div className="space-y-5 p-4 sm:p-6">
    <header className="space-y-2">
      <p className="text-xs text-muted-foreground">WYNOS Food / การชำระเงิน</p>
      <h1 className="text-2xl font-semibold">การชำระเงินและคืนเงิน</h1>
      <p className="text-sm text-muted-foreground">ตรวจสอบสถานะออเดอร์กับรายการ Stripe ที่บันทึกในระบบ แสดงออเดอร์ที่สร้างในช่วงวันที่เลือก</p>
      <p className="rounded-lg bg-muted p-3 text-sm">ยอดนี้เป็นข้อมูลในระบบ ณ {formatThaiDate(result.as_of)} การรับเหตุการณ์ข้อพิพาทหรือคืนเงินบางส่วนยังไม่ยืนยันยอดกับ Stripe โดยตรง การโอนเงินร้านค้าอยู่ที่ <Link className="underline" href="/merchant/finance">การเงินร้านค้า</Link></p>
    </header>
    <form action="/food/payments" className="flex flex-wrap items-end gap-3 rounded-xl border p-4">
      <label className="flex min-w-0 flex-1 flex-col gap-1 text-sm">เลขออเดอร์หรือชื่อร้าน<input name="q" defaultValue={query} maxLength={100} className="h-11 min-w-0 rounded-md border bg-background px-3" /></label>
      <label className="flex flex-col gap-1 text-sm">สถานะ<select name="filter" defaultValue={filter} className="h-11 rounded-md border bg-background px-3">{Object.entries(FOOD_MONITOR_FILTERS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <label className="flex flex-col gap-1 text-sm">ช่องทาง<select name="provider" defaultValue={provider} className="h-11 rounded-md border bg-background px-3"><option value="">ทั้งหมด</option><option value="stripe">Stripe</option><option value="manual">ช่องทางอื่น / สลิป</option></select></label>
      <label className="flex flex-col gap-1 text-sm">วันที่เริ่ม<input name="from" type="date" required defaultValue={dates.from} className="h-11 rounded-md border bg-background px-3" /></label>
      <label className="flex flex-col gap-1 text-sm">วันที่สิ้นสุด<input name="to" type="date" required defaultValue={dates.to} className="h-11 rounded-md border bg-background px-3" /></label>
      <button className="h-11 rounded-md bg-foreground px-4 text-sm text-background">แสดงข้อมูล</button>
    </form>
    <p className="text-sm text-muted-foreground">ในผลการค้นหานี้ มี {result.review_count.toLocaleString("th-TH")} รายการควรตรวจสอบ เกณฑ์รอนานคือเกิน 24 ชั่วโมง</p>
    {result.rows.length === 0 ? <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">ไม่พบรายการในช่วงวันที่และตัวกรองนี้</p> : <div className="space-y-3">{result.rows.map(row => <article key={row.order_id} className="space-y-3 rounded-xl border p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div><h2 className="font-semibold">#{row.order_number} · {row.store_name}</h2><p className="text-xs text-muted-foreground">{formatThaiDate(row.created_at)} · {row.provider === "stripe" ? "Stripe" : "ช่องทางอื่น / สลิป"}</p></div>
        {canOpenOrder ? <Link href={`/food/orders/${row.order_id}`} className="inline-flex min-h-11 items-center rounded-md border px-3 text-sm">ดูออเดอร์</Link> : null}
      </div>
      <FoodOrderState order={row.order_status} payment={row.payment_status} refund={row.refund_status} />
      <dl className="grid gap-3 text-sm sm:grid-cols-3">
        <div><dt className="text-muted-foreground">ยอดออเดอร์</dt><dd className="font-medium tabular-nums">{formatBaht(row.expected_satang / 100)}</dd></div>
        <div><dt className="text-muted-foreground">ยอดรายการ Stripe ที่บันทึก</dt><dd>{row.ledger_amount_satang === null ? "—" : `${formatBaht(row.ledger_amount_satang / 100)} · ${row.ledger_currency?.toUpperCase()}`}</dd></div>
        <div><dt className="text-muted-foreground">สถานะรายการ Stripe</dt><dd>{row.ledger_status ?? "ยังไม่มีรายการ"}</dd></div>
      </dl>
      {row.flags.length ? <ul className="list-disc space-y-1 rounded-lg bg-muted py-3 pl-7 pr-3 text-sm">{row.flags.map(flag => <li key={flag}>{FOOD_MONITOR_FLAGS[flag] ?? flag}</li>)}</ul> : null}
      {row.latest_refund_event || row.latest_dispute_event ? <p className="break-words text-xs text-muted-foreground">เหตุการณ์คืนเงินล่าสุด: {row.latest_refund_event ?? "—"} · เหตุการณ์ข้อพิพาทล่าสุด: {row.latest_dispute_event ?? "—"} · การรับ webhook ล่าสุด: {formatThaiDate(row.latest_webhook_at)}</p> : null}
    </article>)}</div>}
    <FoodObservationPagination page={page} total={result.total_count} href={href} />
  </div>;
}
