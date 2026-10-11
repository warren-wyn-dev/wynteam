"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { ChevronDown, XIcon } from "lucide-react";

import { cn } from "@/lib/utils";
import {
  ADMIN_NAV_GROUPS,
  adminNavItemsForRole,
  findActiveAdminNavItem,
  isAdminNavItemAvailable,
  type AdminNavItem,
} from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";
import type { AdminSystemAccess } from "@/lib/admin-systems";
import { useAdminNav } from "@/components/admin/nav-state";

export const ADMIN_DRAWER_ID = "admin-nav-drawer";
export const ADMIN_MENU_BUTTON_ID = "admin-nav-menu-button";

/**
 * Permanent sidebar from the md breakpoint (tablet and desktop); below it the
 * same menu opens as a drawer from the header's menu button. Which items
 * appear follows adminNavItemsForRole -- navigation only, every page and RPC
 * re-checks access server-side.
 */
export function AdminSidebar({ role, access }: { role: AdminRole; access: AdminSystemAccess }) {
  const items = adminNavItemsForRole(role, access);
  const { drawerOpen, setDrawerOpen } = useAdminNav();

  return (
    <>
      <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col border-r bg-background md:flex lg:w-72">
        <Brand />
        <AdminNavList items={items} idPrefix="sidebar" />
      </aside>

      <DialogPrimitive.Root open={drawerOpen} onOpenChange={setDrawerOpen}>
        <DialogPrimitive.Portal>
          <DialogPrimitive.Overlay className="fixed inset-0 z-50 bg-black/40 md:hidden" />
          <DialogPrimitive.Content
            id={ADMIN_DRAWER_ID}
            aria-describedby={undefined}
            // The header's menu button opens the drawer from outside this
            // Dialog (no Dialog.Trigger), so hand focus back to it ourselves.
            onCloseAutoFocus={(event) => {
              const button = document.getElementById(ADMIN_MENU_BUTTON_ID);
              if (button && button.offsetParent !== null) {
                event.preventDefault();
                button.focus();
              }
            }}
            className="fixed inset-y-0 left-0 z-50 flex w-[min(85vw,20rem)] flex-col bg-background shadow-xl focus:outline-none md:hidden"
          >
            <div className="flex items-center justify-between gap-2 border-b pr-2">
              <DialogPrimitive.Title asChild>
                <div>
                  <Brand />
                </div>
              </DialogPrimitive.Title>
              <DialogPrimitive.Close
                className="inline-flex size-11 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                aria-label="ปิดเมนู"
              >
                <XIcon className="size-5" aria-hidden />
              </DialogPrimitive.Close>
            </div>
            <AdminNavList items={items} idPrefix="drawer" onNavigate={() => setDrawerOpen(false)} />
          </DialogPrimitive.Content>
        </DialogPrimitive.Portal>
      </DialogPrimitive.Root>
    </>
  );
}

function Brand() {
  return (
    <div className="flex h-16 shrink-0 items-center gap-3 px-5">
      <span aria-hidden className="grid size-8 place-items-center rounded-lg bg-foreground text-base font-bold text-background">
        W
      </span>
      <span className="text-base font-semibold tracking-tight">WYN Admin</span>
    </div>
  );
}

function AdminNavList({
  items,
  idPrefix,
  onNavigate,
}: {
  items: AdminNavItem[];
  /** Keeps element ids unique: the sidebar and the drawer render the same list. */
  idPrefix: string;
  onNavigate?: () => void;
}) {
  const pathname = usePathname();
  const { collapsed, toggleGroup } = useAdminNav();
  const active = findActiveAdminNavItem(pathname, items);
  const overview = items.find((item) => !item.group);

  return (
    <nav aria-label="เมนูหลัก" className="flex-1 overflow-y-auto overscroll-contain border-t px-3 pb-8 pt-3">
      {overview ? (
        <div className="pb-3">
          <NavEntry item={overview} active={active === overview} onNavigate={onNavigate} prominent />
        </div>
      ) : null}

      {ADMIN_NAV_GROUPS.map((group) => {
        const groupItems = items.filter((item) => item.group === group.id);
        if (groupItems.length === 0) return null;
        const expanded = !collapsed.has(group.id);
        const holdsActive = active?.group === group.id;
        const listId = `${idPrefix}-nav-${group.id}`;
        const GroupIcon = group.icon;
        return (
          <section key={group.id} className="border-t py-3">
            <button
              type="button"
              aria-expanded={expanded}
              aria-controls={listId}
              onClick={() => toggleGroup(group.id)}
              className="flex min-h-11 w-full items-center gap-2.5 rounded-md px-2.5 text-left text-[13px] font-semibold text-foreground/85 transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <GroupIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <span className="flex-1">{group.label}</span>
              {holdsActive && !expanded ? (
                <>
                  <span aria-hidden className="size-1.5 rounded-full bg-foreground" />
                  <span className="sr-only">(มีหน้าที่เปิดอยู่ในหมวดนี้)</span>
                </>
              ) : null}
              <ChevronDown
                aria-hidden
                className={cn("size-4 shrink-0 text-muted-foreground transition-transform motion-reduce:transition-none", !expanded && "-rotate-90")}
              />
            </button>
            <ul id={listId} hidden={!expanded} className="mt-1 flex flex-col gap-0.5 pl-1.5">
              {groupItems.map((item) => (
                <li key={item.id}>
                  <NavEntry item={item} active={active === item} onNavigate={onNavigate} />
                </li>
              ))}
            </ul>
          </section>
        );
      })}
    </nav>
  );
}

function NavEntry({
  item,
  active,
  onNavigate,
  prominent = false,
}: {
  item: AdminNavItem;
  active: boolean;
  onNavigate?: () => void;
  prominent?: boolean;
}) {
  const Icon = item.icon;
  const base = cn(
    "flex min-h-11 w-full items-center gap-3 rounded-md px-3 text-sm",
    prominent ? "font-semibold" : "pl-4 font-medium",
  );

  // No page yet: shown so the menu reflects the planned structure, but never
  // a link -- nothing to click into, no 404, no implication it already works.
  if (!isAdminNavItemAvailable(item)) {
    return (
      <span aria-disabled="true" className={cn(base, "cursor-not-allowed text-muted-foreground/60")}>
        <Icon className="size-4 shrink-0" aria-hidden />
        <span className="flex-1 truncate">{item.label}</span>
        <span className="shrink-0 rounded-full border px-2 py-0.5 text-[11px] font-medium text-muted-foreground">เร็วๆ นี้</span>
      </span>
    );
  }

  return (
    <Link
      href={item.href}
      aria-current={active ? "page" : undefined}
      onClick={onNavigate}
      className={cn(
        base,
        "transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
        // Per wyn-admin-design-system.md section 6.8/3.3: active state is
        // conveyed by neutral weight/contrast alone (`bg-muted` +
        // `text-foreground`), which stays dark-mode-safe.
        active
          ? "bg-muted font-semibold text-foreground"
          : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
      )}
    >
      <Icon className="size-4 shrink-0" aria-hidden />
      <span className="truncate">{item.label}</span>
    </Link>
  );
}
