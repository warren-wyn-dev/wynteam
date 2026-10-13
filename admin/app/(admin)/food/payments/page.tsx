import Link from "next/link";

import { Badge } from "@/components/ui/badge";
import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import {
  fetchAdminFoodOrders,
  FOOD_PAYMENT_STATUS_LABEL,
  FOOD_REFUND_STATUS_LABEL,
  formatBaht,
  formatThaiDate,
  type AdminFoodOrder,
  type AdminFoodOrderStatusFilter,
} from "@/lib/admin-food";
import { adminCan, requireAdminRole } from "@/lib/auth";
import { cn } from "@/lib/utils";

const TABS = [
  { key: "review", label: "รอตรวจการชำระเงิน", status: "payment_review" },
  { key: "refunds", label: "รอคืนเงิน", status: "refund_pending" },
  { key: "recent", label: "ออเดอร์ล่าสุด", status: undefined },
] as const satisfies ReadonlyArray<{
  key: string;
  label: string;
  status: AdminFoodOrderStatusFilter | undefined;
}>;

type TabKey = (typeof TABS)[number]["key"];
const PAGE_LIMIT = 100;

/**
 * Read-only Food payment triage. Uses the existing admin_food_orders RPC and
 * the same food:edit permission required by the Orders page. No Stripe,
 * settlement, refund or payment-status mutations are possible here.
 *
 * This is a queue, not a payment ledger: "recent" is the latest orders only.
 * Opening a detail uses the existing audited admin_food_order_detail RPC.
 */
export default async function FoodPaymentsPage({
  searchParams,
}: {
  searchParams: Promise<{ tab?: string }>;
}) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food", "edit")) {
    return <NoAccess what="ดูการชำระเงินและคืนเงิน WYNOS Food" />;
  }

  const { tab: requestedTab } = await searchParams;
  const selected: TabKey = TABS.some((tab) => tab.key === requestedTab)
    ? (requestedTab as TabKey)
    : "review";
  const active = TABS.find((tab) => tab.key === selected)!;

  let orders: AdminFoodOrder[] = [];
  let failed = false;
  try {
    orders = await fetchAdminFoodOrders({ status: active.status, limit: PAGE_LIMIT });
  } catch {
    failed = true;
  }

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <p className="text-xs text-muted-foreground">WYNOS Food</p>
          <h2 className="text-xl font-semibold">Payments &amp; Refunds</h2>
          <p className="max-w-2xl text-sm text-muted-foreground">
            ดูคิวตรวจสอบการชำระเงินและออเดอร์รอคืนเงินจากทุก ร้าน (อ่านอย่างเดียว)
            การคืนเงินยังต้องทำผ่านขั้นตอนที่ได้รับอนุญาต ไม่ใช่จากหน้านี้
          </p>
        </div>
        <RefreshButton />
      </div>

      <nav aria-label="ตัวกรองการชำระเงิน" className="flex flex-wrap gap-2">
        {TABS.map((tab) => (
          <Link
            key={tab.key}
            href={tab.key === "review" ? "/food/payments" : `/food/payments?tab=${tab.key}`}
            aria-current={active.key === tab.key ? "page" : undefined}
            className={cn(
              "inline-flex min-h-11 items-center rounded-full border px-4 text-sm font-medium",
              active.key === tab.key
                ? "border-foreground bg-foreground text-background"
                : "bg-background text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {tab.label}
          </Link>
        ))}
      </nav>

      {failed ? (
        <p role="alert" className="rounded-xl border border-dashed p-8 text-sm text-destructive">
          ไม่สามารถโหลดรายการชำระเงินได้ กรุณาลองรีเฟรชอีกครั้ง
        </p>
      ) : (
        <>
          {orders.length >= PAGE_LIMIT ? (
            <p className="text-xs text-muted-foreground">
              แสดงเพียง {PAGE_LIMIT} รายการล่าสุดในคิวนี้ ไม่ใช่ประวัติธุรกรรมทั้งหมด
            </p>
          ) : null}
          {orders.length === 0 ? (
            <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
              ไม่มีรายการในคิวนี้
            </p>
          ) : (
            <div className="flex flex-col divide-y overflow-hidden rounded-xl border">
              {orders.map((order) => (
                <Link
                  key={order.id}
                  href={`/food/orders/${order.id}`}
                  className="flex flex-col gap-2 px-4 py-3 hover:bg-accent sm:flex-row sm:items-center sm:justify-between"
                >
                  <div className="min-w-0">
                    <p className="truncate font-medium">#{order.order_number} · {order.store_name}</p>
                    <p className="text-xs text-muted-foreground">{formatThaiDate(order.created_at)}</p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2 sm:justify-end">
                    <Badge variant="outline">
                      {FOOD_PAYMENT_STATUS_LABEL[order.payment_status] ?? order.payment_status}
                    </Badge>
                    {order.refund_status !== "none" ? (
                      <Badge variant="destructive">
                        {FOOD_REFUND_STATUS_LABEL[order.refund_status] ?? order.refund_status}
                      </Badge>
                    ) : null}
                    <span className="font-medium tabular-nums">{formatBaht(order.total)}</span>
                  </div>
                </Link>
              ))}
            </div>
          )}
          <p className="text-xs text-muted-foreground">
            คิวนี้มาจากรายการออเดอร์ที่ Admin มีสิทธิ์ดู ไม่ใช่การยืนยันยอดกับ Stripe หรือรายงาน Settlement
          </p>
        </>
      )}
    </div>
  );
}
