"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { cn } from "@/lib/utils";

const TABS = [
  { href: "/ai", label: "แชต" },
  { href: "/ai/activity", label: "กิจกรรมและค่าใช้จ่าย" },
  { href: "/ai/memory", label: "ความจำ" },
  { href: "/ai/settings", label: "ตั้งค่าและความปลอดภัย" },
];

export function AiSubnav() {
  const pathname = usePathname();
  return (
    <nav aria-label="AI Secretary" className="flex gap-1 overflow-x-auto border-b">
      {TABS.map((tab) => {
        const active = tab.href === "/ai" ? pathname === "/ai" : pathname.startsWith(tab.href);
        return (
          <Link
            key={tab.href}
            href={tab.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex min-h-11 shrink-0 items-center border-b-2 px-3 text-sm font-medium",
              active ? "border-foreground text-foreground" : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
