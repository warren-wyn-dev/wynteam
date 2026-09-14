import { Home, MessageCircle, Plus, User, Users } from "lucide-react";

import { WynosBottomNav, type WynosBottomNavItem } from "@/components/design-system/WynosBottomNav";

/**
 * Root bottom navigation, shared by every top-level route via <AppChrome>.
 *
 * WYN-159 design system, `WynosBottomNav` — Founder reviewed a direct
 * side-by-side screenshot comparison against `wynos-home-v2.html` and
 * confirmed matching it 100% exactly, including navigation structure (see
 * `.wyn/company/DECISIONS.md`, entry dated 2026-09-14, "Founder ยืนยันให้
 * Bottom Nav/Header ตาม wynos-home-v2.html 100%"). This supersedes the
 * earlier decision (recorded here previously) to keep Search/Notifications
 * as bottom-nav destinations — they are still real, reachable routes, just
 * relocated: Search/Notifications now live in `HomeHeader`'s trailing
 * actions instead. Icon-only, no visible text labels, exactly 5 slots:
 * Home / Clubs / Post-CTA / Chat / Profile.
 */

type MaterialNavKind = "home" | "clubs" | "chat" | "profile" | "add";

function NavGlyph({ kind }: { kind: MaterialNavKind }) {
  if (kind === "home") return <Home size={21} strokeWidth={1.75} />;
  if (kind === "clubs") return <Users size={21} strokeWidth={1.75} />;
  if (kind === "chat") return <MessageCircle size={21} strokeWidth={1.75} />;
  if (kind === "profile") return <User size={21} strokeWidth={1.75} />;
  return <Plus size={24} strokeWidth={2} />;
}

export function BottomNavigation({
  profileHref,
  isActive,
  chatLabel,
  chatBadge,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  chatLabel: string;
  chatBadge: string | null;
}) {
  const items: WynosBottomNavItem[] = [
    { key: "home", href: "/", ariaLabel: "หน้าหลัก", icon: <NavGlyph kind="home" />, active: isActive("/") },
    { key: "clubs", href: "/clubs", ariaLabel: "คลับ", icon: <NavGlyph kind="clubs" />, active: isActive("/clubs") },
    { key: "compose", href: "/?compose=1", ariaLabel: "สร้างโพสต์ใหม่", icon: <NavGlyph kind="add" />, variant: "cta" },
    {
      key: "chat",
      href: "/chat",
      ariaLabel: chatLabel,
      icon: <NavGlyph kind="chat" />,
      active: isActive("/chat"),
      badge: chatBadge,
    },
    { key: "profile", href: profileHref, ariaLabel: "โปรไฟล์", icon: <NavGlyph kind="profile" />, active: isActive(profileHref) },
  ];

  return <WynosBottomNav items={items} />;
}
