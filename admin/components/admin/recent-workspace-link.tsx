"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight, History } from "lucide-react";

import { ADMIN_WORKSPACES, type AdminWorkspace } from "@/lib/admin-nav";

/** UI-only preference; never store identifiers, credentials or app data. */
export const LAST_ADMIN_WORKSPACE_KEY = "wynos-admin:last-workspace";

export function RecentWorkspaceLink() {
  const [workspace, setWorkspace] = useState<AdminWorkspace | null>(null);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(LAST_ADMIN_WORKSPACE_KEY);
      const recent = ADMIN_WORKSPACES.find((item) => item.id === saved && item.id !== "overview");
      setWorkspace(recent ?? null);
    } catch {
      // Storage can be blocked by privacy settings; navigation still works.
    }
  }, []);

  if (!workspace) return null;

  return (
    <Link
      href={workspace.href}
      className="inline-flex min-h-11 w-fit items-center gap-2 rounded-lg border bg-background px-4 text-sm font-medium hover:bg-accent"
    >
      <History aria-hidden="true" className="size-4 text-muted-foreground" />
      ต่อจากครั้งล่าสุด: {workspace.label}
      <ArrowRight aria-hidden="true" className="size-4" />
    </Link>
  );
}
