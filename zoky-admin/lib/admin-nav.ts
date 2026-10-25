import {
  LayoutDashboard,
  Users,
  Store,
  UtensilsCrossed,
  ShoppingBag,
  TicketPercent,
  Gift,
  BadgeDollarSign,
  BadgeCheck,
  BellRing,
  MessageCircle,
  CreditCard,
  Headset,
  BookOpen,
  Wallet,
  Truck,
  Clock3,
  SlidersHorizontal,
  Images,
  UserCog,
  type LucideIcon,
} from "lucide-react";

import type { AdminRole, ZokySystem } from "@/lib/auth";
import { hasSystemAccess, type AdminLevel, type AdminSystem, type AdminSystemAccess } from "@/lib/admin-systems";

/**
 * ZOKY Admin sections, in display order (ZOKY-ADMIN-001, Founder-approved
 * 2026-10-25). Items without `href` have no page yet: the sidebar shows them
 * disabled ("เร็วๆ นี้").
 */
export const ADMIN_NAV_GROUPS = [
  { id: "food", label: "ZOKY Food", icon: UtensilsCrossed, description: "ดูแลฝั่งลูกค้า คำสั่งซื้อ และการชำระเงิน" },
  { id: "merchant", label: "ZOKY Merchant", icon: Store, description: "ดูแลร้านค้า เมนู คูปอง แคมเปญ และโฆษณาของร้านค้า" },
  { id: "team", label: "ทีม ZOKY", icon: UserCog, description: "สมาชิกทีม ZOKY และสิทธิ์ Food/Merchant" },
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
  /** Absent for the top-level "ภาพรวม". */
  group?: AdminNavGroupId;
  /** Shown only to the WYN-219 super admin (navigation only). */
  superAdminOnly?: boolean;
  /** Shown only to the super admin and ZOKY Team Leads (navigation only). */
  teamManagersOnly?: boolean;
  /**
   * Who sees the item: any of these systems at `level` (default view), or
   * "any" ZOKY permission. Navigation only: every page and RPC re-checks.
   */
  requires?: { systems: AdminSystem[]; level?: AdminLevel } | "any";
};

/** The ZOKY Food / ZOKY Merchant dashboard is the section's root route. */
export function systemDashboardHref(system: ZokySystem) {
  return `/${system}`;
}

/** "ภาพรวม": always first, outside every section. */
export const ADMIN_NAV_OVERVIEW: AdminNavItem = {
  id: "overview",
  href: "/",
  label: "ภาพรวม",
  icon: LayoutDashboard,
  requires: "any",
};

export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  ADMIN_NAV_OVERVIEW,

  // ZOKY Food: the customer and order side.
  { id: "food-dashboard", href: "/food", label: "Dashboard", icon: LayoutDashboard, group: "food", requires: { systems: ["food"] } },
  { id: "food-control", href: "/food/control", label: "ศูนย์ควบคุม Food", icon: SlidersHorizontal, group: "food", requires: { systems: ["food"] } },
  { id: "food-banners", href: "/food/banners", label: "แบนเนอร์หน้าแรก Food", icon: Images, group: "food", requires: { systems: ["food"] } },
  { id: "food-reviews", href: "/food/reviews", label: "ตรวจสอบรีวิว Food", icon: MessageCircle, group: "food", requires: { systems: ["food"] } },
  { id: "food-featured", href: "/food/featured", label: "ร้านแนะนำ Food", icon: Store, group: "food", requires: { systems: ["food"] } },
  { id: "food-orders", href: "/food/orders", label: "Orders", icon: ShoppingBag, group: "food", requires: { systems: ["food"], level: "edit" } },
  { id: "food-customers", label: "Customers", icon: Users, group: "food", requires: { systems: ["food"] } },
  { id: "food-payments", label: "Payments & Refunds", icon: CreditCard, group: "food", requires: { systems: ["food"] } },
  { id: "food-support", label: "Customer Support", icon: Headset, group: "food", requires: { systems: ["food"] } },

  // ZOKY Merchant: stores and their marketing. Stores, Coupons, Campaigns,
  // Ads and Promo Notifications still require the `food` permission they
  // always did (decision 2026-10-11) -- only their URLs moved.
  { id: "merchant-dashboard", href: "/merchant", label: "Dashboard", icon: LayoutDashboard, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "merchant-control", href: "/merchant/control", label: "ศูนย์ควบคุม Merchant", icon: SlidersHorizontal, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "stores", href: "/merchant/stores", label: "Stores", icon: Store, group: "merchant", requires: { systems: ["food"] } },
  { id: "merchant-verification", href: "/merchant/verification", label: "Merchant Verification", icon: BadgeCheck, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "menu-management", href: "/merchant/menu", label: "Menu Management", icon: BookOpen, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "coupons", href: "/merchant/coupons", label: "Coupons", icon: TicketPercent, group: "merchant", requires: { systems: ["food"] } },
  { id: "campaigns", href: "/merchant/campaigns", label: "Campaigns", icon: Gift, group: "merchant", requires: { systems: ["food"] } },
  { id: "ads", href: "/merchant/ads", label: "Ads", icon: BadgeDollarSign, group: "merchant", requires: { systems: ["food"], level: "edit" } },
  { id: "promo-notifications", href: "/merchant/notifications", label: "Promo Notifications", icon: BellRing, group: "merchant", requires: { systems: ["food"] } },
  { id: "merchant-finance", href: "/merchant/finance", label: "การเงินร้านค้า", icon: Wallet, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "merchant-delivery", href: "/merchant/delivery", label: "ค่าส่งและรัศมีรายร้าน", icon: Truck, group: "merchant", requires: { systems: ["merchant"] } },
  { id: "merchant-operations", href: "/merchant/operations", label: "เปิด–ปิดร้านและเวลาเตรียม", icon: Clock3, group: "merchant", requires: { systems: ["merchant"] } },

  { id: "zoky-team", href: "/team", label: "สมาชิกและสิทธิ์", icon: UserCog, group: "team", teamManagersOnly: true },
];

export function isAdminNavItemAvailable(item: AdminNavItem): item is AdminNavItem & { href: string } {
  return typeof item.href === "string";
}

/**
 * Unlike WYNOS Admin there is no pre-WYN-219 fallback: requireAdminRole()
 * only lets in accounts whose food/merchant permissions were read, so
 * `access.available` is always true here. `role` stays in the signature so
 * the sidebar is shared verbatim with WYNOS Admin.
 */
export function adminNavItemsForRole(_role: AdminRole, access: AdminSystemAccess): AdminNavItem[] {
  return ADMIN_NAV_ITEMS.filter((item) => {
    if (access.superAdmin) return true;
    if (item.superAdminOnly) return false;
    if (item.teamManagersOnly) return access.teamLead;
    if (!item.requires || item.requires === "any") return true;
    const { systems, level = "view" } = item.requires;
    return systems.some((system) => hasSystemAccess(access, system, level) === true);
  });
}

/**
 * The item a path belongs to: the longest href that equals the path or is a
 * parent segment of it. "ภาพรวม" (`/`) only matches itself. Items without a
 * page never match.
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
