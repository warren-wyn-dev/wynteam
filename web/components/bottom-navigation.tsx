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
  // 2026-09-21 "Tab Bar A: เส้นบาง" redesign: a simpler, unified line-icon
  // set (matching the Lucide icon language the rest of the app already uses
  // via WynosIcon) replaces the previous bespoke glyphs. Only the chat icon
  // fills on selection now -- the others stay outline-only and rely on
  // color/weight (see bottom-nav.css) to signal the active tab.
  const strokeWidth = 1.7;

  if (kind === "home") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="m3 11 9-8 9 8" />
        <path d="M5 10v10h14V10" />
      </svg>
    );
  }

  if (kind === "club") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2" />
        <circle cx="10" cy="7" r="4" />
        <path d="M21 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </svg>
    );
  }

  if (kind === "chat") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill={selected ? "currentColor" : "none"} stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 2C6.48 2 2 5.94 2 10.8c0 2.77 1.46 5.24 3.75 6.86-.13 1.13-.5 2.36-1.32 3.62a.5.5 0 0 0 .58.75c1.9-.6 3.36-1.4 4.4-2.11.83.17 1.7.26 2.59.26 5.52 0 10-3.94 10-8.8S17.52 2 12 2Z" />
      </svg>
    );
  }

  if (kind === "profile") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21c0-4 4-6 8-6s8 2 8 6" />
      </svg>
    );
  }

  return (
    <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="9.5" />
      <path d="M12 7.5v9M7.5 12h9" />
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
