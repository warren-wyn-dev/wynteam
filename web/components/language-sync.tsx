"use client";

import { useEffect } from "react";

import { applyLanguage } from "@/lib/i18n/translator";
import {
  currentLanguage,
  LANGUAGE_CHANGE_EVENT,
  LANGUAGE_STORAGE_KEY,
  loadAccountLanguage,
  readStoredLanguage,
  setLanguage,
} from "@/lib/i18n/language";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

/**
 * WYN-189 (released to every account, Founder 2026-09-27): shows the page in
 * the chosen language and keeps it in line with the signed-in account. The
 * account's saved choice wins and is cached on the device; with nothing
 * saved anywhere the phone's language is used. Runs after hydration so
 * React's server HTML (Thai) still matches.
 */
export function LanguageSync() {
  useEffect(() => {
    applyLanguage(currentLanguage());
    const onChange = () => applyLanguage(currentLanguage());
    const onStorage = (event: StorageEvent) => {
      if (event.key === LANGUAGE_STORAGE_KEY) onChange();
    };
    window.addEventListener(LANGUAGE_CHANGE_EVENT, onChange);
    window.addEventListener("storage", onStorage);

    const client = getSupabaseBrowserClient();
    let checkedFor: string | null = null;
    let live = true;
    const sync = async (userId: string) => {
      const saved = await loadAccountLanguage(client!, userId);
      if (!live || checkedFor !== userId) return;
      if (saved && saved !== readStoredLanguage()) setLanguage(saved);
    };
    const subscription = client?.auth.onAuthStateChange((_event, session) => {
      const userId = session?.user?.id ?? null;
      if (!userId || userId === checkedFor) {
        if (!userId) checkedFor = null;
        return;
      }
      checkedFor = userId;
      // Outside the auth callback: supabase-js must not be awaited inside it.
      setTimeout(() => void sync(userId), 0);
    }).data.subscription;
    return () => {
      live = false;
      subscription?.unsubscribe();
      window.removeEventListener(LANGUAGE_CHANGE_EVENT, onChange);
      window.removeEventListener("storage", onStorage);
    };
  }, []);
  return null;
}
