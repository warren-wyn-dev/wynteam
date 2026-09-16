import { useCallback, useEffect, useSyncExternalStore } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

const CACHE_MS = 15_000;
type Entry = { count: number; updatedAt: number };
const cache = new Map<string, Entry>();
const listeners = new Set<() => void>();

function notify() {
  listeners.forEach((listener) => listener());
}

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function setCount(userId: string, count: number) {
  cache.set(userId, { count, updatedAt: Date.now() });
  notify();
}

// Called once a user's notifications have been marked read (opening
// /notifications does this) so every mounted badge reading this store —
// the root nav and Home's bell alike — clears immediately instead of each
// waiting on its own next poll.
export function markNotificationsRead(userId: string) {
  setCount(userId, 0);
}

async function fetchUnreadCount(client: SupabaseClient, userId: string): Promise<number> {
  const result = await client
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("recipient_id", userId)
    .eq("is_read", false);
  return result.error ? cache.get(userId)?.count ?? 0 : Math.max(0, result.count ?? 0);
}

// Shared unread-notification count: polled at most once per CACHE_MS and on
// window focus, with every caller reading the same cached value so they all
// see the same count and all clear together on markNotificationsRead.
export function useUnreadNotificationCount(client: SupabaseClient | null, userId: string, active: boolean): number {
  const getSnapshot = useCallback(() => cache.get(userId)?.count ?? 0, [userId]);
  const count = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);

  useEffect(() => {
    if (!active || !client || !userId) return;
    let live = true;
    const load = async () => {
      const next = await fetchUnreadCount(client, userId);
      if (live) setCount(userId, next);
    };

    const cached = cache.get(userId);
    if (!cached || Date.now() - cached.updatedAt >= CACHE_MS) void load();

    const onFocus = () => void load();
    window.addEventListener("focus", onFocus);
    return () => {
      live = false;
      window.removeEventListener("focus", onFocus);
    };
  }, [client, userId, active]);

  return count;
}
