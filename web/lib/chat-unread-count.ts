import { useEffect, useSyncExternalStore } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { getActiveAccountStorageKey } from "@/lib/account-registry";

// Unread conversations for the Chat tab badge. The count comes from the
// same `count_unread_conversations()` RPC the Flutter app uses (auth.uid()
// scoped, respects chat lockdown), so web and app always agree.
const VISIBLE_POLL_MS = 15_000;
const HINT_DEBOUNCE_MS = 150;
const PUSH_HINT_EVENT = "wynos:notification-push";

const counts = new Map<string, number>();
// Latest request per account. Focus, Push, route changes and polling can
// overlap; only the newest response may set the badge, so an older read
// (taken before a message arrived or before mark-read) can't overwrite it.
const latestRequest = new Map<string, number>();
const listeners = new Set<() => void>();

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function setCount(userId: string, count: number): void {
  const next = Math.max(0, Math.floor(count));
  if (counts.get(userId) === next) return;
  counts.set(userId, next);
  listeners.forEach((listener) => listener());
}

export async function refreshUnreadChatCount(client: SupabaseClient, userId: string): Promise<void> {
  if (typeof navigator !== "undefined" && !navigator.onLine) return;
  // A request started before an account switch must not land on the new
  // account's badge (or on the old account's cached value).
  const accountKey = getActiveAccountStorageKey();
  const request = (latestRequest.get(userId) ?? 0) + 1;
  latestRequest.set(userId, request);
  try {
    const { data, error } = await client.rpc("count_unread_conversations");
    if (latestRequest.get(userId) !== request) return;
    if (error || getActiveAccountStorageKey() !== accountKey) return;
    setCount(userId, typeof data === "number" ? data : Number(data) || 0);
  } catch {
    // Keep the last known count; focus, Push and polling retry.
  }
}

/** Chat tab badge. `refreshKey` (e.g. the pathname) re-reads the count when
 * the user leaves a conversation, so a thread just read clears at once. */
export function useUnreadChatCount(
  client: SupabaseClient | null,
  userId: string,
  refreshKey: string,
): number {
  const count = useSyncExternalStore(
    subscribe,
    () => counts.get(userId) ?? 0,
    () => 0,
  );

  useEffect(() => {
    if (!client || !userId) return;
    let timer: number | null = null;
    const schedule = (delay = HINT_DEBOUNCE_MS) => {
      if (timer != null) window.clearTimeout(timer);
      timer = window.setTimeout(() => { timer = null; void refreshUnreadChatCount(client, userId); }, delay);
    };
    const onVisible = () => { if (document.visibilityState === "visible") schedule(0); };
    const onPush = (event: Event) => {
      const detail = (event as CustomEvent<{ recipientId?: string; type?: string }>).detail;
      if (detail?.recipientId && detail.recipientId !== userId) return;
      if (!detail?.type || detail.type === "new_message" || detail.type === "message_request") schedule();
    };
    const poll = window.setInterval(() => {
      if (document.visibilityState === "visible") void refreshUnreadChatCount(client, userId);
    }, VISIBLE_POLL_MS);
    window.addEventListener("focus", onVisible);
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener(PUSH_HINT_EVENT, onPush);
    // Short delay lets a conversation's own mark-read request land first.
    schedule();
    return () => {
      if (timer != null) window.clearTimeout(timer);
      window.clearInterval(poll);
      window.removeEventListener("focus", onVisible);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener(PUSH_HINT_EVENT, onPush);
    };
  }, [client, userId, refreshKey]);

  return count;
}
