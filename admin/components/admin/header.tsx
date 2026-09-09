"use client";

import { usePathname } from "next/navigation";

import { Button } from "@/components/ui/button";
import { ADMIN_NAV_ITEMS } from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";

const ROLE_LABEL: Record<AdminRole, string> = {
  admin: "Admin",
  moderator: "Moderator",
};

export function AdminHeader({
  email,
  role,
  signOutAction,
}: {
  email: string | null;
  role: AdminRole;
  signOutAction: () => void;
}) {
  const pathname = usePathname();
  const title = ADMIN_NAV_ITEMS.find((item) => item.href === pathname)?.label ?? "WYN Admin";

  return (
    <header className="sticky top-0 z-30 flex min-h-14 shrink-0 items-center justify-between gap-3 border-b bg-background/95 px-4 py-2 backdrop-blur sm:px-6">
      <div className="min-w-0">
        <p className="text-xs font-semibold tracking-wide text-muted-foreground md:hidden">WYN Admin</p>
        <h1 className="truncate text-base font-semibold">{title}</h1>
      </div>
      <div className="flex min-w-0 items-center gap-2 sm:gap-3">
        <span className="rounded-full bg-secondary px-2.5 py-0.5 text-xs font-medium text-secondary-foreground">
          {ROLE_LABEL[role]}
        </span>
        {email ? <span className="hidden max-w-56 truncate text-sm text-muted-foreground lg:inline">{email}</span> : null}
        <form action={signOutAction}>
          <Button type="submit" variant="outline" size="sm" aria-label="ออกจากระบบ">
            ออกจากระบบ
          </Button>
        </form>
      </div>
    </header>
  );
}
