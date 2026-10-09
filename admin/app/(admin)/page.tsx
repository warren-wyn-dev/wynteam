import Link from "next/link";
import { ArrowUpRight, BookOpenText, ShieldCheck } from "lucide-react";

import { RecentWorkspaceLink } from "@/components/admin/recent-workspace-link";

import { ADMIN_WORKSPACES } from "@/lib/admin-nav";
import { requireAdminRole, type AdminRole } from "@/lib/auth";

const QUICK_LINKS: { href: string; label: string; detail: string; roles?: AdminRole[] }[] = [
  { href: "/analytics", label: "Analytics Center", detail: "สถิติแยก Social, Food และ Merchant", roles: ["admin"] },
  { href: "/users", label: "จัดการผู้ใช้", detail: "WYNOS Social" },
  { href: "/reports", label: "ตรวจสอบรายงาน", detail: "WYNOS Social" },
  { href: "/merchants", label: "คำขอเปิดร้าน", detail: "WYNOS Merchant" },
  { href: "/food/orders", label: "ดูคำสั่งซื้อ Food", detail: "WYNOS Food", roles: ["admin"] },
  { href: "/food/campaigns", label: "แคมเปญ Food", detail: "WYNOS Food" },
  { href: "/audit-log", label: "ประวัติเจ้าหน้าที่", detail: "ระบบส่วนกลาง" },
];

/**
 * Navigation hub across Admin workspaces. Metrics remain on /social and /food,
 * rather than displaying Social-only data as if it were platform-wide totals.
 */
export default async function AdminOverviewPage() {
  const { role } = await requireAdminRole();
  const primary = ADMIN_WORKSPACES.filter((workspace) =>
    workspace.id === "social" || workspace.id === "food" || workspace.id === "merchant",
  );
  const central = ADMIN_WORKSPACES.find((workspace) => workspace.id === "central");

  return (
    <div className="flex flex-col gap-8 p-4 sm:p-6">
      <section className="flex flex-col gap-2">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          WYNOS Admin · Control Center
        </p>
        <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">พื้นที่ทำงานทั้งหมด</h2>
        <p className="max-w-2xl text-sm text-muted-foreground">
          จัดการ WYNOS Social, Food และ Merchant แยกจากกันอย่างชัดเจน
          เลือกพื้นที่ทำงานเพื่อดูข้อมูลและเครื่องมือเฉพาะบริการ
        </p>
        <RecentWorkspaceLink />
      </section>

      <section aria-labelledby="workspaces-heading" className="space-y-3">
        <h3 id="workspaces-heading" className="text-sm font-semibold">บริการของ WYNOS</h3>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {primary.map((workspace) => {
            const Icon = workspace.icon;
            return (
              <Link
                key={workspace.id}
                href={workspace.href}
                className="group flex min-h-48 flex-col rounded-xl border bg-background p-5 transition-colors hover:bg-accent focus-visible:outline-2 focus-visible:outline-offset-2"
              >
                <div className="mb-5 flex items-center justify-between gap-3">
                  <span className="flex size-11 items-center justify-center rounded-xl border bg-muted">
                    <Icon aria-hidden="true" className="size-5" />
                  </span>
                  <ArrowUpRight aria-hidden="true" className="size-4 text-muted-foreground transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
                </div>
                <h4 className="font-semibold">{workspace.label}</h4>
                <p className="mt-0.5 text-xs text-muted-foreground">{workspace.domain}</p>
                <p className="mt-3 text-sm text-muted-foreground">{workspace.description}</p>
              </Link>
            );
          })}
        </div>
      </section>

      <section className="grid gap-5 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
        <div className="rounded-xl border bg-background p-5">
          <h3 className="font-semibold">ทางลัดสำหรับเจ้าหน้าที่</h3>
          <p className="mt-1 text-sm text-muted-foreground">ไปยังหน้าที่มีอยู่แล้ว โดยไม่ต้องค้นหาข้ามเมนู</p>
          <div className="mt-4 divide-y">
            {QUICK_LINKS.filter((link) => !link.roles || link.roles.includes(role)).map((link) => (
              <Link key={link.href} href={link.href} className="flex min-h-12 items-center justify-between gap-3 py-2 text-sm hover:text-foreground">
                <span className="font-medium">{link.label}</span>
                <span className="flex items-center gap-2 text-xs text-muted-foreground">
                  {link.detail} <ArrowUpRight aria-hidden="true" className="size-4" />
                </span>
              </Link>
            ))}
          </div>
        </div>

        {central ? (
          <div className="flex flex-col rounded-xl border bg-background p-5">
            <span className="mb-4 flex size-10 items-center justify-center rounded-xl border bg-muted">
              <BookOpenText aria-hidden="true" className="size-5" />
            </span>
            <h3 className="font-semibold">{central.label}</h3>
            <p className="mt-1 text-sm text-muted-foreground">{central.description}</p>
            <Link href={central.href} className="mt-5 inline-flex min-h-11 items-center gap-2 text-sm font-medium underline-offset-4 hover:underline">
              ดูประวัติการดำเนินงาน <ArrowUpRight aria-hidden="true" className="size-4" />
            </Link>
            <p className="mt-auto flex items-center gap-2 pt-4 text-xs text-muted-foreground">
              <ShieldCheck aria-hidden="true" className="size-4" />
              ใช้สิทธิ์เดิมของ Admin / Moderator
            </p>
          </div>
        ) : null}
      </section>
    </div>
  );
}
