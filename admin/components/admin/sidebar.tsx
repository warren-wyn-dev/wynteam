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
              // Exact WynColors.cyan50/cyan700 pairing from the Flutter
              // app (app/lib/core/design/wyn_colors.dart), not the
              // brand --primary token itself -- --primary (cyan500) is
              // too light for accessible text-on-light-background
              // contrast; cyan700 is the shade WYN's own design system
              // already uses for that purpose. See the Design spec.
              isActive
                ? "bg-[#E6F9FF] text-[#0090C4]"
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
