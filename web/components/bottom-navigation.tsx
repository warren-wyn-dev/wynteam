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
  // WYNOS Web Beta 2: Founder-approved outline icon family.
  // Keep the same outline silhouette in both inactive and active states;
  // the parent tab handles active color/label emphasis.
  const strokeWidth = 2.05;
  const common = {
    className: "route-nav-glyph",
    viewBox: "0 0 24 24",
    "aria-hidden": true,
    fill: "none",
    stroke: "currentColor",
    strokeWidth,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "data-selected": selected ? "true" : undefined,
  };

  if (kind === "home") {
    return (
      <svg {...common}>
        <path d="M12 3.4 3.8 10.6v7.9A2.5 2.5 0 0 0 6.3 21h2.45v-5.35a3.25 3.25 0 0 1 6.5 0V21h2.45a2.5 2.5 0 0 0 2.5-2.5v-7.9L12 3.4Z" />
      </svg>
    );
  }

  if (kind === "club") {
    return (
      <svg {...common}>
        <circle cx="9" cy="7.2" r="3.35" />
        <circle cx="17.1" cy="8.15" r="2.45" />
        <path d="M3.45 20v-1.15a5.55 5.55 0 0 1 11.1 0V20" />
        <path d="M14.4 15.3a4.15 4.15 0 0 1 6.15 3.65V20" />
      </svg>
    );
  }

  if (kind === "chat") {
    return (
      <svg {...common}>
        <path d="M12 3.25c-5.18 0-9.2 3.55-9.2 8.05 0 2.17.92 4.15 2.45 5.58L4.4 21l4.28-1.68c1.02.34 2.14.53 3.32.53 5.18 0 9.2-3.55 9.2-8.05S17.18 3.25 12 3.25Z" />
        <circle cx="8.45" cy="11.55" r=".72" fill="currentColor" stroke="none" />
        <circle cx="12" cy="11.55" r=".72" fill="currentColor" stroke="none" />
        <circle cx="15.55" cy="11.55" r=".72" fill="currentColor" stroke="none" />
      </svg>
    );
  }

  if (kind === "profile") {
    return (
      <svg {...common}>
        <circle cx="12" cy="7.1" r="3.45" />
        <path d="M4.15 20.5v-.85a7.85 7.85 0 0 1 15.7 0v.85" />
      </svg>
    );
  }

  return (
    <svg {...common}>
      <path d="M13.2 4H7.1A3.1 3.1 0 0 0 4 7.1v9.8A3.1 3.1 0 0 0 7.1 20h9.8a3.1 3.1 0 0 0 3.1-3.1v-6.1" />
      <path d="m11.25 14.15.78-3.18 5.05-5.05a1.55 1.55 0 0 1 2.19 0l.81.81a1.55 1.55 0 0 1 0 2.19l-5.05 5.05-3.18.78.4-2.4 5.25-5.25" />
    </svg>
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
