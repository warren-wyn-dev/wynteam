/* eslint-disable @next/next/no-img-element */
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronLeft, Settings } from "lucide-react";
import { useEffect, useState } from "react";

import { GoldenDropCard } from "@/components/golden-drop-card";
import type { HomeFeedRow } from "@/lib/feed";
import type { ProfileRow } from "@/lib/phase3-data";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

export function Avatar({ src, label, size = 42 }: { src?: string | null; label: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  const text = label.trim().replace(/^@/, "").slice(0, 1).toUpperCase() || "W";
  if (!src || failed) return <span className="route-avatar fallback" style={{ width: size, height: size }}>{text}</span>;
  return <img className="route-avatar" src={src} alt="" width={size} height={size} onError={() => setFailed(true)} />;
}

type MaterialNavKind = "home" | "search" | "notifications" | "profile" | "add";

function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  if (kind === "home") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8h5Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 5.69 17 10.19V18h-3v-6h-4v6H7v-7.81l5-4.5M12 3 2 12h3v8h7v-6h0v6h7v-8l-7-9Z" /></svg>
    );
  }
  if (kind === "search") {
    return <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M9.5 3a6.5 6.5 0 1 0 4.09 11.55L19 19.96 20.41 18.55 15 13.14A6.5 6.5 0 0 0 9.5 3Zm0 2A4.5 4.5 0 1 1 5 9.5 4.505 4.505 0 0 1 9.5 5Z" /></svg>;
  }
  if (kind === "notifications") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2Zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2Zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2Zm-2 .5H8V11c0-2.48 1.51-4.5 4-4.5s4 2.02 4 4.5v5.5Z" /></svg>
    );
  }
  if (kind === "profile") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0-6a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 8c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Zm-5.33 4c.73-1.02 3.3-2 5.33-2s4.6.98 5.33 2H6.67Z" /></svg>
    );
  }
  return <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>;
}

export function AppChrome({
  title,
  userId,
  backHref,
  actions,
  headerMode = "standard",
  showBottomNav,
  children,
}: {
  title: string;
  userId: string;
  backHref?: string;
  actions?: React.ReactNode;
  headerMode?: "standard" | "hidden" | "overlay";
  showBottomNav?: boolean;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const [unreadNotificationCount, setUnreadNotificationCount] = useState(0);
  const inferredRootNav = pathname === "/" || pathname === "/search" || pathname === "/notifications" || pathname.startsWith("/profile/");
  const bottomNavVisible = showBottomNav ?? inferredRootNav;
  const notificationRouteActive = pathname === "/notifications" || pathname.startsWith("/notifications/");
  const destinations = [
    { href: "/", label: "หน้าหลัก" },
    { href: "/search", label: "ค้นหา" },
    { href: "/notifications", label: "การแจ้งเตือน" },
    { href: `/profile/${userId}`, label: "โปรไฟล์" },
  ];
  const activeFor = (href: string) => href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);

  useEffect(() => {
    let live = true;
    if (!bottomNavVisible || notificationRouteActive) return () => { live = false; };
    const client = getSupabaseBrowserClient();
    if (!client || !userId) return () => { live = false; };
    const load = async () => {
      const result = await client
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("recipient_id", userId)
        .eq("is_read", false);
      if (live && !result.error) setUnreadNotificationCount(result.count ?? 0);
    };
    void load();
    const onFocus = () => void load();
    window.addEventListener("focus", onFocus);
    return () => {
      live = false;
      window.removeEventListener("focus", onFocus);
    };
  }, [bottomNavVisible, notificationRouteActive, userId]);

  const visibleUnreadNotificationCount = notificationRouteActive ? 0 : unreadNotificationCount;
  const notificationLabel = visibleUnreadNotificationCount > 0
    ? `การแจ้งเตือน มี ${visibleUnreadNotificationCount} รายการที่ยังไม่อ่าน`
    : "การแจ้งเตือน";
  const notificationBadge = unreadNotificationCount > 9 ? "9+" : String(unreadNotificationCount);

  return (
    <div className={`route-app route-app-header-${headerMode} ${bottomNavVisible ? "route-with-bottom-nav" : "route-without-bottom-nav"}`}>
      <main className="route-main">
        {headerMode !== "hidden" ? <header className={`route-header route-header-${headerMode}`}><div className="route-title-row">{backHref ? <Link className="route-icon-link" href={backHref} aria-label="ย้อนกลับ"><ChevronLeft size={headerMode === "overlay" ? 32 : 24} strokeWidth={1.8} /></Link> : <span className="route-header-slot" />}<h1>{title}</h1><div className="route-header-actions">{actions}</div></div></header> : null}
        {children}
      </main>
      {bottomNavVisible ? <nav className="route-bottom-nav" aria-label="เมนูหลัก">
        <Link className={`route-nav-link ${activeFor(destinations[0].href) ? "active" : ""}`} href="/" aria-label="หน้าหลัก"><MaterialNavGlyph kind="home" selected={activeFor("/")} /><span>หน้าหลัก</span></Link>
        <Link className={`route-nav-link ${activeFor(destinations[1].href) ? "active" : ""}`} href="/search" aria-label="ค้นหา"><MaterialNavGlyph kind="search" /><span>ค้นหา</span></Link>
        <Link className="route-nav-link route-create-destination" href="/?compose=1" aria-label="สร้างโพสต์ใหม่"><span className="route-create-button"><MaterialNavGlyph kind="add" /></span><span>โพสต์</span></Link>
        <Link className={`route-nav-link ${activeFor(destinations[2].href) ? "active" : ""}`} href="/notifications" aria-label={notificationLabel}><span className="route-nav-icon-wrap"><MaterialNavGlyph kind="notifications" selected={activeFor("/notifications")} />{visibleUnreadNotificationCount > 0 ? <span className="route-nav-badge" aria-hidden="true">{notificationBadge}</span> : null}</span><span>การแจ้งเตือน</span></Link>
        <Link className={`route-nav-link ${activeFor(destinations[3].href) ? "active" : ""}`} href={`/profile/${userId}`} aria-label="โปรไฟล์"><MaterialNavGlyph kind="profile" selected={activeFor(`/profile/${userId}`)} /><span>โปรไฟล์</span></Link>
      </nav> : null}
    </div>
  );
}

export function ProfileRowView({ profile, trailing }: { profile: ProfileRow; trailing?: React.ReactNode }) {
  const name = profile.display_name?.trim() || profile.username;
  return <div className="route-person-row"><Link href={`/profile/${profile.id}`} className="route-person-main"><Avatar src={profile.avatar_url} label={profile.username} /><span className="route-person-copy"><strong>{name}{profile.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}</strong><small>@{profile.username}</small></span></Link>{trailing}</div>;
}

export function DropPreviewCard({ row }: { row: HomeFeedRow }) {
  return <GoldenDropCard row={row} />;
}

export function SettingsLink() {
  return <Link className="route-icon-link" href="/settings" aria-label="ตั้งค่า"><Settings size={22} /></Link>;
}

export function EmptyState({ children }: { children: React.ReactNode }) {
  return <div className="route-empty">{children}</div>;
}

export function LoadingState() {
  return <div className="route-empty"><div className="route-system-spinner" aria-label="กำลังโหลด" /></div>;
}
