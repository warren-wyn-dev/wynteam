"use client";

// ZOKY-LINE-002 (design A): "Sign in with LINE" for ZOKY customers, shown only
// inside the LINE client (LIFF). Rendered by FoodLoginScreen only when
// isLineLoginEnabled(). It never touches the guest basket or the pending
// LINE auto-link destination (zoky.line-autolink.v1): the login is a full-page
// redirect to the exact /food/auth/callback, and the existing
// takeLineAutoLink()/safeLineDestination() path restores the destination.
import { MessageCircle } from "lucide-react";
import { useEffect, useState, useSyncExternalStore } from "react";

import { loadLiff } from "@/components/food/line-login-guidance";
import { isInstalledIosWebApp } from "@/lib/google-pwa-oauth";
import { configuredLiffIds, isLineInAppBrowser, liffIdFor } from "@/lib/line-liff";

const noopSubscribe = () => () => {};
const readInLine = () => isLineInAppBrowser(navigator.userAgent);

type Slot = "pending" | "ready" | "unavailable";

export function LineLoginButton({
  busy,
  loading,
  error,
  onStart,
}: {
  busy: boolean;
  loading: boolean;
  error: string;
  onStart: () => void;
}) {
  // UA is known synchronously on the client (server snapshot is false, so
  // hydration stays consistent) which reserves the space in the first render.
  const inLine = useSyncExternalStore(noopSubscribe, readInLine, () => false);
  const [slot, setSlot] = useState<Slot>("pending");

  useEffect(() => {
    if (!inLine) return;
    let live = true;
    void (async () => {
      const liffId = liffIdFor("food", configuredLiffIds());
      if (!liffId || isInstalledIosWebApp()) { setSlot("unavailable"); return; }
      try {
        const liff = await loadLiff(liffId);
        if (live) setSlot(liff.isInClient() ? "ready" : "unavailable");
      } catch {
        if (live) setSlot("unavailable");
      }
    })();
    return () => { live = false; };
  }, [inLine]);

  if (!inLine) return null;
  return (
    <div className="wf-auth-line-login">
      {slot === "ready" ? (
        <>
          <button
            className="wf-auth-line-signin"
            type="button"
            disabled={busy}
            aria-busy={loading}
            aria-describedby="wf-auth-line-login-note"
            onClick={onStart}
          >
            {loading ? <span className="wf-mini-loader" aria-hidden="true" /> : <MessageCircle size={18} aria-hidden="true" />}
            {loading ? "กำลังเชื่อมต่อ LINE…" : "เข้าสู่ระบบด้วย LINE"}
          </button>
          <p className="wf-auth-line-login-note" id="wf-auth-line-login-note">
            LINE จะสร้างบัญชี ZOKY ใหม่ ถ้าเคยใช้ Google หรืออีเมลมาก่อน ให้เข้าด้วยวิธีเดิมเพื่อใช้บัญชีเดิมและประวัติออเดอร์
            {" "}
            ZOKY ไม่ขออีเมลของคุณจาก LINE
          </p>
          {error ? <p className="wf-auth-error" role="alert">{error}</p> : null}
        </>
      ) : null}
    </div>
  );
}
