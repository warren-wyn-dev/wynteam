"use client";

import Link from "next/link";
import { useSyncExternalStore } from "react";
import { ArrowRight, History } from "lucide-react";

import { ADMIN_WORKSPACES } from "@/lib/admin-nav";

/** UI-only preference; never store identifiers, credentials or app data. */
export const LAST_ADMIN_WORKSPACE_KEY = "wynos-admin:last-workspace";

function subscribeToStorageChange(onChange: () => void) {
  window.addEventListener("storage", onChange);
  return () => window.removeEventListener("storage", onChange);
}

function readLastWorkspace() {
  try {
    return window.localStorage.getItem(LAST_ADMIN_WORKSPACE_KEY);
  } catch {
    return null;
  }
}

function serverLastWorkspace() {
  return null;
}

export function RecentWorkspaceLink() {
  const saved = useSyncExternalStore(subscribeToStorageChange, readLastWorkspace, serverLastWorkspace);
  const workspace = ADMIN_WORKSPACES.find((item) => item.id === saved && item.id !== "overview");

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
