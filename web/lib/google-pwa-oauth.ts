import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * iOS Home Screen PWAs do not share their auth storage with Safari. Starting
 * Google OAuth via an ordinary cross-scope redirect can open Safari View
 * Controller, which signs Safari in while leaving the installed app signed out.
 * Apple recommends window.open() to keep cross-origin OAuth within the PWA.
 *
 * This is invoked directly by a user gesture; open the blank window BEFORE
 * the asynchronous Supabase request, or iOS blocks it as a popup.
 */
export const GOOGLE_PWA_POPUP_MARKER = "wynos.google-pwa-popup-start.v1";
export const GOOGLE_PWA_COMPLETED_CHANNEL = "wynos.google-pwa-completed.v1";
const POPUP_VALIDITY_MS = 10 * 60 * 1000;

export function isInstalledIosWebApp(): boolean {
  if (typeof window === "undefined" || typeof navigator === "undefined") return false;
  const ios = /iPhone|iPad|iPod/i.test(navigator.userAgent)
    || (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  if (!ios) return false;
  const standalone = (navigator as Navigator & { standalone?: boolean }).standalone === true;
  return standalone || window.matchMedia("(display-mode: standalone)").matches;
}

export function consumeGooglePwaPopupMarker(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const started = Number(window.sessionStorage.getItem(GOOGLE_PWA_POPUP_MARKER));
    window.sessionStorage.removeItem(GOOGLE_PWA_POPUP_MARKER);
    return started > 0 && Date.now() - started < POPUP_VALIDITY_MS;
  } catch {
    return false;
  }
}

export function announceGooglePwaCompletion(): void {
  if (typeof window === "undefined") return;
  // No access/refresh tokens, profile details or OAuth codes leave this page.
  if (typeof BroadcastChannel !== "undefined") {
    const channel = new BroadcastChannel(GOOGLE_PWA_COMPLETED_CHANNEL);
    channel.postMessage({ type: "google-oauth-verified" });
    channel.close();
  }
  try {
    window.opener?.postMessage({ type: "google-oauth-verified" }, window.location.origin);
  } catch {
    // Cross-origin / COOP may sever the opener; BroadcastChannel remains
    // available inside the same installed-app storage partition.
  }
}

export async function startGoogleOAuth(
  client: SupabaseClient,
  browserRedirect: string,
  popupRedirectTo?: string,
): Promise<{ started: boolean; error?: string }> {
  const options = {
    redirectTo: browserRedirect,
    queryParams: { prompt: "select_account" },
  };
  if (!isInstalledIosWebApp()) {
    const { error } = await client.auth.signInWithOAuth({ provider: "google", options });
    return error
      ? { started: false, error: "เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่" }
      : { started: true };
  }

  // MUST happen synchronously before any await on iOS. Failure must never
  // silently fall back to an external Safari redirect (the reported bug).
  let popup: Window | null = null;
  try {
    popup = window.open("about:blank", "_blank");
  } catch {
    // Some browser privacy settings throw instead of returning null.
  }
  if (!popup) {
    return { started: false, error: "iPhone บล็อกหน้าต่าง Google กรุณาอนุญาตหน้าต่างใหม่แล้วลองอีกครั้ง" };
  }

  try {
    popup.sessionStorage.setItem(GOOGLE_PWA_POPUP_MARKER, String(Date.now()));
    popup.document.title = "กำลังเข้าสู่ระบบ Google — WYNOS";
    if (popup.document.body) popup.document.body.textContent = "กำลังเชื่อมต่อ Google…";
    const { data, error } = await client.auth.signInWithOAuth({
      provider: "google",
      options: {
        ...options,
        // Existing allowlisted callback; the OAuth verifier is stored in
        // THIS installed app, and the popup shares this app's cookie jar.
        redirectTo: popupRedirectTo
          ? (() => {
              const callback = new URL(popupRedirectTo, window.location.origin);
              if (callback.origin !== window.location.origin || callback.pathname !== "/auth/callback") {
                throw new Error("Untrusted Google callback");
              }
              return callback.href;
            })()
          : new URL("/auth/callback", window.location.origin).href,
        skipBrowserRedirect: true,
      },
    });
    if (error || !data?.url) throw new Error("OAuth URL unavailable");
    const oauth = new URL(data.url);
    const configured = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? window.location.origin);
    // The project's exact configured Auth origin is mandatory. The only
    // plaintext exception is a loopback Supabase mock in local browser QA.
    const loopback = ["localhost", "127.0.0.1"].includes(configured.hostname)
      && configured.protocol === "http:" && oauth.protocol === "http:";
    if ((!loopback && oauth.protocol !== "https:") || oauth.origin !== configured.origin) {
      throw new Error("Unexpected OAuth URL origin");
    }
    popup.location.replace(oauth.href);
    return { started: true };
  } catch {
    try { popup.close(); } catch { /* The popup may already be gone. */ }
    return {
      started: false,
      error: "เปิด Google ภายใน WYNOS ไม่สำเร็จ กรุณาลองใหม่ หรือเข้าใช้งานผ่าน Safari ชั่วคราว",
    };
  }
}
