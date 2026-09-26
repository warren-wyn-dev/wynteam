"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { usePublishBottomNav } from "@/components/app-bottom-nav-runtime";
import { GoldenDropCard } from "@/components/golden-drop-card";
import { QuoteFeedCard } from "@/components/quote-feed-card";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { DefaultProfileAvatar } from "@/components/ui/default-profile-avatar";
import { isQuotePost, type HomeFeedRow } from "@/lib/feed";
import type { HomeViewerState } from "@/lib/home-actions";
import { useUnreadNotificationCount } from "@/lib/notification-count";
import { scheduleAppRoutePrefetch } from "@/lib/app-prefetch";
import type { ProfileRow } from "@/lib/phase3-data";
import { usePresenceTracking } from "@/lib/presence";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

export function Avatar({ src, label, size = 42 }: { src?: string | null; label: string; size?: number }) {
  const [failedSrc, setFailedSrc] = useState<string | null>(null);
  if (!src || failedSrc === src) return <DefaultProfileAvatar className="route-avatar fallback" size={size} label={`รูปโปรไฟล์ของ ${label}`} />;
  return (
    <Image
      className="route-avatar"
      src={src}
      alt=""
      width={size}
      height={size}
      sizes={`${size}px`}
      onError={() => setFailedSrc(src)}
    />
  );
}

export function AppChrome({
  title,
  userId,
  backHref,
  onBack,
  actions,
  headerMode = "standard",
  showBottomNav,
  children,
}: {
  title: string;
  userId: string;
  backHref?: string;
  onBack?: () => void;
  actions?: React.ReactNode;
  headerMode?: "standard" | "hidden" | "overlay";
  showBottomNav?: boolean;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const primaryClubOrChatRoute = pathname === "/clubs" || pathname === "/chat";
  const inferredRootNav = pathname === "/" || primaryClubOrChatRoute || pathname === "/search" || pathname === "/notifications" || pathname.startsWith("/profile/");
  // Club and Chat are canonical root destinations in the latest navigation.
  // Keep their root pages anchored to the nav even if older route wrappers
  // explicitly opted out before those destinations existed in the bar.
  const bottomNavVisible = primaryClubOrChatRoute ? true : showBottomNav ?? inferredRootNav;
  const notificationRouteActive = pathname === "/notifications" || pathname.startsWith("/notifications/");

  useEffect(() => {
    // AppChrome is only rendered after a user passes the route Auth gate:
    // don't prefetch private pages from signed-out routes, or compete with
    // this page's first API requests. Next <Link> still warms visible tabs.
    return scheduleAppRoutePrefetch((href) => router.prefetch(href), userId, pathname);
  }, [router, userId, pathname]);

  usePresenceTracking(getSupabaseBrowserClient(), userId);
  const unreadNotificationCount = useUnreadNotificationCount(getSupabaseBrowserClient(), userId, bottomNavVisible && !notificationRouteActive);
  const visibleUnreadNotificationCount = notificationRouteActive ? 0 : unreadNotificationCount;
  const notificationLabel = visibleUnreadNotificationCount > 0
    ? `การแจ้งเตือน มี ${visibleUnreadNotificationCount} รายการที่ยังไม่อ่าน`
    : "การแจ้งเตือน";
  const notificationBadge = unreadNotificationCount > 9 ? "9+" : String(unreadNotificationCount);
  usePublishBottomNav(bottomNavVisible, userId, notificationLabel, visibleUnreadNotificationCount > 0 ? notificationBadge : null);
  const backIcon = <WynosIcon name="back" size={headerMode === "overlay" ? 32 : 24} strokeWidth={1.8} />;
  const backControl = onBack
    ? <button className="route-icon-link" type="button" aria-label="ย้อนกลับ" onClick={onBack}>{backIcon}</button>
    : backHref
    ? backHref === pathname
      // backHref matching the current pathname means this "back" isn't a
      // real route change (e.g. a caller toggling a local view without
      // navigating) — a same-URL <Link> click is a no-op in Next.js, so
      // this falls back to a hard reload rather than doing nothing.
      // Callers that can name the local state to undo should pass onBack
      // instead, which avoids the reload entirely.
      ? <button className="route-icon-link" type="button" aria-label="ย้อนกลับ" onClick={() => window.location.assign(backHref)}>{backIcon}</button>
      : <Link className="route-icon-link" href={backHref} aria-label="ย้อนกลับ">{backIcon}</Link>
    : <span className="route-header-slot" />;

  return (
    <div className={`route-app route-app-header-${headerMode} ${bottomNavVisible ? "route-with-bottom-nav" : "route-without-bottom-nav"}`}>
      <main className="route-main">
        {headerMode !== "hidden" ? <header className={`route-header route-header-${headerMode}`}><div className="route-title-row">{backControl}<h1>{title}</h1><div className="route-header-actions">{actions}</div></div></header> : null}
        {children}
      </main>
    </div>
  );
}

export function ProfileRowView({ profile, trailing }: { profile: ProfileRow; trailing?: React.ReactNode }) {
  const name = profile.display_name?.trim() || profile.username;
  return <div className="route-person-row"><Link href={`/profile/${profile.id}`} className="route-person-main"><Avatar src={profile.avatar_url} label={profile.username} /><span className="route-person-copy"><strong>{name}{profile.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}</strong><small>@{profile.username}</small></span></Link>{trailing}</div>;
}

export function DropPreviewCard({
  row,
  homeParity = false,
  viewerId = "",
  viewerSnapshot,
  onRepostChanged,
  onQuoteCreated,
  onQuoteDeleted,
  onQuoteRepostChanged,
}: {
  row: HomeFeedRow;
  homeParity?: boolean;
  viewerId?: string;
  viewerSnapshot?: HomeViewerState | null;
  onRepostChanged?: (actorId: string, dropId: string, removedStandard: boolean) => void;
  onQuoteCreated?: (actorId: string) => void;
  onQuoteDeleted?: (actorId: string, quoteId: string) => void;
  onQuoteRepostChanged?: (actorId: string, quoteId: string, removed: boolean) => void;
}) {
  if (isQuotePost(row)) {
    return <QuoteFeedCard row={row} viewerId={viewerId} initialQuoteState={viewerSnapshot?.quoteEngagementById?.get(row.redrop_id || "")} onQuoteRepostChanged={onQuoteRepostChanged} onDeleted={onQuoteDeleted} />;
  }
  return <GoldenDropCard row={row} homeParity={homeParity} initialViewer={viewerSnapshot} profileViewerId={viewerId} onRepostChanged={onRepostChanged} onQuoteCreated={onQuoteCreated} />;
}

export function SettingsLink() {
  return <Link className="route-icon-link" href="/settings" aria-label="ตั้งค่า"><WynosIcon name="settings" size={22} strokeWidth={2} /></Link>;
}

export function EmptyState({ children }: { children: React.ReactNode }) {
  return <div className="route-empty">{children}</div>;
}

export function LoadingState() {
  return <div className="route-empty"><div className="route-system-spinner" aria-label="กำลังโหลด" /></div>;
}
