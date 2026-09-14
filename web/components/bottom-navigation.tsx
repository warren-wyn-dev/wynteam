import { Bell, Home, Plus, Search, User } from "lucide-react";

import { WynosBottomNav, type WynosBottomNavItem } from "@/components/design-system/WynosBottomNav";

/**
 * Root bottom navigation, shared by every top-level route via <AppChrome>.
 *
 * WYN-159 design system, `WynosBottomNav` — reference is icon-only with a
 * Home/Clubs/Post-CTA/Chat/Profile layout, but per the app-shell/home doc's
 * "Design Rules — reconciling reference vs. existing product requirements"
 * the shipped 5 destinations (Home/Search/Post-CTA/Notifications/Profile)
 * and their labels are unchanged — Search and Notifications are real,
 * frequently-used top-level destinations today. Only the visual language
 * changes: monochrome icon coloring, 21px icons, circular black center CTA,
 * same hairline top border.
 */

type MaterialNavKind = "home" | "search" | "notifications" | "profile" | "add";

function NavGlyph({ kind }: { kind: MaterialNavKind }) {
  if (kind === "home") return <Home size={21} strokeWidth={1.75} />;
  if (kind === "search") return <Search size={21} strokeWidth={1.75} />;
  if (kind === "notifications") return <Bell size={21} strokeWidth={1.75} />;
  if (kind === "profile") return <User size={21} strokeWidth={1.75} />;
  return <Plus size={24} strokeWidth={2} />;
}

export function BottomNavigation({
  profileHref,
  isActive,
  notificationLabel,
  notificationBadge,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  notificationLabel: string;
  notificationBadge: string | null;
}) {
  const items: WynosBottomNavItem[] = [
    { key: "home", href: "/", ariaLabel: "หน้าหลัก", label: "หน้าหลัก", icon: <NavGlyph kind="home" />, active: isActive("/") },
    { key: "search", href: "/search", ariaLabel: "ค้นหา", label: "ค้นหา", icon: <NavGlyph kind="search" />, active: isActive("/search") },
    { key: "compose", href: "/?compose=1", ariaLabel: "สร้างโพสต์ใหม่", label: "โพสต์", icon: <NavGlyph kind="add" />, variant: "cta" },
    {
      key: "notifications",
      href: "/notifications",
      ariaLabel: notificationLabel,
      label: "การแจ้งเตือน",
      icon: <NavGlyph kind="notifications" />,
      active: isActive("/notifications"),
      badge: notificationBadge,
    },
    { key: "profile", href: profileHref, ariaLabel: "โปรไฟล์", label: "โปรไฟล์", icon: <NavGlyph kind="profile" />, active: isActive(profileHref) },
  ];

  return <WynosBottomNav items={items} />;
}
