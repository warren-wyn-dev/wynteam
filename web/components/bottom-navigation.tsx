"use client";

import Link from "next/link";
import type { MouseEvent } from "react";

/**
 * Root bottom navigation shared by the top-level social routes.
 *
 * The five destinations use one consistent outline icon system and equal
 * sizing. Selection is communicated by the soft background tile and darker
 * label/icon rather than by enlarging or filling a destination.
 */
type MaterialNavKind = "home" | "search" | "notification" | "profile" | "add";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  const strokeWidth = selected ? 2.05 : 1.9;

  if (kind === "home") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M3.5 10.5 12 3l8.5 7.5V20h-6v-6h-5v6h-6v-9.5Z" />
      </svg>
    );
  }

  if (kind === "search") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="10.5" cy="10.5" r="6.5" />
        <path d="M20 20l-4.6-4.6" />
      </svg>
    );
  }

  if (kind === "notification") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M6 9.5a6 6 0 1 1 12 0c0 4 1.5 5.5 2 6.5H4c.5-1 2-2.5 2-6.5Z" />
        <path d="M10 19.5a2 2 0 0 0 4 0" />
      </svg>
    );
  }

  if (kind === "profile") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="7.5" r="3.5" />
        <path d="M5 20c.45-4.05 2.85-6 7-6s6.55 1.95 7 6H5Z" />
      </svg>
    );
  }

  return (
    <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      <rect x="4" y="4" width="16" height="16" rx="4" />
      <path d="M12 8v8M8 12h8" />
    </svg>
  );
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
  const homeActive = isActive("/");
  const notificationsActive = isActive("/notifications");
  const handleHomeClick = (event: MouseEvent<HTMLAnchorElement>) => {
    if (!homeActive) return;
    // When Home is already selected, tapping its tab again acts like X/Instagram:
    // return to the top instead of navigating to the same route. Query/hash state
    // is allowed to navigate normally so e.g. an open composer still closes.
    if (window.location.pathname !== "/" || window.location.search || window.location.hash) return;
    event.preventDefault();
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${homeActive ? "active" : ""}`} href="/" aria-label="หน้าหลัก" onClick={handleHomeClick}>
        <MaterialNavGlyph kind="home" selected={homeActive} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/search") ? "active" : ""}`} href="/search" aria-label="ค้นหา">
        <MaterialNavGlyph kind="search" selected={isActive("/search")} />
        <span>ค้นหา</span>
      </Link>
      <Link className="route-nav-link" href="/?compose=1" aria-label="สร้างโพสต์ใหม่">
        <MaterialNavGlyph kind="add" />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${notificationsActive ? "active" : ""}`} href="/notifications" aria-label={notificationLabel}>
        <span className="route-nav-icon-wrap">
          <MaterialNavGlyph kind="notification" selected={notificationsActive} />
          {notificationBadge ? <span className="route-nav-badge">{notificationBadge}</span> : null}
        </span>
        <span>แจ้งเตือน</span>
      </Link>
      <Link className={`route-nav-link ${isActive(profileHref) ? "active" : ""}`} href={profileHref} aria-label="โปรไฟล์">
        <MaterialNavGlyph kind="profile" selected={isActive(profileHref)} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}
