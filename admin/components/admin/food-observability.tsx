import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { FOOD_ORDER_STATUS_LABEL, FOOD_PAYMENT_STATUS_LABEL, FOOD_REFUND_STATUS_LABEL } from "@/lib/admin-food";

export function FoodOrderState({ order, payment, refund }: { order: string; payment: string; refund: string }) {
  return <div className="flex flex-wrap gap-2">
    <Badge variant="gray-tonal">{FOOD_ORDER_STATUS_LABEL[order] ?? order}</Badge>
    <Badge variant="outline">{FOOD_PAYMENT_STATUS_LABEL[payment] ?? payment}</Badge>
    {refund !== "none" ? <Badge variant={refund === "refunded" ? "outline" : "destructive"}>{FOOD_REFUND_STATUS_LABEL[refund] ?? refund}</Badge> : null}
  </div>;
}

export function FoodObservationError({ message, href }: { message: string; href: string }) {
  return <div role="alert" className="space-y-3 rounded-xl border p-5">
    <p className="text-sm">{message}</p>
    <Link href={href} className="inline-flex min-h-11 items-center rounded-md border px-4 text-sm">ลองใหม่</Link>
  </div>;
}

export function FoodObservationPagination({ page, total, href }: { page: number; total: number; href: (page: number) => string }) {
  const pages = Math.max(1, Math.ceil(total / 25));
  return <nav aria-label="เปลี่ยนหน้ารายการ" className="flex flex-wrap items-center justify-between gap-3 text-sm">
    <span>{total.toLocaleString("th-TH")} รายการ · หน้า {page.toLocaleString("th-TH")} / {pages.toLocaleString("th-TH")}</span>
    <div className="flex gap-2">
      {page > 1 ? <Link className="inline-flex min-h-11 items-center rounded-md border px-4" href={href(page - 1)}>ก่อนหน้า</Link> : null}
      {page < pages && page < 4001 ? <Link className="inline-flex min-h-11 items-center rounded-md border px-4" href={href(page + 1)}>ถัดไป</Link> : null}
    </div>
  </nav>;
}
