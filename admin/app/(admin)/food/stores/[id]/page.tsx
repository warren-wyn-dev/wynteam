import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { FoodStoreSuspensionActions, FoodTeamMemberToggle } from "@/components/admin/food-store-actions";
import {
  FOOD_ORDER_STATUS_LABEL,
  FOOD_READINESS_LABEL,
  FOOD_TEAM_ROLE_LABEL,
  fetchAdminFoodOrders,
  fetchAdminFoodStoreDetail,
  fetchAdminWynosPlaceForStore,
  formatBaht,
  formatThaiDate,
  type AdminFoodStoreDetail,
} from "@/lib/admin-food";
import { fetchStoreAuditLog } from "@/lib/admin-audit-log";
import {
  PAYOUT_INTERVAL_LABEL,
  STRIPE_STATUS_LABEL,
  fetchMerchantFinanceOverview,
  resolveFinanceRange,
  type MerchantFinanceStore,
} from "@/lib/admin-merchant-finance";
import { fetchAdminAccess } from "@/lib/admin-permissions";
import { formatGpRate } from "@/lib/admin-gp-format";
import { hasSystemAccess } from "@/lib/admin-systems";
import { adminCan, requireAdminRole, type AdminContext } from "@/lib/auth";
import { cn } from "@/lib/utils";
import { NoAccess } from "@/components/admin/no-access";

const TABS = [
  { value: "overview", label: "Overview" },
  { value: "info", label: "Store Info" },
  { value: "menus", label: "Menus" },
  { value: "operations", label: "Operations" },
  { value: "promotions", label: "Promotions" },
  { value: "finance", label: "Finance" },
  { value: "activity", label: "Activity Logs" },
] as const;
type Tab = (typeof TABS)[number]["value"];

/**
 * WYN-203 store page, split into tabs (WYNOS Merchant -> Stores). The tab is
 * in the URL (?tab=) so refresh, Back/Forward and shared links keep it.
 * Every tab reads through the same permission-checked RPCs as before.
 */
