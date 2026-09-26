import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * WYN-188: Light / Dark / System theme. Built in Web Beta2 and released to
 * every account by the Founder on 2026-09-27.
 *
 * How it applies:
 * - No choice stored (an account that never picked one): no `data-theme` on <html>. The
 *   legacy `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) … }`
 *   rules follow the phone, exactly as before WYN-188.
 * - A choice stored: `data-theme` is always set to the applied
 *   theme, "light" or "dark". "system" resolves from the phone and follows it
 *   live. New Beta2 dark-mode fixes are written only under
 *   `:where(:root[data-theme="dark"])`, so they only reach people who chose a theme.
 *
 * The choice is cached on the device (read before first paint by
 * THEME_BOOT_SCRIPT, so there is no flash) and saved per account in
 * `user_preferences.theme_preference`.
 */
export type ThemePreference = "system" | "light" | "dark";

export const THEME_STORAGE_KEY = "wynos.theme.v1";
export const THEME_CHANGE_EVENT = "wynos:theme-change";
export const THEME_PREFERENCES: readonly ThemePreference[] = ["system", "light", "dark"];

/** Browser/PWA chrome colour per applied theme; matches --wyn-bg. */
export const THEME_CHROME_COLOR = { light: "#ffffff", dark: "#000000" } as const;

export function isThemePreference(value: unknown): value is ThemePreference {
  return value === "system" || value === "light" || value === "dark";
}

export function readStoredThemePreference(): ThemePreference | null {
  try {
    const value = window.localStorage.getItem(THEME_STORAGE_KEY);
    return isThemePreference(value) ? value : null;
  } catch {
    return null;
  }
}

function writeStoredThemePreference(preference: ThemePreference | null) {
  try {
    if (preference) window.localStorage.setItem(THEME_STORAGE_KEY, preference);
    else window.localStorage.removeItem(THEME_STORAGE_KEY);
  } catch {
    // Private mode / blocked storage: the choice still applies for this page.
  }
}

/** Point every theme-color meta tag at the chosen theme (or back to the phone). */
function applyChromeColor(preference: ThemePreference | null) {
  const metas = document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]');
  metas.forEach((meta) => {
    if (!meta.dataset.wynMedia) meta.dataset.wynMedia = meta.getAttribute("media") ?? "";
    const media = meta.dataset.wynMedia;
    if (preference === "light" || preference === "dark") {
      meta.removeAttribute("media");
      meta.content = THEME_CHROME_COLOR[preference];
    } else {
      if (media) meta.setAttribute("media", media);
      meta.content = /dark/.test(media) ? THEME_CHROME_COLOR.dark : THEME_CHROME_COLOR.light;
    }
  });
}

const systemDarkQuery = () => window.matchMedia("(prefers-color-scheme: dark)");
let systemListener: ((event: MediaQueryListEvent) => void) | null = null;

function setAppliedTheme(theme: "light" | "dark") {
  const root = document.documentElement;
  root.dataset.theme = theme;
  root.style.colorScheme = theme;
}

/**
 * Apply a preference to the page. `null` (nothing chosen on this device or
 * account) removes the attribute so the legacy phone-following rules apply.
 */
export function applyThemePreference(preference: ThemePreference | null) {
  const root = document.documentElement;
  if (systemListener) {
    systemDarkQuery().removeEventListener("change", systemListener);
    systemListener = null;
  }
  if (preference === "light" || preference === "dark") {
    setAppliedTheme(preference);
  } else if (preference === "system") {
    setAppliedTheme(systemDarkQuery().matches ? "dark" : "light");
    systemListener = (event) => setAppliedTheme(event.matches ? "dark" : "light");
    systemDarkQuery().addEventListener("change", systemListener);
  } else {
    delete root.dataset.theme;
    root.style.removeProperty("color-scheme");
  }
  applyChromeColor(preference);
}

/** Apply, cache on this device, and tell listeners (other components). */
export function setThemePreference(preference: ThemePreference | null) {
  applyThemePreference(preference);
  writeStoredThemePreference(preference);
  window.dispatchEvent(new CustomEvent(THEME_CHANGE_EVENT, { detail: preference }));
}

/**
 * Runs inline in <head> before first paint. Kept tiny and dependency-free; a
 * static string with no interpolated input, so it is not an injection sink.
 */
export const THEME_BOOT_SCRIPT = `(function(){try{var p=localStorage.getItem(${JSON.stringify(
  THEME_STORAGE_KEY,
)});if(p==="system")p=matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";if(p==="light"||p==="dark"){var r=document.documentElement;r.setAttribute("data-theme",p);r.style.colorScheme=p;}}catch(e){}})();`;

/** The account's saved choice, or null when none is saved or it cannot be read. */
export async function loadAccountThemePreference(client: SupabaseClient, userId: string): Promise<ThemePreference | null> {
  try {
    const { data, error } = await client.from("user_preferences").select("theme_preference").eq("user_id", userId).maybeSingle();
    if (error || !data) return null;
    return isThemePreference(data.theme_preference) ? data.theme_preference : null;
  } catch {
    return null;
  }
}

/** Save the choice to the account. Returns false if it could not be saved (it still applies on this device). */
export async function saveAccountThemePreference(client: SupabaseClient, userId: string, preference: ThemePreference): Promise<boolean> {
  try {
    const { error } = await client.from("user_preferences").upsert({ user_id: userId, theme_preference: preference }, { onConflict: "user_id" });
    return !error;
  } catch {
    return false;
  }
}
