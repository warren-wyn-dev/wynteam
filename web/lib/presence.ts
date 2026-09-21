import { useCallback, useEffect, useSyncExternalStore } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { fetchShowOnlineStatus } from "./phase3-data";

const PRESENCE_CHANNEL = "wynos:online-presence";

let channel: RealtimeChannel | null = null;
let channelClient: SupabaseClient | null = null;
let subscribed: Promise<void> | null = null;
let onlineIds: ReadonlySet<string> = new Set();
let startedForUserId: string | null = null;
const listeners = new Set<() => void>();

function notify() {
  for (const listener of listeners) listener();
}

function syncFromChannel(ch: RealtimeChannel) {
  onlineIds = new Set(Object.keys(ch.presenceState()));
  notify();
}

// One shared Presence channel per browser tab -- every screen that reads
// online status via useOnlineUserIds() sees the same set, keyed by user id
// (so "who's online" is just Object.keys(presenceState())) rather than each
// screen opening its own channel.
function ensureChannel(client: SupabaseClient, userId: string): { channel: RealtimeChannel; ready: Promise<void> } {
  if (channel && channelClient === client && subscribed) return { channel, ready: subscribed };
  channelClient = client;
  const ch = client.channel(PRESENCE_CHANNEL, { config: { presence: { key: userId } } });
  channel = ch;
  ch.on("presence", { event: "sync" }, () => syncFromChannel(ch));
  subscribed = new Promise<void>((resolve) => {
    ch.subscribe((status) => { if (status === "SUBSCRIBED") resolve(); });
  });
  return { channel: ch, ready: subscribed };
}

function startPresence(client: SupabaseClient, userId: string) {
  // Guards against re-tracking on every AppChrome remount (it mounts fresh
  // on each client-side navigation) -- this only actually does anything
  // once per tab session, not once per page. Doesn't handle a same-tab
  // account switch (the channel would stay keyed to the first user id);
  // fine for this app's session model, not worth the extra bookkeeping.
  if (startedForUserId === userId) return;
  startedForUserId = userId;
  const { channel: ch, ready } = ensureChannel(client, userId);

  const trackIfVisible = () => {
    if (document.visibilityState === "hidden") return;
    void fetchShowOnlineStatus(client, userId)
      .then((visible) => (visible ? ready.then(() => ch.track({ user_id: userId })) : undefined))
      .catch(() => undefined);
  };
  trackIfVisible();

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") void ch.untrack().catch(() => undefined);
    else trackIfVisible();
  });
  window.addEventListener("pagehide", () => void ch.untrack().catch(() => undefined));
}

/**
 * Mounted from inside AppChrome, so it runs on effectively every
 * authenticated screen -- the closest thing this app has to an app-shell
 * runtime without introducing a new global provider. Broadcasts the
 * current user's own online presence over a shared Supabase Realtime
 * Presence channel, gated by their existing show_online_status privacy
 * toggle (previously stored but never actually read anywhere -- this is
 * the first thing that does). A user who has it off simply never tracks,
 * so they never appear in anyone else's online-id set; no separate
 * client-side filtering needed to respect the setting.
 */
export function usePresenceTracking(client: SupabaseClient | null, userId: string): void {
  useEffect(() => {
    if (!client || !userId) return;
    startPresence(client, userId);
  }, [client, userId]);
}

/** Read-only: the current shared set of online user ids. No channel of its
 * own -- relies on usePresenceTracking already having been mounted
 * (via AppChrome) to establish the shared channel. */
export function useOnlineUserIds(): ReadonlySet<string> {
  const getSnapshot = useCallback(() => onlineIds, []);
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    getSnapshot,
    getSnapshot,
  );
}
