/**
 * Shared links are mostly opened from chat/social apps, whose built-in
 * browsers keep their own cookies (so the visitor is signed out even when
 * Safari/Chrome is signed in) and are refused by Google OAuth
 * ("disallowed_useragent"). LINE is sent to the system browser by the
 * `openExternalBrowser` redirect in next.config.ts; the other apps have no
 * such switch, so the welcome screen asks the visitor to open the page in
 * their browser instead.
 */
export type InAppBrowser = "LINE" | "Facebook" | "Instagram" | "TikTok";

export function detectInAppBrowser(userAgent: string): InAppBrowser | null {
  if (/ Line\//.test(userAgent)) return "LINE";
  if (/Instagram/.test(userAgent)) return "Instagram";
  if (/FBAN|FBAV|FB_IAB|MessengerForiOS/.test(userAgent)) return "Facebook";
  if (/BytedanceWebview|musical_ly|TikTok/i.test(userAgent)) return "TikTok";
  return null;
}
