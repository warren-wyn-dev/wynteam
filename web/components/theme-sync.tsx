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
 * WYN-188: keeps the page theme in line with the signed-in account.
 * - Developer accounts: the account's saved choice wins and is cached on the device.
 * - Any other signed-in account: a choice cached by a previous developer on this
 *   device is cleared, so Web Beta1 users keep today's phone-following theme.
 * - Signed out: the device keeps its last choice (applied before paint by the
 *   boot script in app/layout.tsx).
 */
export function ThemeSync() {
  useEffect(() => {
    applyThemePreference(readStoredThemePreference());
    const client = getSupabaseBrowserClient();
    if (!client) return;
    let checkedFor: string | null = null;
    let live = true;
    const sync = async (userId: string) => {
      const { data: isDeveloper, error } = await client.rpc("is_developer_account");
      if (!live || checkedFor !== userId) return;
      if (error) return;
      if (isDeveloper !== true) {
        if (readStoredThemePreference()) setThemePreference(null);
        return;
      }
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
