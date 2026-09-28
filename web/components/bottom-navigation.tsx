"use client";

import Link from "next/link";
import type { MouseEvent } from "react";

import { triggerRouteRefresh } from "@/components/route-refresh-runtime";

/**
 * Root bottom navigation shared by the top-level social routes.
 * The five existing destinations stay unchanged; the visual treatment is the
 * approved lightweight app dock with no selected background tile.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "compose";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  return (
    <span
      className={`route-nav-glyph route-nav-glyph--${kind}`}
      aria-hidden="true"
      data-selected={selected ? "true" : undefined}
    />
  );
}

export function BottomNavigation({
  profileHref,
  isActive,
  chatUnreadCount = 0,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  chatUnreadCount?: number;
}) {
  const homeActive = isActive("/");
  const clubActive = isActive("/clubs");
  const chatActive = isActive("/chat");
  const profileActive = isActive(profileHref);
  // A bottom-dock visit is the root profile; content links keep back navigation.
  const profileTabHref = `${profileHref}?from=tab`;

  const handleActiveTabTap = (active: boolean, path: string) => (event: MouseEvent<HTMLAnchorElement>) => {
    if (!active) return;
    if (window.location.pathname !== path || window.location.search || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const handleHomeClick = handleActiveTabTap(homeActive, "/");
  const handleProfileClick = (event: MouseEvent<HTMLAnchorElement>) => {
    // From a post/search, first switch to root Profile; re-taps refresh there.
    if (!profileActive || window.location.pathname !== profileHref ||
        window.location.search !== "?from=tab" || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${homeActive ? "active" : ""}`} href="/" aria-label="หน้าหลัก" onClick={handleHomeClick}>
        <MaterialNavGlyph kind="home" selected={homeActive} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${clubActive ? "active" : ""}`} href="/clubs" aria-label="คลับ" onClick={handleActiveTabTap(clubActive, "/clubs")}>
        <MaterialNavGlyph kind="club" selected={clubActive} />
        <span>คลับ</span>
      </Link>
      <Link
        className="route-nav-link route-nav-link--post"
        href="/?compose=1"
        aria-label="สร้างโพสต์ใหม่"
        onPointerDown={() => { void import("@/components/beta4-composer"); }}
      >
        <MaterialNavGlyph kind="compose" />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${chatActive ? "active" : ""}`} href="/chat" aria-label={chatUnreadCount > 0 ? `แชท มี ${chatUnreadCount} บทสนทนาที่ยังไม่อ่าน` : "แชท"} onClick={handleActiveTabTap(chatActive, "/chat")}>
        <span className="route-nav-icon-wrap">
          <MaterialNavGlyph kind="chat" selected={chatActive} />
          {chatUnreadCount > 0 ? <span className="route-nav-badge" aria-hidden="true">{chatUnreadCount > 9 ? "9+" : chatUnreadCount}</span> : null}
        </span>
        <span>แชท</span>
      </Link>
      <Link className={`route-nav-link ${profileActive ? "active" : ""}`} href={profileTabHref} aria-label="โปรไฟล์" onClick={handleProfileClick}>
        <MaterialNavGlyph kind="profile" selected={profileActive} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}
