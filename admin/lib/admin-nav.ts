import {
  LayoutDashboard,
  Users,
  ShieldAlert,
  ShieldCheck,
  Lock,
  Flag,
  ScrollText,
  Megaphone,
  Store,
  UtensilsCrossed,
  ShoppingBag,
  TicketPercent,
  Gift,
  BadgeDollarSign,
  BadgeCheck,
  BellRing,
  MapPinned,
  Map as MapIcon,
  MessageCircle,
  CreditCard,
  Headset,
  BookOpen,
  MapPinOff,
  Bot,
  Settings,
  type LucideIcon,
} from "lucide-react";

import type { AdminRole } from "@/lib/auth";
import { hasSystemAccess, type AdminLevel, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";

/**
 * Sidebar sections, in display order (Founder sidebar restructure,
 * 2026-10-11). "Dashboard รวม" sits above every section and belongs to none
 * of them. Moving an item between sections changes navigation only -- the
 * route, its page and its permission check stay where they were.
 */
export const ADMIN_NAV_GROUPS = [
  { id: "account", label: "WYNOS Account", icon: Users, description: "บัญชีผู้ใช้ส่วนกลาง สิทธิ์ และความปลอดภัย" },
  { id: "social", label: "WYNOS Social", icon: MessageCircle, description: "จัดการเนื้อหา รายงาน และประกาศ" },
  { id: "food", label: "WYNOS Food", icon: UtensilsCrossed, description: "ดูแลฝั่งลูกค้า คำสั่งซื้อ และการชำระเงิน" },
  { id: "merchant", label: "WYNOS Merchant", icon: Store, description: "ดูแลร้านค้า เมนู คูปอง แคมเปญ และโฆษณาของร้านค้า" },
  { id: "maps", label: "WYNOS Maps", icon: MapIcon, description: "สถานที่และความถูกต้องของข้อมูลแผนที่" },
  { id: "other", label: "อื่นๆ", icon: Settings, description: "เครื่องมือข้ามระบบ การตลาดระดับแพลตฟอร์ม และการตั้งค่า" },
] as const satisfies ReadonlyArray<{ id: string; label: string; icon: LucideIcon; description: string }>;

export type AdminNavGroupId = (typeof ADMIN_NAV_GROUPS)[number]["id"];

export type AdminNavItem = {
  /** Stable key, also used for items that have no route yet. */
  id: string;
  /**
   * The page this item opens. Absent means the feature has no page yet: the
   * sidebar shows it disabled with a "เร็วๆ นี้" badge and never links it.
   */
  href?: string;
  label: string;
  icon: LucideIcon;
  /** Absent for the top-level "Dashboard รวม". */
  group?: AdminNavGroupId;
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
};

/** The per-system dashboard route (app/(admin)/dashboard/[system]). */
export function systemDashboardHref(system: AdminSystem) {
  return `/dashboard/${system}`;
}

function systemDashboard(system: AdminSystem): AdminNavItem {
  return {
    id: `${system}-dashboard`,
    href: systemDashboardHref(system),
    label: "Dashboard",
    icon: LayoutDashboard,
    group: system,
    requires: { systems: [system] },
  };
}

/** "Dashboard รวม": always first, outside every section. */
export const ADMIN_NAV_OVERVIEW: AdminNavItem = {
  id: "overview",
  href: "/",
  label: "Dashboard รวม",
  icon: LayoutDashboard,
  requires: "any",
};

export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  ADMIN_NAV_OVERVIEW,

  systemDashboard("account"),
  // Moderators (Social only) still open user pages to apply sanctions.
  { id: "users", href: "/users", label: "User Management", icon: Users, group: "account", requires: { systems: ["account", "social"] } },
  { id: "roles", href: "/team", label: "Roles & Permissions", icon: ShieldCheck, group: "account", superAdminOnly: true },
  { id: "account-security", label: "Account Security", icon: Lock, group: "account", requires: { systems: ["account"] } },

  systemDashboard("social"),
  { id: "moderation", href: "/moderation", label: "Content Moderation", icon: ShieldAlert, group: "social", requires: { systems: ["social"] } },
  { id: "reports", href: "/reports", label: "Report Center", icon: Flag, group: "social", requires: { systems: ["social"] } },
  { id: "announcements", href: "/announcements", label: "Announcements", icon: Megaphone, group: "social", requires: { systems: ["social"] } },

  // WYNOS Food: the customer and order side.
  systemDashboard("food"),
  { id: "food-orders", href: "/food/orders", label: "Orders", icon: ShoppingBag, group: "food", adminOnly: true, requires: { systems: ["food"], level: "edit" } },
  { id: "food-customers", label: "Customers", icon: Users, group: "food", requires: { systems: ["food"] } },
  { id: "food-payments", label: "Payments & Refunds", icon: CreditCard, group: "food", requires: { systems: ["food"] } },
  { id: "food-support", label: "Customer Support", icon: Headset, group: "food", requires: { systems: ["food"] } },

  // WYNOS Merchant: stores and their marketing. Stores, Coupons, Campaigns,
  // Ads and Promo Notifications moved here from WYNOS Food; they keep their
  // /food/* URLs and still require the `food` permission they always did.
  systemDashboard("merchant"),
  { id: "stores", href: "/food", label: "Stores", icon: Store, group: "merchant", requires: { systems: ["food"] } },
  { id: "merchant-verification", href: "/merchants", label: "Merchant Verification", icon: BadgeCheck, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "menu-management", label: "Menu Management", icon: BookOpen, group: "merchant", requires: { systems: ["merchant", "food"] } },
  { id: "coupons", href: "/food/coupons", label: "Coupons", icon: TicketPercent, group: "merchant", requires: { systems: ["food"] } },
  { id: "campaigns", href: "/food/campaigns", label: "Campaigns", icon: Gift, group: "merchant", requires: { systems: ["food"] } },
  { id: "ads", href: "/food/ads", label: "Ads", icon: BadgeDollarSign, group: "merchant", adminOnly: true, requires: { systems: ["food"], level: "edit" } },
  { id: "promo-notifications", href: "/food/notifications", label: "Promo Notifications", icon: BellRing, group: "merchant", requires: { systems: ["food"] } },

  systemDashboard("maps"),
  { id: "places", href: "/maps/places", label: "Place Management", icon: MapPinned, group: "maps", requires: { systems: ["maps"] } },
  { id: "map-reports", label: "Map Reports", icon: MapPinOff, group: "maps", requires: { systems: ["maps"] } },

  { id: "ai-secretary", label: "AI Secretary", icon: Bot, group: "other", requires: "any" },
  { id: "platform-marketing", label: "Platform Marketing", icon: Megaphone, group: "other", requires: "any" },
  { id: "audit-log", href: "/audit-log", label: "Audit Logs", icon: ScrollText, group: "other", superAdminOnly: true },
  { id: "system-settings", label: "System Settings", icon: Settings, group: "other", superAdminOnly: true },
];

export function isAdminNavItemAvailable(item: AdminNavItem): item is AdminNavItem & { href: string } {
  return typeof item.href === "string";
}

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
 * `/food/stores/9` to Stores. Dashboard รวม (`/`) only matches itself.
 * Items without a page never match.
 */
export function findActiveAdminNavItem(pathname: string, items: AdminNavItem[] = ADMIN_NAV_ITEMS): AdminNavItem | undefined {
  let match: (AdminNavItem & { href: string }) | undefined;
  for (const item of items) {
    if (!isAdminNavItemAvailable(item)) continue;
    const matches =
      item.href === "/" ? pathname === "/" : pathname === item.href || pathname.startsWith(`${item.href}/`);
    if (matches && (!match || item.href.length > match.href.length)) match = item;
  }
  return match;
}
