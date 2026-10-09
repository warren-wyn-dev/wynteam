"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronsUpDown } from "lucide-react";

import { cn } from "@/lib/utils";
import {
  ADMIN_WORKSPACES,
  getAdminVisibleItems,
  getAdminWorkspace,
  isAdminNavActive,
} from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";

export function AdminSidebar({ role }: { role: AdminRole }) {
  const pathname = usePathname();
  const workspace = getAdminWorkspace(pathname);
  const items = getAdminVisibleItems(workspace, role);

  return (
    <>
      <aside className="hidden h-screen w-64 shrink-0 flex-col border-r bg-background md:sticky md:top-0 md:flex">
        <div className="border-b px-5 py-5">
          <Link href="/" className="inline-flex items-center gap-3 rounded-md focus-visible:outline-2 focus-visible:outline-offset-4">
            <span aria-hidden="true" className="flex size-9 items-center justify-center rounded-xl bg-foreground text-sm font-bold text-background">
              W
            </span>
            <span className="flex flex-col leading-tight">
              <span className="text-base font-semibold tracking-tight">WYNOS Admin</span>
              <span className="text-xs text-muted-foreground">Control Center</span>
            </span>
          </Link>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-3 py-4">
          <p className="px-3 pb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            พื้นที่ทำงาน
          </p>
          <nav aria-label="เลือกพื้นที่ทำงาน" className="flex flex-col gap-1">
            {ADMIN_WORKSPACES.map((section) => {
              const Icon = section.icon;
              const active = workspace.id === section.id;
              return (
                <Link
                  href={section.href}
                  key={section.id}
                  aria-current={active ? "location" : undefined}
                  className={cn(
                    "flex min-h-11 items-center gap-3 rounded-lg px-3 text-sm transition-colors focus-visible:outline-2 focus-visible:outline-offset-[-2px]",
                    active ? "bg-muted font-semibold text-foreground" : "text-muted-foreground hover:bg-accent hover:text-foreground",
                  )}
                >
                  <Icon aria-hidden="true" className="size-[18px] shrink-0" />
                  <span className="min-w-0 flex-1 truncate">{section.label}</span>
                  {active ? <span aria-hidden="true" className="size-1.5 rounded-full bg-foreground" /> : null}
                </Link>
              );
            })}
          </nav>

          <div className="mx-3 my-5 border-t" />

          <div className="flex items-center justify-between gap-2 px-3 pb-2">
            <p className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              {workspace.label}
            </p>
            <ChevronsUpDown aria-hidden="true" className="size-3 text-muted-foreground" />
          </div>
          <nav aria-label={"เมนู" + workspace.label} className="flex flex-col gap-1">
            {items.map((item) => {
              const Icon = item.icon;
              const active = isAdminNavActive(pathname, item.href);
              return (
                <Link
                  href={item.href}
                  key={item.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex min-h-10 items-center gap-3 rounded-lg px-3 text-sm transition-colors focus-visible:outline-2 focus-visible:outline-offset-[-2px]",
                    active ? "bg-muted font-semibold text-foreground" : "text-muted-foreground hover:bg-accent hover:text-foreground",
                  )}
                >
                  <Icon className="size-4 shrink-0" aria-hidden="true" />
                  <span className="truncate">{item.label}</span>
                </Link>
              );
            })}
          </nav>
        </div>
        <p className="border-t px-5 py-3 text-xs text-muted-foreground">
          {workspace.domain}
        </p>
      </aside>

      <nav
        aria-label={"เมนูมือถือ " + workspace.label}
        className="fixed inset-x-0 bottom-0 z-40 flex min-h-16 items-stretch overflow-x-auto border-t bg-background/95 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden"
      >
        <div className="flex w-full min-w-max items-stretch justify-around gap-1">
          {items.map((item) => {
            const Icon = item.icon;
            const active = isAdminNavActive(pathname, item.href);
            return (
              <Link
                href={item.href}
                key={item.href}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "flex min-h-16 min-w-[76px] flex-1 flex-col items-center justify-center gap-1 rounded-lg px-2 py-2 text-[11px] transition-colors",
                  active ? "bg-muted font-semibold text-foreground" : "text-muted-foreground hover:bg-accent hover:text-foreground",
                )}
              >
                <Icon aria-hidden="true" className="size-5" />
                <span className="whitespace-nowrap">{item.label}</span>
              </Link>
            );
          })}
        </div>
      </nav>
    </>
  );
}
