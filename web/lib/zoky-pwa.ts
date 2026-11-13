// ZOKY "add to home screen" card logic (customer web, zoky.wynos.online).
// Pure helpers so the decision rules can be unit tested without a browser.

export const ZOKY_INSTALL_DISMISS_KEY = "zoky-install-dismissed-at.v1";
export const ZOKY_INSTALL_COOLDOWN_MS = 7 * 24 * 60 * 60 * 1000;
export const ZOKY_INSTALL_SHOW_DELAY_MS = 0; // Founder 2026-11-12: show immediately
export const ZOKY_OPEN_URL = "https://zoky.wynos.online/";

/**
 * Vercel preview/deployment hosts of this team (*-warren14.vercel.app). The
 * install card also shows there so it can be tested on a phone before release.
 * It only controls whether the card shows: Food auth/origin rules keep using
 * isFoodAppHost, so previews are not treated as ZOKY origins anywhere else.
 */
export function isZokyPreviewHost(hostname: string): boolean {
  return /^[a-z0-9-]+-warren14\.vercel\.app$/i.test(hostname);
}

export type ZokyInstallMode = "android-prompt" | "android-manual" | "ios" | "open-browser" | "in-app-bar";

/** True when this page runs inside another page's frame (e.g. the WynChat mini app). */
export function isEmbeddedFrame(win: { top: unknown; self?: unknown } | null | undefined): boolean {
  if (!win) return false;
  try {
    return win.top !== (win.self ?? win);
  } catch {
    // A cross-origin top that cannot be read still means we are framed.
    return true;
  }
}

export function isIosDevice(userAgent: string, platform: string, touchPoints: number): boolean {
  if (/iphone|ipad|ipod/i.test(userAgent)) return true;
  // iPadOS Safari reports a desktop Mac UA but, unlike a Mac, has touch points.
  return platform === "MacIntel" && touchPoints > 1;
}

/**
 * What the card should offer, or null when it must stay hidden.
 * - standalone (already installed): never.
 * - inside Facebook/Messenger/LINE/etc. in-app browsers: a small top bar only
 *   (Founder 2026-11-13: the big card hid the menu and cannot install there).
 * - embedded: install and Push cannot work in a frame, so offer the browser.
 * - dismissed within the cooldown: hidden (the embedded card included).
 */
export function zokyInstallMode(state: {
  standalone: boolean;
  embedded: boolean;
  /** Facebook, Messenger, LINE, Instagram, TikTok in-app browser. */
  inApp?: boolean;
  ios: boolean;
  hasInstallEvent: boolean;
  dismissedAt: number | null;
  now: number;
}): ZokyInstallMode | null {
  if (state.standalone) return null;
  if (state.dismissedAt !== null && state.now - state.dismissedAt < ZOKY_INSTALL_COOLDOWN_MS) return null;
  if (state.inApp) return "in-app-bar";
  if (state.embedded) return "open-browser";
  if (state.ios) return "ios";
  return state.hasInstallEvent ? "android-prompt" : null;
}

export function readZokyDismissedAt(storage: Pick<Storage, "getItem"> | null | undefined): number | null {
  try {
    const raw = storage?.getItem(ZOKY_INSTALL_DISMISS_KEY);
    const value = raw ? Number(raw) : NaN;
    return Number.isFinite(value) ? value : null;
  } catch {
    return null;
  }
}

export function writeZokyDismissedAt(storage: Pick<Storage, "setItem"> | null | undefined, now: number): void {
  try {
    storage?.setItem(ZOKY_INSTALL_DISMISS_KEY, String(now));
  } catch {
    // Blocked storage (private mode): the card may simply come back next visit.
  }
}
