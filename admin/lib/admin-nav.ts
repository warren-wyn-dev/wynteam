import {
  Bell,
  BookOpenText,
  ClipboardCheck,
  Flag,
  Gift,
  House,
  LayoutDashboard,
  MapPinned,
  Megaphone,
  ScrollText,
  ShieldAlert,
  ShoppingBag,
  Store,
  TicketPercent,
  Users,
  UtensilsCrossed,
  type LucideIcon,
} from "lucide-react";

import type { AdminRole } from "@/lib/auth";

export type AdminWorkspaceId = "overview" | "social" | "food" | "merchant" | "central";

export type AdminNavItem = {
  href: string;
  label: string;
  icon: LucideIcon;
  task: string;
  feature: string;
  /** Hide privileged destinations from the menu; backend auth remains authoritative. */
  roles?: readonly AdminRole[];
};

export type AdminWorkspace = {
  id: AdminWorkspaceId;
  label: string;
  shortLabel: string;
  domain: string;
  description: string;
  href: string;
  icon: LucideIcon;
  items: readonly AdminNavItem[];
};

/**
 * Navigation is organized by operational responsibility, not database tables.
 * All legacy deep links stay valid. Never duplicate Food/Merchant actions in
 * another workspace: moving the *menu* does not move the underlying route.
 */
export const ADMIN_WORKSPACES: readonly AdminWorkspace[] = [
  {
    id: "overview",
    label: "ภาพรวมระบบ",
    shortLabel: "ภาพรวม",
    domain: "WYNOS Admin",
    description: "เลือกพื้นที่ทำงานของแต่ละบริการ",
    href: "/",
    icon: House,
    items: [
      { href: "/", label: "ศูนย์รวมระบบ", icon: LayoutDashboard, task: "ADMIN-WORKSPACES", feature: "Platform overview" },
    ],
  },
  {
    id: "social",
    label: "WYNOS Social",
    shortLabel: "Social",
    domain: "wynos.online",
    description: "ผู้ใช้ เนื้อหา และความปลอดภัยชุมชน",
    href: "/social",
    icon: Users,
    items: [
      { href: "/social", label: "แดชบอร์ดโซเชียล", icon: LayoutDashboard, task: "WYN-050", feature: "Admin Dashboard" },
      { href: "/users", label: "ผู้ใช้งาน", icon: Users, task: "WYN-051", feature: "Admin User Management" },
      { href: "/moderation", label: "ตรวจสอบเนื้อหา", icon: ShieldAlert, task: "WYN-052", feature: "Admin Content Moderation" },
      { href: "/reports", label: "รายงานการละเมิด", icon: Flag, task: "WYN-053", feature: "Admin Report Center" },
      { href: "/announcements", label: "ประกาศและแจ้งเตือน", icon: Megaphone, task: "WYN-055", feature: "Official Announcements" },
    ],
  },
  {
    id: "food",
    label: "WYNOS Food",
    shortLabel: "Food",
    domain: "food.wynos.online",
    description: "การสั่งอาหาร แคมเปญ และการดูแลลูกค้า",
    href: "/food",
    icon: UtensilsCrossed,
    items: [
      { href: "/food", label: "ภาพรวม Food และร้าน", icon: LayoutDashboard, task: "WYN-203", feature: "Food overview" },
      { href: "/food/orders", label: "คำสั่งซื้อ", icon: ShoppingBag, task: "WYN-203", feature: "Food orders", roles: ["admin"] },
      { href: "/food/campaigns", label: "แคมเปญ", icon: Gift, task: "WYN-206", feature: "Food campaigns" },
      { href: "/food/coupons", label: "คูปอง", icon: TicketPercent, task: "WYN-206", feature: "Food coupons" },
      { href: "/food/notifications", label: "การแจ้งเตือน", icon: Bell, task: "FOOD-PROMO", feature: "Food notifications" },
      { href: "/food/ads", label: "โฆษณา", icon: Megaphone, task: "WYN-207", feature: "Food ads", roles: ["admin"] },
      { href: "/food/places", label: "สถานที่และแผนที่", icon: MapPinned, task: "WYNOS-PLACES", feature: "WYNOS Places" },
    ],
  },
  {
    id: "merchant",
    label: "WYNOS Merchant",
    shortLabel: "Merchant",
    domain: "merchant.wynos.online",
    description: "การสมัครและการกำกับดูแลร้านค้า",
    href: "/merchants",
    icon: Store,
    items: [
      { href: "/merchants", label: "คำขอเปิดร้าน", icon: ClipboardCheck, task: "MERCHANT", feature: "Merchant Application Review" },
    ],
  },
  {
    id: "central",
    label: "ระบบส่วนกลาง",
    shortLabel: "ส่วนกลาง",
    domain: "WYNOS Admin",
    description: "ประวัติการดำเนินงานของเจ้าหน้าที่",
    href: "/audit-log",
    icon: BookOpenText,
    items: [
      { href: "/audit-log", label: "ประวัติการดำเนินงาน", icon: ScrollText, task: "WYN-054", feature: "Audit Log" },
    ],
  },
];

/** Maintained for consumers that need a flat list of valid Admin destinations. */
export const ADMIN_NAV_ITEMS: AdminNavItem[] = ADMIN_WORKSPACES.flatMap((workspace) => [...workspace.items]);

export function isAdminNavActive(pathname: string, href: string) {
  return pathname === href || (href !== "/" && pathname.startsWith(href + "/"));
}

export function getAdminWorkspace(pathname: string): AdminWorkspace {
  const sortedItems = [...ADMIN_NAV_ITEMS].sort((left, right) => right.href.length - left.href.length);
  const match = sortedItems.find((item) => isAdminNavActive(pathname, item.href));
  return ADMIN_WORKSPACES.find((workspace) => workspace.items.some((item) => item.href === match?.href))
    ?? ADMIN_WORKSPACES[0];
}

export function getAdminCurrentItem(pathname: string): AdminNavItem | undefined {
  return [...ADMIN_NAV_ITEMS]
    .sort((left, right) => right.href.length - left.href.length)
    .find((item) => isAdminNavActive(pathname, item.href));
}

export function getAdminVisibleItems(workspace: AdminWorkspace, role: AdminRole): AdminNavItem[] {
  return workspace.items.filter((item) => !item.roles || item.roles.includes(role));
}
