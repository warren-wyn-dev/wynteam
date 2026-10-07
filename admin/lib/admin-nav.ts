import {
  LayoutDashboard,
  Users,
  ShieldAlert,
  Flag,
  ScrollText,
  Megaphone,
  Store,
  UtensilsCrossed,
  BadgeDollarSign,
  WalletCards,
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
 * Core WYN Admin sections plus operational product surfaces.
 * The original Phase 7 routes remain in roadmap order; Merchant review
 * is an operational surface added for WYNOS Merchant applications.
 */
export const ADMIN_NAV_ITEMS: AdminNavItem[] = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard, task: "WYN-050", feature: "Admin Dashboard" },
  { href: "/users", label: "User Management", icon: Users, task: "WYN-051", feature: "Admin User Management" },
  { href: "/merchants", label: "Merchant Applications", icon: Store, task: "MERCHANT", feature: "Merchant Application Review" },
  { href: "/food", label: "Food Stores & Orders", icon: UtensilsCrossed, task: "WYN-203", feature: "WYNOS Food store operations" },
  { href: "/finance", label: "Finance / Platform Control", icon: BadgeDollarSign, task: "FINANCE", feature: "WYNOS Finance Control Center" },
  { href: "/finance", label: "Finance & Platform", icon: WalletCards, task: "FINANCE", feature: "WYNOS Finance & Platform Control" },
  { href: "/moderation", label: "Content Moderation", icon: ShieldAlert, task: "WYN-052", feature: "Admin Content Moderation" },
  { href: "/reports", label: "Report Center", icon: Flag, task: "WYN-053", feature: "Admin Report Center" },
  { href: "/audit-log", label: "Audit Log", icon: ScrollText, task: "WYN-054", feature: "Audit Log" },
  { href: "/announcements", label: "Announcements", icon: Megaphone, task: "WYN-055", feature: "Official Announcements" },
];
