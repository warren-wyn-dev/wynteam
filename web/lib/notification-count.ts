import { useCallback, useEffect, useSyncExternalStore } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { getActiveAccountStorageKey } from "@/lib/account-registry";
import { emitNotificationChanges } from "@/lib/notification-events";

// The table's Postgres Changes publication is an independently reviewed
// DATABASE release. Until enabled, Push hints and visible-only polling keep
// the same browser experience usable without assuming a working WebSocket.
const CACHE_MS = 15_000;
const VISIBLE_POLL_MS = 12_000;
const ROUTE_GRACE_MS = 1_500;
const HINT_DEBOUNCE_MS = 120;
const PUSH_HINT_EVENT = "wynos:notification-push";
const BROADCAST_NAME = "wynos-notification-hints.v1";

type Entry = { count: number; updatedAt: number };
type Hint = { userId: string; kind: "new" | "sync" | "read"; notificationId?: string };

type Runtime = {
  client: SupabaseClient;
  userId: string;
  accountKey: string | null;
  refs: number;
  channel: RealtimeChannel | null;
  broadcast: BroadcastChannel | null;
  pollTimer: number | null;
  refreshTimer: number | null;
  closeTimer: number | null;
  inFlight: Promise<void> | null;
  needsRefresh: boolean;
  reading: boolean;
  revision: number;
  seen: Set<string>;
  teardown: () => void;
};

const counts = new Map<string, Entry>();
const listeners = new Set<() => void>();
const runtimes = new Map<string, Runtime>();

function notify(): void {
  listeners.forEach((listener) => listener());
}
function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
function setCount(userId: string, count: number): void {
  const next = Math.max(0, Math.floor(count));
  const previous = counts.get(userId);
  counts.set(userId, { count: next, updatedAt: Date.now() });
  if (previous?.count !== next) notify();
}

function current(runtime: Runtime): boolean {
  return runtimes.get(runtime.userId) === runtime &&
    runtime.accountKey === getActiveAccountStorageKey();
}

async function fetchUnreadCount(client: SupabaseClient, userId: string): Promise<number> {
  const result = await client
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("recipient_id", userId)
    .eq("is_read", false)
    // DM transport events belong to Chat and are deliberately absent from
    // the notification centre. Counting them created a permanent ghost badge.
    .neq("type", "new_message");
  if (result.error) throw result.error;
  return Math.max(0, result.count ?? 0);
}

/** A single in-flight unread request per account; discard older results when
 * an INSERT or read action occurs while the network request is outstanding. */
function refresh(runtime: Runtime): Promise<void> {
  if (!current(runtime) || runtime.reading || typeof navigator !== "undefined" && !navigator.onLine) {
    runtime.needsRefresh = true;
    return Promise.resolve();
  }
  if (runtime.inFlight) {
    runtime.needsRefresh = true;
    return runtime.inFlight;
  }
  const revision = runtime.revision;
  const promise = fetchUnreadCount(runtime.client, runtime.userId)
    .then((count) => {
      if (!current(runtime)) return;
      if (runtime.revision === revision && !runtime.reading) setCount(runtime.userId, count);
      else runtime.needsRefresh = true;
    })
    .catch(() => {
      // Keep last known count through flaky networks. Visibility/focus/Push
      // and the next poll all provide independent retry opportunities.
    })
    .finally(() => {
      runtime.inFlight = null;
      if (current(runtime) && runtime.needsRefresh && !runtime.reading) {
        runtime.needsRefresh = false;
        scheduleRefresh(runtime, HINT_DEBOUNCE_MS);
      }
    });
  runtime.inFlight = promise;
  return promise;
}

function scheduleRefresh(runtime: Runtime, delay = HINT_DEBOUNCE_MS): void {
  if (!current(runtime)) return;
  if (runtime.refreshTimer != null) window.clearTimeout(runtime.refreshTimer);
  runtime.refreshTimer = window.setTimeout(() => {
    runtime.refreshTimer = null;
    void refresh(runtime);
  }, delay);
}

function processHint(runtime: Runtime, kind: Hint["kind"], notificationId?: string, relay = true): void {
  if (!current(runtime)) return;
  if (kind === "new" && notificationId) {
    if (runtime.seen.has(notificationId)) return;
    runtime.seen.add(notificationId);
    if (runtime.seen.size > 128) runtime.seen.delete(runtime.seen.values().next().value!);
  }
  runtime.revision += 1;
  if (kind === "new" && counts.has(runtime.userId)) {
    setCount(runtime.userId, (counts.get(runtime.userId)?.count ?? 0) + 1);
  }
  emitNotificationChanges(runtime.userId);
  scheduleRefresh(runtime);
  // Other tabs receive only a per-account invalidation hint, never
  // notification text, actor details or FCM credentials.
  if (relay) {
    try { runtime.broadcast?.postMessage({ userId: runtime.userId, kind, notificationId } satisfies Hint); }
    catch { /* BroadcastChannel is optional on older PWA browsers. */ }
  }
}

function stop(runtime: Runtime): void {
  if (runtimes.get(runtime.userId) !== runtime) return;
  runtimes.delete(runtime.userId);
  runtime.teardown();
}

