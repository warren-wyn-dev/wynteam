"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { usePathname } from "next/navigation";

import { findActiveAdminNavItem, type AdminNavGroupId } from "@/lib/admin-nav";

type AdminNavState = {
  /** Mobile drawer (below the md breakpoint). */
  drawerOpen: boolean;
  setDrawerOpen: (open: boolean) => void;
  /** Sections the admin collapsed. Shared by the desktop sidebar and the drawer. */
  collapsed: ReadonlySet<AdminNavGroupId>;
  toggleGroup: (group: AdminNavGroupId) => void;
};

const AdminNavContext = createContext<AdminNavState | null>(null);

/** md in Tailwind's default scale: the sidebar is permanent from here up. */
const DESKTOP_QUERY = "(min-width: 768px)";

/**
 * Sidebar UI state that the header (menu button) and the sidebar share.
 * Every section starts expanded; collapsing lasts for the session because
 * the admin layout, and so this provider, survives client-side navigation.
 */
export function AdminNavProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [collapsed, setCollapsed] = useState<ReadonlySet<AdminNavGroupId>>(() => new Set());
  const [seenPathname, setSeenPathname] = useState(pathname);

  // Every navigation (a menu tap, Back/Forward, a link inside a page) closes
  // the drawer and reopens the section that holds the new page, so the
  // active item is never hidden inside a collapsed section.
  if (pathname !== seenPathname) {
    setSeenPathname(pathname);
    setDrawerOpen(false);
    const group = findActiveAdminNavItem(pathname)?.group;
    if (group && collapsed.has(group)) {
      const next = new Set(collapsed);
      next.delete(group);
      setCollapsed(next);
    }
  }

  // Growing past the breakpoint hides the drawer with CSS; close it too so
  // its focus trap and scroll lock don't outlive it.
  useEffect(() => {
    const media = window.matchMedia(DESKTOP_QUERY);
    const onChange = () => {
      if (media.matches) setDrawerOpen(false);
    };
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, []);

  const toggleGroup = useCallback((group: AdminNavGroupId) => {
    setCollapsed((current) => {
      const next = new Set(current);
      if (!next.delete(group)) next.add(group);
      return next;
    });
  }, []);

  const value = useMemo(
    () => ({ drawerOpen, setDrawerOpen, collapsed, toggleGroup }),
    [drawerOpen, collapsed, toggleGroup],
  );

  return <AdminNavContext.Provider value={value}>{children}</AdminNavContext.Provider>;
}

export function useAdminNav(): AdminNavState {
  const state = useContext(AdminNavContext);
  if (!state) throw new Error("useAdminNav must be used inside AdminNavProvider");
  return state;
}
