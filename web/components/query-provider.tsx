"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

/**
 * One QueryClient per browser session (not per render): a plain module-level
 * client would leak state across users on the server, so it's created lazily
 * inside useState instead. staleTime keeps repeat navigations (e.g. back to
 * a profile you already opened) from re-fetching immediately.
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
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
