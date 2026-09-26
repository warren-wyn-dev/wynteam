"use client";

import { usePathname } from "next/navigation";
import { useLayoutEffect, useSyncExternalStore } from "react";

import { BottomNavigation } from "@/components/bottom-navigation";
import { useUnreadChatCount } from "@/lib/chat-unread-count";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type BottomNavState = {
  visible: boolean;
  userId: string;
  notificationLabel: string;
  notificationBadge: string | null;
} | null;

let state: BottomNavState = null;
const listeners = new Set<() => void>();

function publish(next: BottomNavState) {
  state = next;
  listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot() {
  return state;
}

/**
 * Lets each page's AppChrome (components/phase3-ui.tsx) publish what the
 * persistent bottom nav — rendered once in the root layout by
 * AppBottomNavHost below, not remounted per page — should show right now.
 *
 * useLayoutEffect, not useEffect: it commits before paint, so the nav
 * updates in the same frame a new page mounts instead of one frame behind
 * (visible as the nav popping between states on every navigation).
 *
 * No cleanup on unmount: the whole point is that the nav keeps showing
 * whatever the last-mounted page published — including through the moment
 * that page unmounts during a route change — until the next page publishes
 * its own state. Resetting on unmount would reintroduce exactly the
 * flash-to-hidden this exists to avoid.
 */
export function usePublishBottomNav(visible: boolean, userId: string, notificationLabel: string, notificationBadge: string | null) {
  useLayoutEffect(() => {
    publish({ visible, userId, notificationLabel, notificationBadge });
  }, [visible, userId, notificationLabel, notificationBadge]);
}

export function AppBottomNavHost() {
  const navState = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);
  const pathname = usePathname();
  const userId = navState?.userId ?? "";
  const chatUnreadCount = useUnreadChatCount(userId ? getSupabaseBrowserClient() : null, userId, pathname);
  if (!navState?.visible || !navState.userId) return null;

  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`));

  return (
    <BottomNavigation
      profileHref={`/profile/${navState.userId}`}
      isActive={isActive}
      chatUnreadCount={chatUnreadCount}
    />
  );
}
