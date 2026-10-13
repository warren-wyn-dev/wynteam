"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { ChevronDown, Search, XIcon } from "lucide-react";

import { cn } from "@/lib/utils";
import {
  ADMIN_NAV_GROUPS,
  adminNavItemsForRole,
  findActiveAdminNavItem,
  isAdminNavItemAvailable,
  searchAdminNavItems,
  type AdminNavItem,
} from "@/lib/admin-nav";
import type { AdminRole } from "@/lib/auth";
import type { AdminSystemAccess } from "@/lib/admin-systems";
import { useAdminNav } from "@/components/admin/nav-state";
import { Input } from "@/components/ui/input";

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
  const { drawerOpen, setDrawerOpen, query, setQuery } = useAdminNav();

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
            // Radix handles Escape during document capture, before the
            // search input's React handler. Clear search before dismissing.
            onEscapeKeyDown={(event) => {
              if (query) {
                event.preventDefault();
                setQuery("");
              }
            }}
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
      <span className="text-base font-semibold tracking-tight">WYNOS Admin</span>
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
  const { collapsed, toggleGroup, query, setQuery } = useAdminNav();
  const active = findActiveAdminNavItem(pathname, items);
  const filteredItems = searchAdminNavItems(items, query);
  const searching = query.trim().length > 0;
  const overview = filteredItems.find((item) => !item.group);
  const resultsId = `${idPrefix}-nav-results`;
  const statusId = `${idPrefix}-nav-search-status`;
  const navigate = () => {
    setQuery("");
    onNavigate?.();
  };

  return (
    <nav aria-label="เมนูหลัก" className="flex min-h-0 flex-1 flex-col border-t">
      <div role="search" aria-label="ค้นหาเมนู" className="shrink-0 border-b px-3 py-3">
        <label htmlFor={`${idPrefix}-menu-search`} className="sr-only">ค้นหาเมนู</label>
        <div className="relative">
          <Search aria-hidden className="pointer-events-none absolute left-3 top-3.5 size-4 text-muted-foreground" />
          <Input
            id={`${idPrefix}-menu-search`}
            type="search"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === "Escape" && query) {
                event.preventDefault();
                event.stopPropagation();
                setQuery("");
              }
            }}
            placeholder="ค้นหาเมนูไทย / English"
            autoComplete="off"
            aria-controls={resultsId}
            aria-describedby={statusId}
            className="pl-9 pr-11 shadow-none [&::-webkit-search-cancel-button]:hidden"
          />
          {query ? (
            <button
              type="button"
              aria-label="ล้างคำค้นหาเมนู"
              onClick={() => {
                setQuery("");
                document.getElementById(`${idPrefix}-menu-search`)?.focus();
              }}
              className="absolute right-0 top-0 grid size-11 place-items-center rounded-md text-muted-foreground hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <XIcon aria-hidden className="size-4" />
            </button>
          ) : null}
        </div>
        <p id={statusId} role="status" className="mt-2 text-xs text-muted-foreground">
          {searching ? `พบ ${filteredItems.length} เมนู` : "เลือกหมวดด้านล่าง หรือค้นหาชื่อเมนู"}
        </p>
      </div>
      <div id={resultsId} className="flex-1 overflow-y-auto overscroll-contain px-3 pb-8 pt-3">
        {overview ? (
          <div className="pb-3">
            <NavEntry item={overview} active={active === overview} onNavigate={navigate} prominent />
          </div>
        ) : null}

        {searching && filteredItems.length === 0 ? (
          <div className="rounded-md border border-dashed px-3 py-6 text-center">
            <p className="text-sm font-medium">ไม่พบเมนู</p>
            <p className="mt-1 text-xs text-muted-foreground">ลองค้นหาชื่อเมนูหรือหมวดอื่น</p>
          </div>
        ) : null}

        {ADMIN_NAV_GROUPS.map((group) => {
          const groupItems = filteredItems.filter((item) => item.group === group.id);
          if (groupItems.length === 0) return null;
          const expanded = searching || !collapsed.has(group.id);
          const holdsActive = active?.group === group.id;
          const listId = `${idPrefix}-nav-${group.id}`;
          const descriptionId = `${idPrefix}-nav-${group.id}-description`;
          const activeHintId = `${idPrefix}-nav-${group.id}-active`;
          const GroupIcon = group.icon;
          return (
            <section key={group.id} className="border-t py-3">
              {searching ? (
                <h2 className="flex items-center gap-2.5 px-2.5 pb-2 text-[13px] font-semibold">
                  <GroupIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                  <span className="flex-1">{group.label}</span>
                  <span className="text-xs font-normal text-muted-foreground">{groupItems.length}</span>
                </h2>
              ) : (
                <button
                  type="button"
                  aria-expanded={expanded}
                  aria-controls={listId}
                  aria-label={group.label}
                  aria-describedby={holdsActive && !expanded ? `${descriptionId} ${activeHintId}` : descriptionId}
                  onClick={() => toggleGroup(group.id)}
                  className="flex min-h-11 w-full items-center gap-2.5 rounded-md px-2.5 py-2 text-left text-[13px] font-semibold text-foreground/85 transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                >
                  <GroupIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
                  <span className="min-w-0 flex-1">
                    <span className="block">{group.label}</span>
                    <span id={descriptionId} className="mt-0.5 block text-xs font-normal leading-relaxed text-muted-foreground">{group.description}</span>
                  </span>
                  {holdsActive && !expanded ? (
                    <>
                      <span aria-hidden className="size-1.5 rounded-full bg-foreground" />
                      <span id={activeHintId} className="sr-only">(มีหน้าที่เปิดอยู่ในหมวดนี้)</span>
                    </>
                  ) : null}
                  <ChevronDown
                    aria-hidden
                    className={cn("size-4 shrink-0 text-muted-foreground transition-transform motion-reduce:transition-none", !expanded && "-rotate-90")}
                  />
                </button>
              )}
              <ul id={listId} hidden={!expanded} className="mt-1 flex flex-col gap-0.5 pl-1.5">
                {groupItems.map((item) => (
                  <li key={item.id}>
                    <NavEntry item={item} active={active === item} onNavigate={navigate} />
                  </li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>
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
