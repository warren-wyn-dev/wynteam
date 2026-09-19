"use client";

import Link from "next/link";
import type { MouseEvent } from "react";

import { triggerRouteRefresh } from "@/components/route-refresh-runtime";

/**
 * Root bottom navigation shared by the top-level social routes.
 * The five existing destinations stay unchanged; the visual treatment is the
 * approved lightweight app dock with no selected background tile.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "add";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  const strokeWidth = selected ? 2.15 : 1.9;

  if (kind === "home") {
    return (
      <svg
        className="route-nav-glyph"
        viewBox="0 0 24 24"
        aria-hidden="true"
        fill={selected ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M3.5 10.5 12 3l8.5 7.5V20h-6v-6h-5v6h-6v-9.5Z" />
      </svg>
    );
  }

  if (kind === "club") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="8.5" cy="8" r="2.6" />
        <circle cx="15.5" cy="8" r="2.6" />
        <circle cx="12" cy="5.7" r="2.2" />
        <path d="M3.3 19c.4-3.5 2.35-5.2 5.2-5.2s4.8 1.7 5.2 5.2" />
        <path d="M10.3 19c.4-3.5 2.35-5.2 5.2-5.2s4.8 1.7 5.2 5.2" />
      </svg>
    );
  }

  if (kind === "chat") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 4.5c4.42 0 7.5 2.84 7.5 6.5 0 3.66-3.08 6.5-7.5 6.5-.86 0-1.68-.11-2.44-.31L5.5 19.5l1.1-3.38C5.06 14.87 4.5 13.15 4.5 11c0-3.66 3.08-6.5 7.5-6.5Z" />
        <circle cx="8.7" cy="11" r="1.05" fill="currentColor" stroke="none" />
        <circle cx="12" cy="11" r="1.05" fill="currentColor" stroke="none" />
        <circle cx="15.3" cy="11" r="1.05" fill="currentColor" stroke="none" />
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
      <circle cx="12" cy="12" r="8.25" />
      <path d="M12 8v8M8 12h8" />
    </svg>
  );
}

export function BottomNavigation({
  profileHref,
  isActive,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
}) {
  const homeActive = isActive("/");
  const profileActive = isActive(profileHref);

  const handleActiveTabTap = (active: boolean, path: string) => (event: MouseEvent<HTMLAnchorElement>) => {
    if (!active) return;
    if (window.location.pathname !== path || window.location.search || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const handleHomeClick = handleActiveTabTap(homeActive, "/");
  const handleProfileClick = handleActiveTabTap(profileActive, profileHref);

  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${homeActive ? "active" : ""}`} href="/" aria-label="หน้าหลัก" onClick={handleHomeClick}>
        <MaterialNavGlyph kind="home" selected={homeActive} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/clubs") ? "active" : ""}`} href="/clubs" aria-label="คลับ">
        <MaterialNavGlyph kind="club" selected={isActive("/clubs")} />
        <span>คลับ</span>
      </Link>
      <Link
        className="route-nav-link"
        href="/?compose=1"
        aria-label="สร้างโพสต์ใหม่"
        onPointerDown={() => { void import("@/components/beta4-composer"); }}
      >
        <MaterialNavGlyph kind="add" />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/chat") ? "active" : ""}`} href="/chat" aria-label="แชท">
        <MaterialNavGlyph kind="chat" selected={isActive("/chat")} />
        <span>แชท</span>
      </Link>
      <Link className={`route-nav-link ${profileActive ? "active" : ""}`} href={profileHref} aria-label="โปรไฟล์" onClick={handleProfileClick}>
        <MaterialNavGlyph kind="profile" selected={profileActive} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}
