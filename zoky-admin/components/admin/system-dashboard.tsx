import { Suspense } from "react";
import Link from "next/link";
import { AlertTriangle, Ban, BadgeCheck, ReceiptText, Store, Wallet } from "lucide-react";

import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { StatCard } from "@/components/admin/stat-card";
import { ADMIN_NAV_GROUPS, adminNavItemsForRole, isAdminNavItemAvailable, systemDashboardHref } from "@/lib/admin-nav";
import { fetchAdminFoodOverview } from "@/lib/admin-food";
import { MERCHANT_APPLICATION_LIMIT, fetchMerchantApplications } from "@/lib/admin-merchants";
import { ADMIN_SYSTEM_LABEL } from "@/lib/admin-systems";
import { adminCan, requireAdminRole, type AdminContext, type ZokySystem } from "@/lib/auth";

/**
 * ZOKY Food / ZOKY Merchant dashboards (moved from WYNOS Admin's
 * /dashboard/[system], ZOKY-ADMIN-001). Numbers come only from RPCs the
 * matching menu pages already use, under the same permission.
 */
export async function SystemDashboard({ system }: { system: ZokySystem }) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, system)) return <NoAccess what={` ${ADMIN_SYSTEM_LABEL[system]}`} />;

  const group = ADMIN_NAV_GROUPS.find((entry) => entry.id === system)!;
  const menu = adminNavItemsForRole(ctx.role, ctx.access).filter(
    (item) => item.group === system && item.href !== systemDashboardHref(system),
  );

  return (
    <div className="flex flex-col gap-6 p-6">
      <section className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <h2 className="text-xl font-semibold">{`${group.label} · Dashboard`}</h2>
          <p className="text-sm text-muted-foreground">{group.description}</p>
        </div>
        <RefreshButton />
      </section>

      <Suspense fallback={<StatsSkeleton />}>
        <SystemStats system={system} ctx={ctx} />
      </Suspense>

      {menu.length > 0 ? (
        <section className="flex flex-col gap-3">
          <h3 className="text-sm font-medium text-muted-foreground">เมนูในหมวดนี้</h3>
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {menu.map((item) => {
              const Icon = item.icon;
              return (
                <li key={item.id}>
                  {isAdminNavItemAvailable(item) ? (
                    <Link
                      href={item.href}
                      className="flex min-h-14 items-center gap-3 rounded-xl border bg-background p-4 text-sm font-medium transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    >
                      <Icon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                      {item.label}
                    </Link>
                  ) : (
                    <div
                      aria-disabled="true"
                      className="flex min-h-14 items-center gap-3 rounded-xl border border-dashed p-4 text-sm text-muted-foreground"
                    >
                      <Icon className="size-4 shrink-0" aria-hidden />
                      <span className="flex-1">{item.label}</span>
                      <span className="rounded-full border px-2 py-0.5 text-[11px] font-medium">เร็วๆ นี้</span>
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}
    </div>
  );
}

async function settle<T>(promise: Promise<T>): Promise<{ ok: true; value: T } | { ok: false }> {
  try {
    return { ok: true, value: await promise };
  } catch {
    return { ok: false };
  }
}

async function SystemStats({ system, ctx }: { system: ZokySystem; ctx: AdminContext }) {
  switch (system) {
    case "food": {
      const overview = await settle(fetchAdminFoodOverview());
      if (!overview.ok) return <LoadFailed />;
      const o = overview.value;
      return (
        <StatGrid>
          <StatCard label="ออเดอร์วันนี้" value={o.orders_today} icon={ReceiptText} />
          <StatCard label="กำลังดำเนินการ" value={o.active_orders} icon={ReceiptText} />
          <StatCard label="ยอดขายวันนี้ (บาท)" value={Number(o.sales_today)} icon={Wallet} sublabel="นับเฉพาะออเดอร์ที่ส่งแล้ว" />
        </StatGrid>
      );
    }

    case "merchant": {
      // Stores still use the `food` permission they always did.
      const canSeeStores = adminCan(ctx, "food");
      const [applications, overview] = await Promise.all([
        settle(fetchMerchantApplications("pending")),
        canSeeStores ? settle(fetchAdminFoodOverview()) : Promise.resolve(null),
      ]);
      if (!applications.ok && (!overview || !overview.ok)) return <LoadFailed />;
      return (
        <StatGrid>
          {applications.ok ? (
            <StatCard
              label="คำขอ Merchant รอตรวจสอบ"
              value={applications.value.length}
              icon={BadgeCheck}
              sublabel={applications.value.length >= MERCHANT_APPLICATION_LIMIT ? `นับได้สูงสุด ${MERCHANT_APPLICATION_LIMIT} รายการ` : undefined}
            />
          ) : null}
          {overview?.ok ? (
            <>
              <StatCard
                label="ร้านทั้งหมด"
                value={overview.value.stores_total}
                icon={Store}
                sublabel={`เผยแพร่ ${overview.value.stores_published} · เปิดอยู่ ${overview.value.stores_open}`}
              />
              <StatCard label="ร้านที่ถูกระงับ" value={overview.value.stores_suspended} icon={Ban} />
            </>
          ) : null}
        </StatGrid>
      );
    }

  }
}

function StatGrid({ children }: { children: React.ReactNode }) {
  return <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">{children}</section>;
}

function LoadFailed() {
  return (
    <p role="alert" className="flex items-center justify-center gap-2 rounded-xl border p-6 text-center text-sm text-muted-foreground">
      <AlertTriangle className="size-4 shrink-0" aria-hidden />
      โหลดข้อมูลสรุปไม่สำเร็จ ลองกดรีเฟรชอีกครั้ง
    </p>
  );
}

function StatsSkeleton() {
  return (
    <div role="status" aria-label="กำลังโหลด" className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {Array.from({ length: 3 }).map((_, index) => (
        <div key={index} className="h-28 animate-pulse rounded-xl bg-muted" />
      ))}
    </div>
  );
}
