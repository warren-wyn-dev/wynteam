"use client";

import { usePathname } from "next/navigation";
import { Menu } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useAdminNav } from "@/components/admin/nav-state";
import { ADMIN_DRAWER_ID, ADMIN_MENU_BUTTON_ID } from "@/components/admin/sidebar";
import { ADMIN_NAV_GROUPS, findActiveAdminNavItem } from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";

const ROLE_LABEL: Record<AdminRole, string> = {
  admin: "Admin",
  moderator: "Moderator",
  staff: "Staff",
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
  const { drawerOpen, setDrawerOpen } = useAdminNav();
  const active = findActiveAdminNavItem(pathname);
  const title = active?.label ?? "WYN Admin";
  // The section the page sits in, so a moved item (e.g. Stores under WYNOS
  // Merchant) still says where it lives. Pages outside every section say
  // "WYN Admin", as the mobile header always did.
  const section = ADMIN_NAV_GROUPS.find((group) => group.id === active?.group)?.label ?? "WYN Admin";

  return (
    <header className="sticky top-0 z-30 flex min-h-14 shrink-0 items-center justify-between gap-3 border-b bg-background/95 px-4 py-2 backdrop-blur sm:px-6">
      <div className="flex min-w-0 flex-1 items-center gap-2">
        <Button
          id={ADMIN_MENU_BUTTON_ID}
          type="button"
          variant="ghost"
          className="-ml-2 size-11 shrink-0 px-0 md:hidden [&_svg]:size-5"
          aria-label="เปิดเมนู"
          aria-haspopup="dialog"
          aria-expanded={drawerOpen}
          aria-controls={drawerOpen ? ADMIN_DRAWER_ID : undefined}
          onClick={() => setDrawerOpen(true)}
        >
          <Menu aria-hidden />
        </Button>
        <div className="min-w-0">
          <p className="truncate text-xs font-semibold tracking-wide text-muted-foreground">{section}</p>
          <h1 className="truncate text-base font-semibold">{title}</h1>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-2 sm:gap-3">
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
