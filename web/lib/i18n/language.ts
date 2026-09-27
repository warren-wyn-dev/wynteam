import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * WYN-189: Thai / English. Released to every account by the Founder
 * (2026-09-27).
 *
 * - First visit (nothing chosen on this device or account): follows the
 *   phone/browser language — English for `en-*`, otherwise Thai.
 * - A choice is cached on the device (`wynos.lang.v1`, read before first
 *   paint by LANGUAGE_BOOT_SCRIPT) and saved per account in
 *   `user_preferences.language_preference`.
 *
 * The pages are written in Thai; English is applied on the client by
 * lib/i18n/translator.ts.
 */
export type AppLanguage = "th" | "en";

export const LANGUAGE_STORAGE_KEY = "wynos.lang.v1";
export const LANGUAGE_CHANGE_EVENT = "wynos:language-change";
export const APP_LANGUAGES: readonly AppLanguage[] = ["th", "en"];

export function isAppLanguage(value: unknown): value is AppLanguage {
  return value === "th" || value === "en";
}

/** The phone/browser language: English for `en-*`, Thai for every other language (spec). */
export function deviceLanguage(languages: readonly string[] | undefined = typeof navigator === "undefined" ? undefined : navigator.languages): AppLanguage {
  const first = languages?.[0] ?? (typeof navigator === "undefined" ? "th" : navigator.language);
  if (!first) return "th";
  return /^en\b/i.test(first) ? "en" : "th";
}

export function readStoredLanguage(): AppLanguage | null {
  try {
    const value = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return isAppLanguage(value) ? value : null;
  } catch {
    return null;
  }
}

// This page's choice, kept in memory too so it applies when storage is blocked.
let chosenThisPage: AppLanguage | null | undefined;

/** The choice in effect on this device/page, or null when none (follow the phone). */
export function chosenLanguage(): AppLanguage | null {
  return readStoredLanguage() ?? chosenThisPage ?? null;
}

/** The language this page should show: the choice, else the phone's language. */
export function currentLanguage(): AppLanguage {
  return chosenLanguage() ?? deviceLanguage();
}

/**
 * Cache the choice on this device (`null` forgets it: follow the phone) and
 * tell listeners (the translator, Settings).
 */
export function setLanguage(language: AppLanguage | null) {
  chosenThisPage = language;
  try {
    if (language) window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
    else window.localStorage.removeItem(LANGUAGE_STORAGE_KEY);
  } catch {
    // Private mode / blocked storage: the choice still applies for this page.
  }
  window.dispatchEvent(new CustomEvent(LANGUAGE_CHANGE_EVENT, { detail: language }));
}

/**
 * Runs inline in <head> before first paint. For English it sets
 * `lang="en"` and `data-i18n-pending`, which hides the page (see
 * globals.css) until the translator has run, so Thai never flashes. A
 * 6-second safety timer shows the page regardless, in case JavaScript never
 * runs; slow phones normally finish well before it. Static string, no
 * interpolated input.
 */
export const LANGUAGE_BOOT_SCRIPT = `(function(){try{var l=null;try{l=localStorage.getItem(${JSON.stringify(
  LANGUAGE_STORAGE_KEY,
)})}catch(e){}if(l!=="th"&&l!=="en"){var n=(navigator.languages&&navigator.languages[0])||navigator.language||"th";l=/^en\\b/i.test(n)?"en":"th"}if(l==="en"){var r=document.documentElement;r.lang="en";r.setAttribute("data-i18n-pending","");setTimeout(function(){r.removeAttribute("data-i18n-pending")},6000)}}catch(e){}})();`;

/**
 * The account's saved choice: the language, `null` when the account has
 * none, or `undefined` when it could not be read (keep the device's cache).
 */
export async function loadAccountLanguage(client: SupabaseClient, userId: string): Promise<AppLanguage | null | undefined> {
  try {
    const { data, error } = await client.from("user_preferences").select("language_preference").eq("user_id", userId).maybeSingle();
    if (error) return undefined;
    return isAppLanguage(data?.language_preference) ? data.language_preference : null;
  } catch {
    return undefined;
  }
}

// Saves run one after another, so quick taps end on the last choice.
let languageSaves: Promise<unknown> = Promise.resolve();

/** Save the choice to the account. Resolves false if it could not be saved (it still applies on this device). */
export function saveAccountLanguage(client: SupabaseClient, userId: string, language: AppLanguage): Promise<boolean> {
  const save = languageSaves.then(async () => {
    try {
      const { error } = await client.from("user_preferences").upsert({ user_id: userId, language_preference: language }, { onConflict: "user_id" });
      return !error;
    } catch {
      return false;
    }
  });
  languageSaves = save;
  return save;
}
