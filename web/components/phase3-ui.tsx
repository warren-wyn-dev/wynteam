"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft, Settings } from "lucide-react";
import { useEffect, useState } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { GoldenDropCard } from "@/components/golden-drop-card";
import type { HomeFeedRow } from "@/lib/feed";
import type { ProfileRow } from "@/lib/phase3-data";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type NotificationCountCacheEntry = { count: number; updatedAt: number };
const notificationCountCache = new Map<string, NotificationCountCacheEntry>();
const NOTIFICATION_CACHE_MS = 15_000;

export function Avatar({ src, label, size = 42 }: { src?: string | null; label: string; size?: number }) {
  const [failed, setFailed] = useState(false);
  const text = label.trim().replace(/^@/, "").slice(0, 1).toUpperCase() || "W";
  if (!src || failed) return <span className="route-avatar fallback" style={{ width: size, height: size }}>{text}</span>;
  return (
    <Image
      className="route-avatar"
      src={src}
      alt=""
      width={size}
      height={size}
      sizes={`${size}px`}
      onError={() => setFailed(true)}
    />
  );
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
  const router = useRouter();
  const cachedNotifications = notificationCountCache.get(userId);
  const [unreadNotificationCount, setUnreadNotificationCount] = useState(() => cachedNotifications?.count ?? 0);
  const primaryClubOrChatRoute = pathname === "/clubs" || pathname === "/chat";
  const inferredRootNav = pathname === "/" || primaryClubOrChatRoute || pathname === "/search" || pathname === "/notifications" || pathname.startsWith("/profile/");
  // Club and Chat are canonical root destinations in the latest navigation.
  // Keep their root pages anchored to the nav even if older route wrappers
  // explicitly opted out before those destinations existed in the bar.
  const bottomNavVisible = primaryClubOrChatRoute ? true : showBottomNav ?? inferredRootNav;
  const notificationRouteActive = pathname === "/notifications" || pathname.startsWith("/notifications/");
  const activeFor = (href: string) => href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);

  useEffect(() => {
    // The static root destinations are prefetched by AppNavigationRuntime.
    // Profile is user-specific, so warm it as soon as AppChrome knows the id.
    if (userId) router.prefetch(`/profile/${userId}`);
  }, [router, userId]);

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
      if (live && !result.error) {
        const count = result.count ?? 0;
        notificationCountCache.set(userId, { count, updatedAt: Date.now() });
        setUnreadNotificationCount(count);
      }
    };

    const cached = notificationCountCache.get(userId);
    if (!cached || Date.now() - cached.updatedAt >= NOTIFICATION_CACHE_MS) void load();

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
  const backIcon = <ChevronLeft size={headerMode === "overlay" ? 32 : 24} strokeWidth={1.8} />;
  const backControl = backHref
    ? backHref === pathname
      ? <button className="route-icon-link" type="button" aria-label="ย้อนกลับ" onClick={() => window.location.assign(backHref)}>{backIcon}</button>
      : <Link className="route-icon-link" href={backHref} aria-label="ย้อนกลับ">{backIcon}</Link>
    : <span className="route-header-slot" />;

  return (
    <div className={`route-app route-app-header-${headerMode} ${bottomNavVisible ? "route-with-bottom-nav" : "route-without-bottom-nav"}`}>
      <main className="route-main">
        {headerMode !== "hidden" ? <header className={`route-header route-header-${headerMode}`}><div className="route-title-row">{backControl}<h1>{title}</h1><div className="route-header-actions">{actions}</div></div></header> : null}
        {children}
      </main>
      {bottomNavVisible ? (
        <BottomNavigation
          profileHref={`/profile/${userId}`}
          isActive={activeFor}
          notificationLabel={notificationLabel}
          notificationBadge={visibleUnreadNotificationCount > 0 ? notificationBadge : null}
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
