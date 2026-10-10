import {
  LayoutDashboard,
  Users,
  ShieldAlert,
  Flag,
  ScrollText,
  Megaphone,
  Store,
  UtensilsCrossed,
  ShoppingBag,
  TicketPercent,
  Gift,
  BadgeDollarSign,
  BellRing,
  MapPinned,
  KeyRound,
  type LucideIcon,
} from "lucide-react";

import type { AdminRole } from "@/lib/auth";
import { hasSystemAccess, type AdminLevel, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";

/**
 * WYN-219 Phase 1: the sidebar is grouped by WYNOS system (Founder decision
 * 2026-10-10). Group order here is the order shown.
 */
export const ADMIN_NAV_GROUPS = [
  { id: "overview", label: "ภาพรวม" },
  { id: "account", label: "WYNOS Account" },
  { id: "social", label: "WYNOS Social" },
  { id: "food", label: "WYNOS Food" },
  { id: "merchant", label: "WYNOS Merchant" },
  { id: "maps", label: "WYNOS Maps" },
  { id: "system", label: "ระบบ" },
] as const;

export type AdminNavGroupId = (typeof ADMIN_NAV_GROUPS)[number]["id"];

export type AdminNavItem = {
  href: string;
  label: string;
  icon: LucideIcon;
  group: AdminNavGroupId;
  /**
   * Hides the item from moderators. Navigation only -- each page still
   * enforces its own role check server-side.
   */
  adminOnly?: boolean;
  /** Shown only to the WYN-219 super admin (navigation only, as above). */
  superAdminOnly?: boolean;
  /**
   * WYN-219: who sees the item once per-system permissions exist -- any of
   * these systems at `level` (default view), or "any" permission at all.
   * Navigation only: every page and RPC re-checks.
   */
  requires?: { systems: AdminSystem[]; level?: AdminLevel } | "any";
  /** The task that will fill this page in -- shown on its placeholder. */
  task: string;
  feature: string;
};

export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard, group: "overview", requires: "any", task: "WYN-050", feature: "Admin Dashboard" },
  // Moderators (Social only) still open user pages to apply sanctions.
  { href: "/users", label: "User Management", icon: Users, group: "account", requires: { systems: ["account", "social"] }, task: "WYN-051", feature: "Admin User Management" },
  { href: "/moderation", label: "Content Moderation", icon: ShieldAlert, group: "social", requires: { systems: ["social"] }, task: "WYN-052", feature: "Admin Content Moderation" },
  { href: "/reports", label: "Report Center", icon: Flag, group: "social", requires: { systems: ["social"] }, task: "WYN-053", feature: "Admin Report Center" },
  { href: "/announcements", label: "Announcements", icon: Megaphone, group: "social", requires: { systems: ["social"] }, task: "WYN-055", feature: "Official Announcements" },
  { href: "/food", label: "Stores", icon: UtensilsCrossed, group: "food", requires: { systems: ["food"] }, task: "WYN-203", feature: "WYNOS Food store operations" },
  { href: "/food/orders", label: "Orders", icon: ShoppingBag, group: "food", adminOnly: true, requires: { systems: ["food"], level: "edit" }, task: "WYN-203", feature: "WYNOS Food orders" },
  { href: "/food/coupons", label: "Coupons", icon: TicketPercent, group: "food", requires: { systems: ["food"] }, task: "WYN-219", feature: "WYNOS Food coupons" },
  { href: "/food/campaigns", label: "Campaigns", icon: Gift, group: "food", requires: { systems: ["food"] }, task: "WYN-219", feature: "WYNOS campaigns" },
  { href: "/food/ads", label: "Ads", icon: BadgeDollarSign, group: "food", adminOnly: true, requires: { systems: ["food"], level: "edit" }, task: "WYN-219", feature: "WYNOS Food ads" },
  { href: "/food/notifications", label: "Promo Notifications", icon: BellRing, group: "food", requires: { systems: ["food"] }, task: "WYN-219", feature: "WYNOS Food promo notifications" },
  { href: "/merchants", label: "Merchant Applications", icon: Store, group: "merchant", requires: { systems: ["merchant"] }, task: "MERCHANT", feature: "Merchant Application Review" },
  { href: "/maps/places", label: "Places", icon: MapPinned, group: "maps", requires: { systems: ["maps"] }, task: "WYN-219", feature: "WYNOS Places Manager" },
  { href: "/audit-log", label: "Audit Log", icon: ScrollText, group: "system", superAdminOnly: true, task: "WYN-054", feature: "Audit Log" },
  { href: "/team", label: "Team Permissions", icon: KeyRound, group: "system", superAdminOnly: true, task: "WYN-219", feature: "Team Permissions" },
];

export function adminNavItemsForRole(role: AdminRole, access: AdminSystemAccess): AdminNavItem[] {
  return ADMIN_NAV_ITEMS.filter((item) => {
    if (item.superAdminOnly) {
      // Before the foundation exists the audit log stays visible to staff as before.
      return access.superAdmin || (!access.available && item.href === "/audit-log");
    }
    if (access.available && item.requires) {
      if (access.superAdmin) return true;
      if (item.requires === "any") return Object.keys(access.permissions).length > 0;
      const { systems, level = "view" } = item.requires;
      return systems.some((system) => hasSystemAccess(access, system, level) === true);
    }
    return role === "admin" || !item.adminOnly;
  });
}

/**
 * The item a path belongs to: the longest href that equals the path or is a
 * parent segment of it, so `/food/orders/123` resolves to Orders and
 * `/food/stores/9` to Stores. Dashboard (`/`) only matches itself.
 */
export function findActiveAdminNavItem(pathname: string, items: AdminNavItem[] = ADMIN_NAV_ITEMS): AdminNavItem | undefined {
  let match: AdminNavItem | undefined;
  for (const item of items) {
    const matches =
      item.href === "/" ? pathname === "/" : pathname === item.href || pathname.startsWith(`${item.href}/`);
    if (matches && (!match || item.href.length > match.href.length)) match = item;
  }
  return match;
}
