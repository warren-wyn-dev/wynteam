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
    <header className="flex h-14 shrink-0 items-center justify-between border-b bg-background px-6">
      <h1 className="text-base font-semibold">{title}</h1>
      <div className="flex items-center gap-3">
        <span className="rounded-full bg-secondary px-2.5 py-0.5 text-xs font-medium text-secondary-foreground">
          {ROLE_LABEL[role]}
        </span>
        {email ? <span className="text-sm text-muted-foreground">{email}</span> : null}
        <form action={signOutAction}>
          <Button type="submit" variant="outline" size="sm" aria-label="ออกจากระบบ">
            ออกจากระบบ
          </Button>
        </form>
      </div>
    </header>
  );
}
