"use client";

import { useEffect } from "react";

import { resyncPushRegistration } from "@/lib/push-notifications";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

/**
 * Keeps Push on for accounts that turned it on on this device: after a
 * token rotation, a token the server dropped, or switching back to the
 * account, the current token is registered again (once per page load).
 * Waits until the page is idle so it never competes with the first paint.
 */
export function PushResync() {
  useEffect(() => {
    const client = getSupabaseBrowserClient();
    if (!client) return;
    let timer: ReturnType<typeof setTimeout> | null = null;
    const { data } = client.auth.onAuthStateChange((_event, session) => {
      const userId = session?.user?.id;
      if (!userId) return;
      if (timer) clearTimeout(timer);
      // Outside the auth callback (supabase-js must not be awaited inside it) and after first paint.
      timer = setTimeout(() => void resyncPushRegistration(client, userId), 3000);
    });
    return () => {
      if (timer) clearTimeout(timer);
      data.subscription.unsubscribe();
    };
  }, []);
  return null;
}
