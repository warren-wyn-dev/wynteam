"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createSyncStoragePersister } from "@tanstack/query-sync-storage-persister";
import { PersistQueryClientProvider } from "@tanstack/react-query-persist-client";
import { useEffect, useState } from "react";
import { subscribeFollowChange } from "@/lib/follow-state";
import { ACTIVE_ACCOUNT_STORAGE_KEY, getActiveAccountStorageKey } from "@/lib/account-registry";
import { PERSIST_QUERY_CACHE_KEY } from "@/lib/query-persist-key";

// One day: long enough that reopening the app later the same day still shows
// something instantly, short enough that genuinely stale data never lingers
// past a day of not opening the app before the network refetch replaces it.
const MAX_AGE = 24 * 60 * 60 * 1000;

/**
 * One QueryClient per browser session (not per render): a plain module-level
 * client would leak state across users on the server, so it's created lazily
 * inside useState instead. staleTime keeps repeat navigations (e.g. back to
 * a profile you already opened) from re-fetching immediately.
 *
 * Persisting the cache to localStorage means reopening the app (or the
 * installed home-screen icon) paints the last-seen feed/profile/chat data
 * immediately instead of a blank skeleton, while the network still refetches
 * in the background per the normal staleTime/refetchOnMount behaviour —
 * this is display-only, never a substitute for a real fetch.
 */
export function QueryProvider({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        refetchOnWindowFocus: false,
        retry: 1,
      },
    },
  }));
  const [persister] = useState(() =>
    typeof window === "undefined"
      ? null
      : createSyncStoragePersister({ storage: window.localStorage, key: PERSIST_QUERY_CACHE_KEY }),
  );

  useEffect(() => subscribeFollowChange(() => {
    // Counts and relationship state are shared across Search and Profile.
    void client.invalidateQueries({ queryKey: ["profile-summary"] });
  }), [client]);

  useEffect(() => {
    // Each tab has its own Supabase singleton and in-memory QueryClient.
    // A switch in another tab changes the shared active slot but cannot
    // replace this tab's already-created client. Reload promptly rather
    // than continuing to show account A while B is selected globally.
    const initialAccount = getActiveAccountStorageKey();
    const handleStorage = (event: StorageEvent) => {
      if (event.storageArea !== window.localStorage) return;
      if (event.key !== ACTIVE_ACCOUNT_STORAGE_KEY && event.key !== null) return;
      if (getActiveAccountStorageKey() === initialAccount) return;
      void client.cancelQueries();
      client.clear();
      window.location.reload();
    };
    window.addEventListener("storage", handleStorage);
    return () => window.removeEventListener("storage", handleStorage);
  }, [client]);

  // window.localStorage doesn't exist during SSR — fall back to a plain,
  // unpersisted provider so nested useQuery calls still have a QueryClient
  // in context for the server-rendered pass; the client re-render picks up
  // the persister once it mounts.
  if (!persister) return <QueryClientProvider client={client}>{children}</QueryClientProvider>;

  return (
    <PersistQueryClientProvider client={client} persistOptions={{ persister, maxAge: MAX_AGE }}>
      {children}
    </PersistQueryClientProvider>
  );
}
