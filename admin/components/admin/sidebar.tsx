"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";
import {
  getAdminCurrentItem,
  getAdminVisibleItems,
  getAdminWorkspace,
} from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";

/**
 * The workspace selector lives in AdminHeader, not in the sidebar.
 * Both desktop and mobile navigation only show pages belonging to the
 * selected workspace. All existing routes and server-side permissions stay
 * unchanged.
 */
export function AdminSidebar({ role }: { role: AdminRole }) {
  const pathname = usePathname();
  const workspace = getAdminWorkspace(pathname);
  const currentItem = getAdminCurrentItem(pathname);
  const items = getAdminVisibleItems(workspace, role);
  const WorkspaceIcon = workspace.icon;
  const mobileNavRef = useRef<HTMLElement>(null);

  useEffect(() => {
    // A selected tab must remain visible even when the active destination
    // is beyond the phone's 320px viewport (e.g. Social reports or Food ads).
    const nav = mobileNavRef.current;
    const active = nav?.querySelector<HTMLElement>('[aria-current="page"]');
    if (!nav || !active) return;
    const navBox = nav.getBoundingClientRect();
    const itemBox = active.getBoundingClientRect();
    const centered = nav.scrollLeft + itemBox.left - navBox.left -
      (nav.clientWidth - itemBox.width) / 2;
    nav.scrollTo({ left: Math.max(0, centered), behavior: "auto" });
  }, [pathname, workspace.id]);

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

        <div className="min-h-0 flex-1 overflow-y-auto px-3 py-5">
          <div className="mb-5 flex items-center gap-3 border-b px-3 pb-5">
            <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted">
              <WorkspaceIcon className="size-5" aria-hidden="true" />
            </span>
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold">{workspace.label}</p>
              <p className="truncate text-xs text-muted-foreground">{workspace.domain}</p>
            </div>
          </div>

          <p className="px-3 pb-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            เมนูจัดการ
          </p>
          <nav aria-label={"เมนู" + workspace.label} className="flex flex-col gap-1">
            {items.map((item) => {
              const Icon = item.icon;
              const active = currentItem?.href === item.href;
              return (
                <Link
                  href={item.href}
                  key={item.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "flex min-h-11 items-center gap-3 rounded-lg px-3 text-sm transition-colors focus-visible:outline-2 focus-visible:outline-offset-[-2px]",
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
          เปลี่ยน Workspace ได้จากแถบด้านบน
        </p>
      </aside>

      <nav
        ref={mobileNavRef}
        key={workspace.id}
        aria-label={"เมนูมือถือ " + workspace.label}
        className="fixed inset-x-0 bottom-0 z-40 flex min-h-16 items-stretch overflow-x-auto border-t bg-background/95 px-2 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden"
      >
        <div className="flex w-full min-w-max items-stretch justify-around gap-1">
          {items.map((item) => {
            const Icon = item.icon;
            const active = currentItem?.href === item.href;
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
