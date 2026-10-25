import { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AlertTriangle, Camera, Flag, MapPinPlus, ShieldAlert } from "lucide-react";

import { NoAccess } from "@/components/admin/no-access";
import { RefreshButton } from "@/components/admin/refresh-button";
import { StatCard } from "@/components/admin/stat-card";
import { ADMIN_NAV_GROUPS, adminNavItemsForRole, isAdminNavItemAvailable, systemDashboardHref, type WynosDashboardSystem } from "@/lib/admin-nav";
import { fetchAdminWynosPlacePhotos, fetchAdminWynosPlaceSuggestions } from "@/lib/admin-maps";
import { fetchQueue } from "@/lib/admin-reports";
import { ADMIN_SYSTEM_LABEL, isAdminSystem, type AdminSystem } from "@/lib/admin-systems";
import { adminCan, requireAdminRole } from "@/lib/auth";

/**
 * Per-system dashboards (sidebar restructure, 2026-10-11): one page for each
 * of WYNOS Account, Social and Maps. Food and Merchant moved to ZOKY Admin
 * (ZOKY-ADMIN-001); next.config.ts redirects their old dashboard URLs. Numbers come only from
 * RPCs/views the matching menu pages already use, under the same permission;
 * where no such source exists the page says so instead of showing a figure.
 */
export default async function SystemDashboardPage({ params }: { params: Promise<{ system: string }> }) {
  const { system } = await params;
  if (!isAdminSystem(system) || !isWynosDashboardSystem(system)) notFound();

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
        <SystemStats system={system} />
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

function isWynosDashboardSystem(system: AdminSystem): system is WynosDashboardSystem {
  return system !== "food" && system !== "merchant";
}

async function SystemStats({ system }: { system: WynosDashboardSystem }) {
  switch (system) {
    case "account":
      return (
        <Notice>
          ยังไม่มีข้อมูลสรุปเฉพาะ WYNOS Account — ดูสถิติผู้ใช้และผู้สมัครใหม่ได้ที่{" "}
          <Link href="/" className="font-medium text-foreground underline underline-offset-4">
            Dashboard รวม
          </Link>
        </Notice>
      );

    case "social": {
      const queue = await settle(fetchQueue(["pending", "reviewing"]));
      if (!queue.ok) return <LoadFailed />;
      const pending = queue.value.filter((row) => row.status === "pending").length;
      const reviewing = queue.value.length - pending;
      return (
        <StatGrid>
          <StatCard label="รายงานรอดำเนินการ" value={pending} icon={Flag} sublabel="ที่ Report Center" />
          <StatCard label="รายงานกำลังตรวจสอบ" value={reviewing} icon={ShieldAlert} />
        </StatGrid>
      );
    }

    case "maps": {
      const [suggestions, photos] = await Promise.all([
        settle(fetchAdminWynosPlaceSuggestions("pending")),
        settle(fetchAdminWynosPlacePhotos()),
      ]);
      if (!suggestions.ok && !photos.ok) return <LoadFailed />;
      return (
        <StatGrid>
          {suggestions.ok ? (
            <StatCard
              label="สถานที่ที่ผู้ใช้เสนอ รอตรวจ"
              value={suggestions.value.length}
              icon={MapPinPlus}
              sublabel={suggestions.value.length >= 200 ? "นับได้สูงสุด 200 รายการ" : undefined}
            />
          ) : null}
          {photos.ok ? (
            <StatCard
              label="รูปสถานที่ รอตรวจ"
              value={photos.value.length}
              icon={Camera}
              sublabel={photos.value.length >= 100 ? "นับได้สูงสุด 100 รายการ" : undefined}
            />
          ) : null}
        </StatGrid>
      );
    }
  }
}

function StatGrid({ children }: { children: React.ReactNode }) {
  return <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">{children}</section>;
}

function Notice({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">{children}</p>;
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
