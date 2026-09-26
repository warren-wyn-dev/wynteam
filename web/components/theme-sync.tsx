"use client";

import { useEffect } from "react";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  applyThemePreference,
  loadAccountThemePreference,
  readStoredThemePreference,
  setThemePreference,
} from "@/lib/theme-preference";

/**
 * WYN-188 (released to every account, Founder 2026-09-27): keeps the page
 * theme in line with the signed-in account. The account's saved choice
 * wins and is cached on the device; when signed out the device keeps its
 * last choice (applied before paint by the boot script in app/layout.tsx).
 * An account that never chose keeps today's phone-following behaviour.
 */
export function ThemeSync() {
  useEffect(() => {
    applyThemePreference(readStoredThemePreference());
    const client = getSupabaseBrowserClient();
    if (!client) return;
    let checkedFor: string | null = null;
    let live = true;
    const sync = async (userId: string) => {
      const saved = await loadAccountThemePreference(client, userId);
      if (!live || checkedFor !== userId) return;
      if (saved && saved !== readStoredThemePreference()) setThemePreference(saved);
    };
    const { data } = client.auth.onAuthStateChange((_event, session) => {
      const userId = session?.user?.id ?? null;
      if (!userId || userId === checkedFor) {
        if (!userId) checkedFor = null;
        return;
      }
      checkedFor = userId;
      // Outside the auth callback: supabase-js must not be awaited inside it.
      setTimeout(() => void sync(userId), 0);
    });
    return () => {
      live = false;
      data.subscription.unsubscribe();
    };
  }, []);
  return null;
}
