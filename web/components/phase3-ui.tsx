/* eslint-disable @next/next/no-img-element */
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronLeft, Settings } from "lucide-react";
import { useEffect, useState } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { GoldenDropCard } from "@/components/golden-drop-card";
import type { HomeFeedRow } from "@/lib/feed";
import { fetchHomeChatBadge } from "@/lib/home-parity-data";
import type { ProfileRow } from "@/lib/phase3-data";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

/**
 * Unread-notification badge, extracted so `HomeHeader`'s Bell action (which
 * moved here from the bottom nav's now-removed Notifications slot, per the
 * 2026-09-14 Founder-confirmed nav/header correction, see
 * `.wyn/company/DECISIONS.md`) can reuse the exact same fetch + formatting
 * logic `AppChrome` used to run for the bottom nav.
 */
export function useUnreadNotificationBadge(userId: string, active: boolean) {
  const pathname = usePathname();
  const [unreadNotificationCount, setUnreadNotificationCount] = useState(0);
  const notificationRouteActive = pathname === "/notifications" || pathname.startsWith("/notifications/");

  useEffect(() => {
    let live = true;
    if (!active || notificationRouteActive) return () => { live = false; };
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
  }, [active, notificationRouteActive, userId]);

  const visibleUnreadNotificationCount = notificationRouteActive ? 0 : unreadNotificationCount;
  const notificationLabel = visibleUnreadNotificationCount > 0
    ? `การแจ้งเตือน มี ${visibleUnreadNotificationCount} รายการที่ยังไม่อ่าน`
    : "การแจ้งเตือน";
  const notificationBadge = visibleUnreadNotificationCount > 0
    ? (unreadNotificationCount > 9 ? "9+" : String(unreadNotificationCount))
    : null;

  return { notificationBadge, notificationLabel };
}

export function Avatar({ src, label, size = 42 }: { src?: string | null; label: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  const text = label.trim().replace(/^@/, "").slice(0, 1).toUpperCase() || "W";
  if (!src || failed) return <span className="route-avatar fallback" style={{ width: size, height: size }}>{text}</span>;
  return <img className="route-avatar" src={src} alt="" width={size} height={size} onError={() => setFailed(true)} />;
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
  const [unreadChatCount, setUnreadChatCount] = useState(0);
  const inferredRootNav = pathname === "/" || pathname === "/search" || pathname === "/notifications" || pathname.startsWith("/profile/");
  const bottomNavVisible = showBottomNav ?? inferredRootNav;
  const chatRouteActive = pathname === "/chat" || pathname.startsWith("/chat/");
  const activeFor = (href: string) => href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);

  useEffect(() => {
    let live = true;
    if (!bottomNavVisible || chatRouteActive) return () => { live = false; };
    const client = getSupabaseBrowserClient();
    if (!client || !userId) return () => { live = false; };
    const load = async () => {
      try {
        const count = await fetchHomeChatBadge(client);
        if (live) setUnreadChatCount(count);
      } catch {
        // ignore — badge is non-critical, leave at previous/default value
      }
    };
    void load();
    const onFocus = () => void load();
    window.addEventListener("focus", onFocus);
    return () => {
      live = false;
      window.removeEventListener("focus", onFocus);
    };
  }, [bottomNavVisible, chatRouteActive, userId]);

  const visibleUnreadChatCount = chatRouteActive ? 0 : unreadChatCount;
  const chatLabel = visibleUnreadChatCount > 0
    ? `แชท มี ${visibleUnreadChatCount > 9 ? "9+" : visibleUnreadChatCount} ข้อความที่ยังไม่อ่าน`
    : "แชท";
  const chatBadge = visibleUnreadChatCount > 0 ? (visibleUnreadChatCount > 9 ? "9+" : String(visibleUnreadChatCount)) : null;

  return (
    <div className={`route-app route-app-header-${headerMode} ${bottomNavVisible ? "route-with-bottom-nav" : "route-without-bottom-nav"}`}>
      <main className="route-main">
        {headerMode !== "hidden" ? <header className={`route-header route-header-${headerMode}`}><div className="route-title-row">{backHref ? <Link className="route-icon-link" href={backHref} aria-label="ย้อนกลับ"><ChevronLeft size={headerMode === "overlay" ? 32 : 24} strokeWidth={1.8} /></Link> : <span className="route-header-slot" />}<h1>{title}</h1><div className="route-header-actions">{actions}</div></div></header> : null}
        {children}
      </main>
      {bottomNavVisible ? (
        <BottomNavigation
          profileHref={`/profile/${userId}`}
          isActive={activeFor}
          chatLabel={chatLabel}
          chatBadge={chatBadge}
        />
      ) : null}
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
