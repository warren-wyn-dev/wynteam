"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";
import { ChevronDown } from "lucide-react";

import { Button } from "@/components/ui/button";
import { LAST_ADMIN_WORKSPACE_KEY } from "@/components/admin/recent-workspace-link";
import { ADMIN_WORKSPACES, getAdminCurrentItem, getAdminWorkspace } from "@/lib/admin-nav";
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
  const router = useRouter();
  const workspace = getAdminWorkspace(pathname);
  const current = getAdminCurrentItem(pathname);
  const title = current?.label ?? workspace.label;

  useEffect(() => {
    if (workspace.id === "overview") return;
    try {
      window.localStorage.setItem(LAST_ADMIN_WORKSPACE_KEY, workspace.id);
    } catch {
      // Private-mode storage restrictions must not break navigation.
    }
  }, [workspace.id]);

  return (
    <header className="sticky top-0 z-30 flex min-h-16 shrink-0 flex-wrap items-center justify-between gap-3 border-b bg-background/95 px-4 py-3 backdrop-blur sm:px-6">
      <div className="flex min-w-0 flex-1 items-center gap-3">
        <div className="relative w-[150px] shrink-0 sm:w-[185px]">
          <label htmlFor="admin-workspace" className="sr-only">เลือกพื้นที่ทำงานของ WYNOS Admin</label>
          <select
            id="admin-workspace"
            value={workspace.id}
            onChange={(event) => {
              const next = ADMIN_WORKSPACES.find((item) => item.id === event.target.value);
              if (next) router.push(next.href);
            }}
            className="h-10 w-full appearance-none rounded-lg border bg-background py-2 pl-3 pr-9 text-sm font-medium focus-visible:outline-2 focus-visible:outline-offset-2"
          >
            {ADMIN_WORKSPACES.map((item) => (
              <option key={item.id} value={item.id}>{item.label}</option>
            ))}
          </select>
          <ChevronDown aria-hidden="true" className="pointer-events-none absolute right-3 top-3 size-4 text-muted-foreground" />
        </div>
        <div className="min-w-0 border-l pl-3 sm:pl-4">
          <p className="hidden truncate text-xs text-muted-foreground sm:block">{workspace.domain}</p>
          <h1 className="truncate text-sm font-semibold sm:text-base">{title}</h1>
        </div>
      </div>
      <div className="flex min-w-0 shrink-0 items-center gap-2 sm:gap-3">
        <span className="hidden rounded-full bg-secondary px-2.5 py-1 text-xs font-medium text-secondary-foreground sm:inline-flex">
          {ROLE_LABEL[role]}
        </span>
        {email ? <span className="hidden max-w-48 truncate text-sm text-muted-foreground lg:inline">{email}</span> : null}
        <form action={signOutAction}>
          <Button type="submit" variant="outline" size="sm" aria-label="ออกจากระบบ">
            ออกจากระบบ
          </Button>
        </form>
      </div>
    </header>
  );
}
