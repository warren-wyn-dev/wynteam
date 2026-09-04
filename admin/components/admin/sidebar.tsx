"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";
import { ADMIN_NAV_ITEMS } from "@/lib/admin-nav";

export function AdminSidebar() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="เมนูหลัก"
      className="flex w-60 shrink-0 flex-col gap-1 border-r bg-background p-4"
    >
      <div className="mb-4 px-2 text-lg font-semibold">WYN Admin</div>
      {ADMIN_NAV_ITEMS.map((item) => {
        const isActive = pathname === item.href;
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors",
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
    </nav>
  );
}
