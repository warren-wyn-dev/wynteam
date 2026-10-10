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
import { hasSystemAccess, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";

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
   * WYN-219 step 2: once a system's checks use per-system permissions, its
   * items show only to people with at least view access to that system.
   */
  system?: AdminSystem;
  /** The task that will fill this page in -- shown on its placeholder. */
  task: string;
  feature: string;
};

export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard, group: "overview", task: "WYN-050", feature: "Admin Dashboard" },
  { href: "/users", label: "User Management", icon: Users, group: "account", task: "WYN-051", feature: "Admin User Management" },
  { href: "/moderation", label: "Content Moderation", icon: ShieldAlert, group: "social", task: "WYN-052", feature: "Admin Content Moderation" },
  { href: "/reports", label: "Report Center", icon: Flag, group: "social", task: "WYN-053", feature: "Admin Report Center" },
  { href: "/announcements", label: "Announcements", icon: Megaphone, group: "social", task: "WYN-055", feature: "Official Announcements" },
  { href: "/food", label: "Stores", icon: UtensilsCrossed, group: "food", task: "WYN-203", feature: "WYNOS Food store operations" },
  { href: "/food/orders", label: "Orders", icon: ShoppingBag, group: "food", adminOnly: true, task: "WYN-203", feature: "WYNOS Food orders" },
  { href: "/food/coupons", label: "Coupons", icon: TicketPercent, group: "food", task: "WYN-219", feature: "WYNOS Food coupons" },
  { href: "/food/campaigns", label: "Campaigns", icon: Gift, group: "food", task: "WYN-219", feature: "WYNOS campaigns" },
  { href: "/food/ads", label: "Ads", icon: BadgeDollarSign, group: "food", adminOnly: true, task: "WYN-219", feature: "WYNOS Food ads" },
  { href: "/food/notifications", label: "Promo Notifications", icon: BellRing, group: "food", task: "WYN-219", feature: "WYNOS Food promo notifications" },
  { href: "/merchants", label: "Merchant Applications", icon: Store, group: "merchant", task: "MERCHANT", feature: "Merchant Application Review" },
  { href: "/maps/places", label: "Places", icon: MapPinned, group: "maps", system: "maps", task: "WYN-219", feature: "WYNOS Places Manager" },
  { href: "/audit-log", label: "Audit Log", icon: ScrollText, group: "system", task: "WYN-054", feature: "Audit Log" },
  { href: "/team", label: "Team Permissions", icon: KeyRound, group: "system", superAdminOnly: true, task: "WYN-219", feature: "Team Permissions" },
];

export function adminNavItemsForRole(role: AdminRole, access: AdminSystemAccess): AdminNavItem[] {
  return ADMIN_NAV_ITEMS.filter((item) => {
    if (item.superAdminOnly && !access.superAdmin) return false;
    // Per-system items follow the permission once it exists in this database.
    const systemAccess = item.system ? hasSystemAccess(access, item.system) : null;
    if (systemAccess !== null) return systemAccess;
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