export default async function FoodStoreDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ tab?: string }>;
}) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what=" WYNOS Food" />;
  const canEditFood = adminCan(ctx, "food", "edit");
  const { id } = await params;
  const { tab: rawTab } = await searchParams;
  const tab: Tab = TABS.some((item) => item.value === rawTab) ? (rawTab as Tab) : "overview";
  const store = await fetchAdminFoodStoreDetail(id);
  if (!store) notFound();
  const suspended = Boolean(store.admin_suspended_at);

  return (
    <div className="flex flex-col gap-6 p-4 sm:p-6">
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
          <p className="break-all text-xs text-muted-foreground">Store ID {store.id}</p>
        </div>
        {canEditFood ? <FoodStoreSuspensionActions storeId={store.id} storeName={store.name} suspended={suspended} /> : null}
      </section>

      {suspended ? (
        <section className="rounded-xl border border-destructive/40 bg-destructive/5 p-4 text-sm">
          <p className="font-medium">ระงับเมื่อ {formatThaiDate(store.admin_suspended_at)}{store.admin_suspended_by_username ? ` โดย @${store.admin_suspended_by_username}` : ""}</p>
          <p className="mt-1 text-muted-foreground">เหตุผล: {store.admin_suspended_reason}</p>
        </section>
      ) : null}

      <nav aria-label="ข้อมูลร้าน" className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
        <ul className="flex w-max gap-1 border-b">
          {TABS.map((item) => (
            <li key={item.value}>
              <Link
                href={item.value === "overview" ? `/food/stores/${store.id}` : `/food/stores/${store.id}?tab=${item.value}`}
                aria-current={tab === item.value ? "page" : undefined}
                scroll={false}
                className={cn(
                  "-mb-px inline-flex min-h-11 items-center whitespace-nowrap border-b-2 px-3 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
                  tab === item.value
                    ? "border-foreground font-semibold text-foreground"
                    : "border-transparent text-muted-foreground hover:text-foreground",
                )}
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>

      {tab === "overview" ? <OverviewTab store={store} /> : null}
      {tab === "info" ? <InfoTab store={store} canEditFood={canEditFood} /> : null}
      {tab === "menus" ? <MenusTab /> : null}
      {tab === "operations" ? <OperationsTab store={store} canEditFood={canEditFood} /> : null}
      {tab === "promotions" ? <PromotionsTab /> : null}
      {tab === "finance" ? <FinanceTab store={store} ctx={ctx} /> : null}
      {tab === "activity" ? <ActivityTab store={store} ctx={ctx} /> : null}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border bg-background p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 text-lg font-semibold tabular-nums">{value}</p>
    </div>
  );
}

function Note({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">{children}</p>;
}

function OverviewTab({ store }: { store: AdminFoodStoreDetail }) {
  return (
    <>
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Stat label="ออเดอร์ทั้งหมด" value={store.orders_total.toLocaleString("th-TH")} />
        <Stat label="ออเดอร์ 30 วัน" value={store.orders_30d.toLocaleString("th-TH")} />
        <Stat label="ยอดขาย 30 วัน" value={formatBaht(store.sales_30d)} />
        <Stat label="ยกเลิก 30 วัน" value={store.cancelled_30d.toLocaleString("th-TH")} />
        <Stat label="กำลังดำเนินการ" value={store.active_orders.toLocaleString("th-TH")} />
      </section>
      <section className="rounded-xl border bg-background p-4 text-sm">
        <p className="font-medium">ความพร้อมเปิดขาย</p>
        {store.readiness_missing.length ? (
          <p className="mt-1">ยังขาด: {store.readiness_missing.map((item) => FOOD_READINESS_LABEL[item] ?? item).join(" · ")}</p>
        ) : (
          <p className="mt-1 text-muted-foreground">ข้อมูลร้านครบ พร้อมเปิดขาย</p>
        )}
      </section>
    </>
  );
}

async function InfoTab({ store, canEditFood }: { store: AdminFoodStoreDetail; canEditFood: boolean }) {
  // WYN-219: the store's map pin comes from a WYNOS Maps RPC (maps:view).
  const canSeeMaps = hasSystemAccess(await fetchAdminAccess(), "maps") !== false;
  const mapPlace = canSeeMaps ? await fetchAdminWynosPlaceForStore(store.id) : null;
  const owner = store.team.find((member) => member.role === "owner" && member.active);

  return (
    <>
      <section className="rounded-xl border bg-background p-4 text-sm">
        <dl className="grid gap-3 sm:grid-cols-2">
          <Field label="เจ้าของร้าน" value={owner ? `@${owner.username ?? "ไม่ทราบชื่อ"}` : "—"} />
          <Field label="เบอร์ติดต่อ" value={store.phone ?? "—"} />
          <Field label="ที่อยู่" value={store.address ?? "—"} />
          <Field label="เวลาเปิด-ปิด" value={store.business_hours ?? "—"} />
          <Field label="Slug" value={store.slug} />
          <Field label="สร้างเมื่อ" value={formatThaiDate(store.created_at)} />
        </dl>
        <p className="mt-3 text-xs text-muted-foreground">ข้อมูลการรับเงินของร้านแสดงแบบปกปิดในแท็บ Finance</p>
      </section>

      <section className="rounded-xl border bg-background p-4 text-sm">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="font-medium">WYNOS Maps</p>
            {!canSeeMaps ? (
              <p className="mt-1 text-muted-foreground">ต้องมีสิทธิ์ WYNOS Maps เพื่อดูหมุดของร้านนี้</p>
            ) : mapPlace ? (
              <p className="mt-1 text-muted-foreground">
                {mapPlace.id} · {mapPlace.latitude.toFixed(5)}, {mapPlace.longitude.toFixed(5)} · {mapPlace.is_active ? "แสดงบนแผนที่" : "ยังไม่แสดง"}
              </p>
            ) : (
              <p className="mt-1 text-muted-foreground">ร้านนี้ยังไม่มี WYNOS Place — Merchant ต้องปักหมุดก่อนเผยแพร่</p>
            )}
          </div>
          {canSeeMaps ? (
            <Link href="/maps/places?category=restaurant" className="rounded-md border px-3 py-2 text-xs font-medium hover:bg-accent">เปิด Places Manager</Link>
          ) : null}
        </div>
      </section>

      <section className="rounded-xl border bg-background p-4 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-medium">พื้นที่ให้บริการ</p>
          <Badge variant={store.in_service_area ? "ink-solid" : "destructive"}>{store.in_service_area ? "อยู่ในเขตมหาสารคาม" : "อยู่นอกเขต / ยังไม่ปักหมุด"}</Badge>
        </div>
        {store.latitude != null && store.longitude != null ? (
          <p className="mt-1 text-muted-foreground">
            หมุดร้าน {Number(store.latitude).toFixed(5)}, {Number(store.longitude).toFixed(5)}
            {store.delivery_radius_km != null ? ` · ส่งได้ในรัศมี ${Number(store.delivery_radius_km)} กม.` : ""} ·{" "}
            <a href={`https://www.google.com/maps?q=${store.latitude},${store.longitude}`} target="_blank" rel="noreferrer" className="underline">เปิดแผนที่</a>
          </p>
        ) : (
          <p className="mt-1 text-muted-foreground">ร้านยังไม่ได้ปักหมุด จึงยังเปิดขายไม่ได้</p>
        )}
      </section>

      <TeamSection store={store} canEditFood={canEditFood} />
    </>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 break-words">{value}</dd>
    </div>
  );
}

function TeamSection({ store, canEditFood }: { store: AdminFoodStoreDetail; canEditFood: boolean }) {
  return (
    <section className="flex flex-col gap-3">
      <h3 className="text-base font-semibold">ทีมของร้าน</h3>
      {store.team.length === 0 ? (
        <Note>ยังไม่มีสมาชิก</Note>
      ) : (
        <div className="flex flex-col divide-y rounded-xl border bg-background">
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
              {canEditFood ? (
                <FoodTeamMemberToggle storeId={store.id} userId={member.user_id} active={member.active} label={`@${member.username ?? "สมาชิก"}`} />
              ) : null}
            </div>
          ))}
        </div>
      )}
    </section>
  );
}

