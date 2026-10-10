"use client";

import { Fragment } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";
import { ADMIN_NAV_GROUPS, adminNavItemsForRole, findActiveAdminNavItem } from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";
import type { AdminSystemAccess } from "@/lib/admin-systems";

export function AdminSidebar({ role, access }: { role: AdminRole; access: AdminSystemAccess }) {
  const pathname = usePathname();
  const items = adminNavItemsForRole(role, access);
  const active = findActiveAdminNavItem(pathname, items);

  return (
    <nav
      aria-label="เมนูหลัก"
      className="fixed inset-x-0 bottom-0 z-40 flex h-20 items-stretch gap-1 overflow-x-auto border-t bg-background/95 px-2 py-2 backdrop-blur md:sticky md:top-0 md:h-screen md:w-60 md:shrink-0 md:flex-col md:overflow-y-auto md:border-r md:border-t-0 md:p-4"
    >
      <div className="mb-2 hidden px-2 text-lg font-semibold md:block">WYN Admin</div>
      {ADMIN_NAV_GROUPS.map((group, index) => {
        const groupItems = items.filter((item) => item.group === group.id);
        if (groupItems.length === 0) return null;
        return (
          <Fragment key={group.id}>
            {/* Mobile bottom bar: a thin divider between systems. Desktop: a group heading. */}
            {index > 0 ? <div aria-hidden className="my-2 w-px shrink-0 bg-border md:hidden" /> : null}
            <div
              role="group"
              aria-label={group.label}
              className="flex shrink-0 items-stretch gap-1 md:shrink md:flex-col"
            >
              <p
                aria-hidden
                className="hidden px-3 pb-1 pt-4 text-xs font-semibold tracking-wide text-muted-foreground md:block"
              >
                {group.label}
              </p>
              {groupItems.map((item) => {
                const isActive = active?.href === item.href;
                const Icon = item.icon;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    aria-current={isActive ? "page" : undefined}
                    className={cn(
                      "flex min-h-11 min-w-20 shrink-0 flex-col whitespace-nowrap items-center justify-center gap-1 rounded-md px-2 py-2 text-xs font-medium transition-colors md:min-h-11 md:min-w-0 md:flex-row md:justify-start md:gap-3 md:px-3 md:text-sm",
                      // Per wyn-admin-design-system.md section 6.8/3.3: no more
                      // color-coded active state (was cyan50/cyan700 from the
                      // Flutter app's wyn_colors.dart). Active state is now
                      // conveyed by neutral weight/contrast alone -- `bg-muted`/
                      // `text-foreground` already equal the doc's "gray-100 bg +
                      // ink text" (light) / "gray-800 bg + white text" (dark)
                      // tokens exactly, so this stays dark-mode-safe for free.
                      isActive
                        ? "bg-muted font-semibold text-foreground"
                        : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
                    )}
                  >
                    <Icon className="size-4" />
                    {item.label}
                  </Link>
                );
              })}
            </div>
          </Fragment>
        );
      })}
    </nav>
  );
}