function start(client: SupabaseClient, userId: string): Runtime {
  const existing = runtimes.get(userId);
  if (existing && existing.client === client && current(existing)) {
    if (existing.closeTimer != null) {
      window.clearTimeout(existing.closeTimer);
      existing.closeTimer = null;
    }
    existing.refs += 1;
    return existing;
  }
  if (existing) stop(existing);

  const runtime: Runtime = {
    client, userId, accountKey: getActiveAccountStorageKey(), refs: 1,
    channel: null, broadcast: null, pollTimer: null, refreshTimer: null,
    closeTimer: null, inFlight: null, needsRefresh: false, reading: false,
    revision: 0, seen: new Set(), teardown: () => undefined,
  };
  runtimes.set(userId, runtime);

  const onFocus = () => {
    if (document.visibilityState !== "hidden" && current(runtime)) {
      scheduleRefresh(runtime, 0);
      emitNotificationChanges(runtime.userId); // repair missed events
    }
  };
  const onVisibility = () => { if (document.visibilityState === "visible") onFocus(); };
  const onPush = (event: Event) => {
    const detail = (event as CustomEvent<{
      recipientId?: string; notificationId?: string; type?: string;
    }>).detail;
    if (detail?.recipientId && detail.recipientId !== userId) return;
    if (detail?.type === "new_message") return; // Chat owns DM unread
    processHint(runtime, detail?.notificationId ? "new" : "sync", detail?.notificationId);
  };
  window.addEventListener("focus", onFocus);
  document.addEventListener("visibilitychange", onVisibility);
  window.addEventListener(PUSH_HINT_EVENT, onPush);

  if (typeof BroadcastChannel !== "undefined") {
    try {
      runtime.broadcast = new BroadcastChannel(BROADCAST_NAME);
      runtime.broadcast.onmessage = (event: MessageEvent<Hint>) => {
        const data = event.data;
        if (!data || data.userId !== userId || !current(runtime)) return;
        // Do not increment from a cross-tab hint: its exact count may
        // already be included in an older SQL result. Reconcile via RLS.
        runtime.revision += 1;
        emitNotificationChanges(userId);
        scheduleRefresh(runtime);
      };
    } catch { /* The authenticated page still has local refresh and focus. */ }
  }

  try {
    runtime.channel = client
      .channel(`wynos-notifications:${userId}`)
      .on("postgres_changes", {
        event: "INSERT", schema: "public", table: "notifications",
        filter: `recipient_id=eq.${userId}`,
      }, (payload) => {
        const next = payload.new as { id?: string; type?: string; is_read?: boolean; recipient_id?: string };
        if (next.recipient_id !== userId || next.type === "new_message" || next.is_read === true) return;
        processHint(runtime, "new", next.id);
      })
      .on("postgres_changes", {
        event: "UPDATE", schema: "public", table: "notifications",
        filter: `recipient_id=eq.${userId}`,
      }, (payload) => {
        const next = payload.new as { recipient_id?: string; type?: string };
        if (next.recipient_id === userId && next.type !== "new_message") processHint(runtime, "sync");
      })
      .subscribe((status) => {
        if (status === "SUBSCRIBED") scheduleRefresh(runtime, 0);
      });
  } catch {
    // A missing publication / failed WebSocket must never blank the badge.
    // Background Push and visible polling remain independent fallbacks.
  }

  runtime.pollTimer = window.setInterval(() => {
    if (document.visibilityState === "visible" && navigator.onLine && current(runtime)) {
      void refresh(runtime);
    }
  }, VISIBLE_POLL_MS);
  if (!counts.has(userId) || Date.now() - counts.get(userId)!.updatedAt >= CACHE_MS) {
    void refresh(runtime);
  }
  runtime.teardown = () => {
    window.removeEventListener("focus", onFocus);
    document.removeEventListener("visibilitychange", onVisibility);
    window.removeEventListener(PUSH_HINT_EVENT, onPush);
    if (runtime.pollTimer != null) window.clearInterval(runtime.pollTimer);
    if (runtime.refreshTimer != null) window.clearTimeout(runtime.refreshTimer);
    if (runtime.closeTimer != null) window.clearTimeout(runtime.closeTimer);
    try { runtime.broadcast?.close(); } catch { /* no-op */ }
    if (runtime.channel) void client.removeChannel(runtime.channel);
  };
  return runtime;
}

/** Clear immediately on opening the centre but hold network reconciliation
 * until its bounded server-side mark-read update finishes. */
export function markNotificationsRead(userId: string): void {
  const runtime = runtimes.get(userId);
  if (runtime && current(runtime)) {
    runtime.reading = true;
    runtime.revision += 1;
  }
  setCount(userId, 0);
}

export function settleNotificationsRead(client: SupabaseClient, userId: string): void {
  const runtime = runtimes.get(userId);
  if (runtime && runtime.client === client && current(runtime)) {
    runtime.reading = false;
    runtime.revision += 1;
    scheduleRefresh(runtime, 0);
    try { runtime.broadcast?.postMessage({ userId, kind: "read" } satisfies Hint); } catch { /* optional */ }
  } else {
    void fetchUnreadCount(client, userId).then((count) => setCount(userId, count)).catch(() => undefined);
  }
}

/** Root nav and Home may both mount this hook: share one active socket,
 * one badge request, and one visible-only fallback interval per account. */
export function useUnreadNotificationCount(
  client: SupabaseClient | null,
  userId: string,
  active: boolean,
): number {
  const getSnapshot = useCallback(() => counts.get(userId)?.count ?? 0, [userId]);
  const count = useSyncExternalStore(subscribe, getSnapshot, getSnapshot);

  useEffect(() => {
    if (!active || !client || !userId) return;
    const runtime = start(client, userId);
    return () => {
      runtime.refs = Math.max(0, runtime.refs - 1);
      if (runtime.refs === 0) {
        runtime.closeTimer = window.setTimeout(() => {
          if (runtime.refs === 0) stop(runtime);
        }, ROUTE_GRACE_MS);
      }
    };
  }, [client, userId, active]);

  return count;
}