function MenusTab() {
  return (
    <Note>
      ยังไม่มี API ให้ Admin อ่านหรือแก้เมนูของร้าน — เมนูจัดการได้ที่ merchant.wynos.online เท่านั้นในตอนนี้
      (Menu Management อยู่ในแผนของ WYNOS Merchant และต้องใช้ข้อมูลชุดเดียวกับ Merchant Backend)
    </Note>
  );
}

async function OperationsTab({ store, canEditFood }: { store: AdminFoodStoreDetail; canEditFood: boolean }) {
  // Orders carry customer data: food:edit only.
  const orders = canEditFood ? await fetchAdminFoodOrders({ storeId: store.id, limit: 20 }) : [];
  return (
    <>
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="สถานะร้าน" value={store.is_open ? "เปิดรับออเดอร์" : "ปิดอยู่"} />
        <Stat label="การเผยแพร่" value={store.is_published ? "เผยแพร่แล้ว" : "ยังไม่เผยแพร่"} />
        <Stat label="กำลังดำเนินการ" value={store.active_orders.toLocaleString("th-TH")} />
        <Stat label="เวลาเปิด-ปิด" value={store.business_hours ?? "—"} />
      </section>
      {canEditFood ? (
        <section className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h3 className="text-base font-semibold">ออเดอร์ล่าสุด</h3>
            <Link href={`/food/orders?store=${store.id}`} className="text-sm text-muted-foreground hover:text-foreground">ดูทั้งหมด</Link>
          </div>
          {orders.length === 0 ? (
            <Note>ยังไม่มีออเดอร์</Note>
          ) : (
            <div className="flex flex-col divide-y rounded-xl border bg-background">
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
        <p className="text-sm text-muted-foreground">ข้อมูลออเดอร์และลูกค้าดูได้เฉพาะผู้มีสิทธิ์แก้ไข WYNOS Food</p>
      )}
    </>
  );
}

function PromotionsTab() {
  return (
    <section className="flex flex-col gap-3">
      <Note>ยังไม่มี API สรุปโปรโมชันรายร้าน — ดูและจัดการได้จากหน้ารวมของ WYNOS Merchant ด้านล่าง</Note>
      <div className="flex flex-wrap gap-2">
        {[
          ["/food/coupons", "Coupons"],
          ["/food/campaigns", "Campaigns"],
          ["/food/ads", "Ads"],
          ["/food/notifications", "Promo Notifications"],
        ].map(([href, label]) => (
          <Link key={href} href={href} className="rounded-md border px-3 py-2 text-sm font-medium hover:bg-accent">{label}</Link>
        ))}
      </div>
    </section>
  );
}

async function FinanceTab({ store, ctx }: { store: AdminFoodStoreDetail; ctx: AdminContext }) {
  if (!adminCan(ctx, "merchant")) {
    return <Note>ต้องมีสิทธิ์ WYNOS Merchant เพื่อดูข้อมูลการเงินของร้าน</Note>;
  }
  const range = resolveFinanceRange({ range: "30d" });
  let row: MerchantFinanceStore | undefined;
  let failed = false;
  try {
    const data = await fetchMerchantFinanceOverview(range);
    row = data.stores.find((item) => item.store_id === store.id);
  } catch {
    failed = true;
  }
  if (failed || !row) return <Note>โหลดข้อมูลการเงินไม่สำเร็จ หรือระบบการเงินร้านค้ายังไม่ได้ติดตั้งบนฐานข้อมูลนี้</Note>;

  return (
    <>
      <p className="text-sm text-muted-foreground">30 วันล่าสุด ({range.from} – {range.to}, เวลาไทย) · อ่านอย่างเดียว</p>
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat label="ยอดขายสุทธิ" value={formatBaht(row.sales_net)} />
        <Stat label="คืนเงิน" value={formatBaht(row.refunds)} />
        <Stat label="ค่าโฆษณา" value={formatBaht(row.ad_spend)} />
        <Stat label="ส่วนแบ่งแคมเปญ WYNOS" value={formatBaht(row.platform_funded)} />
        <Stat label="รายได้ร้าน" value={formatBaht(row.income)} />
        <Stat label="WYNOS ค้างโอน (ปัจจุบัน)" value={formatBaht(row.platform_owed)} />
        <Stat label={`GP ที่เก็บแล้ว (อัตราปัจจุบัน ${formatGpRate(row.gp_rate_bp ?? 0)})`} value={formatBaht(row.gp ?? 0)} />
        <Stat
          label="การรับเงิน (Stripe)"
          value={row.stripe_status ? STRIPE_STATUS_LABEL[row.stripe_status] : "ยังไม่มีบัญชี"}
        />
      </section>
      <section className="rounded-xl border bg-background p-4 text-sm text-muted-foreground">
        {row.stripe_status ? (
          <p>
            {row.stripe_bank_last4 ? `บัญชีธนาคารลงท้าย ••${row.stripe_bank_last4}` : "ยังไม่ได้ผูกบัญชีธนาคาร"}
            {row.stripe_payout_interval ? ` · Stripe โอน${PAYOUT_INTERVAL_LABEL[row.stripe_payout_interval] ?? row.stripe_payout_interval}` : ""}
            {row.stripe_livemode === false ? " · Test mode" : ""}
          </p>
        ) : (
          <p>ร้านยังไม่ได้เชื่อม Stripe Connect</p>
        )}
        <Link href="/merchant/finance?view=stores" className="mt-2 inline-block underline">เปิดการเงินร้านค้าทั้งหมด</Link>
      </section>
    </>
  );
}

const STORE_AUDIT_LABEL: Record<string, string> = {
  admin_food_store_suspended: "ระงับร้าน",
  admin_food_store_unsuspended: "ปลดระงับร้าน",
  admin_food_staff_updated: "เปลี่ยนสิทธิ์ทีมงาน",
  admin_food_order_viewed: "เปิดดูออเดอร์",
};

async function ActivityTab({ store, ctx }: { store: AdminFoodStoreDetail; ctx: AdminContext }) {
  // The audit log view is super admin only (WYN-219 decision, 2026-10-10).
  if (ctx.access.available && !ctx.access.superAdmin) {
    return <Note>Audit Log ดูได้เฉพาะ super admin</Note>;
  }
  let rows: Awaited<ReturnType<typeof fetchStoreAuditLog>> = [];
  try {
    rows = await fetchStoreAuditLog(store.id);
  } catch {
    return <Note>โหลด Audit Log ไม่สำเร็จ</Note>;
  }
  if (rows.length === 0) return <Note>ยังไม่มีการดำเนินการของผู้ดูแลกับร้านนี้</Note>;
  return (
    <ul className="flex flex-col divide-y rounded-xl border bg-background">
      {rows.map((row) => (
        <li key={row.id} className="flex flex-col gap-0.5 px-4 py-3 text-sm">
          <p className="font-medium">{STORE_AUDIT_LABEL[row.event_type] ?? row.event_type}</p>
          <p className="text-xs text-muted-foreground">
            {formatThaiDate(row.created_at)}
            {row.actor_username_snapshot ? ` · โดย @${row.actor_username_snapshot}` : ""}
            {typeof row.detail?.reason === "string" ? ` · เหตุผล: ${row.detail.reason}` : ""}
          </p>
        </li>
      ))}
    </ul>
  );
}
