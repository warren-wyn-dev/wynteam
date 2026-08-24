import {
  LayoutDashboard,
  Users,
  ShieldAlert,
  Flag,
  ScrollText,
  Megaphone,
  type LucideIcon,
} from "lucide-react";

export type AdminNavItem = {
  href: string;
  label: string;
  icon: LucideIcon;
  /** The task that will fill this page in -- shown on its placeholder. */
  task: string;
  feature: string;
};

/**
 * The 6 sections of WYN Admin, in the exact order the roadmap lists
 * Phase 7's tasks (.wyn/docs/product/wyn-v1.0.0-roadmap.md, WYN-050
 * through WYN-055). Every entry but Dashboard renders a placeholder
 * page until its own task lands -- see the Design spec's Screen 2.
 */
export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard, task: "WYN-050", feature: "Admin Dashboard" },
  { href: "/users", label: "User Management", icon: Users, task: "WYN-051", feature: "Admin User Management" },
  { href: "/moderation", label: "Content Moderation", icon: ShieldAlert, task: "WYN-052", feature: "Admin Content Moderation" },
  { href: "/reports", label: "Report Center", icon: Flag, task: "WYN-053", feature: "Admin Report Center" },
  { href: "/audit-log", label: "Audit Log", icon: ScrollText, task: "WYN-054", feature: "Audit Log" },
  { href: "/announcements", label: "Announcements", icon: Megaphone, task: "WYN-055", feature: "Official Announcements" },
];
