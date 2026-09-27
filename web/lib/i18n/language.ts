import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * WYN-189: Thai / English. Released to every account by the Founder
 * (2026-09-27).
 *
 * - First visit (nothing chosen on this device or account): follows the
 *   phone/browser language — English when it is not Thai.
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

/** The phone/browser language: Thai when any preferred language is Thai-first, otherwise English. */
export function deviceLanguage(languages: readonly string[] | undefined = typeof navigator === "undefined" ? undefined : navigator.languages): AppLanguage {
  const first = languages?.[0] ?? (typeof navigator === "undefined" ? "th" : navigator.language);
  if (!first) return "th";
  return /^th\b/i.test(first) ? "th" : "en";
}

export function readStoredLanguage(): AppLanguage | null {
  try {
    const value = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return isAppLanguage(value) ? value : null;
  } catch {
    return null;
  }
}

/** The language this page should show: the device's saved choice, else the phone's language. */
export function currentLanguage(): AppLanguage {
  return readStoredLanguage() ?? deviceLanguage();
}

/** Cache the choice on this device and tell listeners (the translator, Settings). */
export function setLanguage(language: AppLanguage) {
  try {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
  } catch {
    // Private mode / blocked storage: the choice still applies for this page.
  }
  window.dispatchEvent(new CustomEvent(LANGUAGE_CHANGE_EVENT, { detail: language }));
}

/**
 * Runs inline in <head> before first paint. For English it sets
 * `lang="en"` and `data-i18n-pending`, which hides the page (see
 * globals.css) until the translator has run, so Thai never flashes. A
 * safety timer shows the page regardless. Static string, no interpolated
 * input.
 */
export const LANGUAGE_BOOT_SCRIPT = `(function(){try{var l=null;try{l=localStorage.getItem(${JSON.stringify(
  LANGUAGE_STORAGE_KEY,
)})}catch(e){}if(l!=="th"&&l!=="en"){var n=(navigator.languages&&navigator.languages[0])||navigator.language||"th";l=/^th\\b/i.test(n)?"th":"en"}if(l==="en"){var r=document.documentElement;r.lang="en";r.setAttribute("data-i18n-pending","");setTimeout(function(){r.removeAttribute("data-i18n-pending")},2500)}}catch(e){}})();`;

/** The account's saved choice, or null when none is saved or it cannot be read. */
export async function loadAccountLanguage(client: SupabaseClient, userId: string): Promise<AppLanguage | null> {
  try {
    const { data, error } = await client.from("user_preferences").select("language_preference").eq("user_id", userId).maybeSingle();
    if (error || !data) return null;
    return isAppLanguage(data.language_preference) ? data.language_preference : null;
  } catch {
    return null;
  }
}

/** Save the choice to the account. Returns false if it could not be saved (it still applies on this device). */
export async function saveAccountLanguage(client: SupabaseClient, userId: string, language: AppLanguage): Promise<boolean> {
  try {
    const { error } = await client.from("user_preferences").upsert({ user_id: userId, language_preference: language }, { onConflict: "user_id" });
    return !error;
  } catch {
    return false;
  }
}
