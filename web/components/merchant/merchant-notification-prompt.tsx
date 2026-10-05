"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { BellRing, X } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

import { previewMerchantOrderSound } from "@/components/merchant/merchant-order-alert";
import {
  getPushAvailability,
  isCurrentDevicePushEnabled,
  isPushChosenOff,
  pushReasonDescription,
  subscribeToPushNotifications,
  type PushBlockReason,
} from "@/lib/push-notifications";

/**
 * WYN-199: Founder — "เวลากดเข้าไอคอน ควรถาม/ขออนุญาต เปิดการแจ้งเตือนทันที".
 * When Merchant opens and this device does not get order notifications yet,
 * ask right away. Browsers only show the permission dialog after a tap, so
 * this sheet's button is that tap. "ไว้ทีหลัง" hides it until the app is
 * opened again (per browser session); it is never shown once enabled.
 */
const LATER_KEY = "wynos.merchant.notify-later.v1";

type PromptState =
  | { kind: "ask" }
  | { kind: "blocked"; reason: PushBlockReason };

function laterThisSession() {
  try {
    return window.sessionStorage.getItem(LATER_KEY) === "1";
  } catch {
    return false;
  }
}

export function MerchantNotificationPrompt({
  client,
  userId,
  forceOpen,
  onClose,
  onEnabled,
}: {
  client: SupabaseClient;
  userId: string;
  /** Opened from the bell button: show even if "later" was chosen. */
  forceOpen: boolean;
  onClose: () => void;
  onEnabled: () => void;
}) {
  const [state, setState] = useState<PromptState | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const allowRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const close = useCallback(() => {
    try { window.sessionStorage.setItem(LATER_KEY, "1"); } catch { /* best effort */ }
    setState(null);
    onClose();
  }, [onClose]);

  useEffect(() => {
    let live = true;
    void (async () => {
      if (!forceOpen && (laterThisSession() || isPushChosenOff(userId))) return;
      const availability = await getPushAvailability();
      if (!live) return;
      if (!availability.available) {
        // Nothing the store can do here (no browser support or no server
        // config): do not nag. Denied / not installed get instructions.
        if (availability.reason === "denied" || availability.reason === "install-required" || forceOpen) {
          setState({ kind: "blocked", reason: availability.reason });
        }
        return;
      }
      const enabled = await isCurrentDevicePushEnabled(client, userId);
      if (!live) return;
      if (enabled === true) {
        onEnabled();
        if (forceOpen) onClose();
        return;
      }
      // null = could not check (offline): ask anyway, the button retries.
      setState({ kind: "ask" });
    })();
    return () => { live = false; };
    // Checked once per opening; callbacks are stable enough for that.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [client, userId, forceOpen]);

  useEffect(() => {
    if (state?.kind === "ask") allowRef.current?.focus();
  }, [state]);

  // Modal for keyboard users: Escape closes, Tab stays inside.
  useEffect(() => {
    if (!state) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        close();
        return;
      }
      if (event.key !== "Tab" || !dialogRef.current) return;
      const focusable = Array.from(dialogRef.current.querySelectorAll<HTMLElement>("button:not([disabled])"));
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      const inside = dialogRef.current.contains(document.activeElement);
      if (event.shiftKey && (document.activeElement === first || !inside)) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [state, close]);

  if (!state) return null;


  const allow = async () => {
    if (busy) return;
    setBusy(true);
    setError("");
    // The permission request is the first awaited browser call (iOS needs the tap).
    const result = await subscribeToPushNotifications(client, userId);
    setBusy(false);
    if (result.ok) {
      setState(null);
      onEnabled();
      onClose();
      return;
    }
    if (result.reason === "denied" || result.reason === "install-required") {
      setState({ kind: "blocked", reason: result.reason });
      return;
    }
    setError(pushReasonDescription(result.reason));
  };

  return (
    <div ref={dialogRef} className="wm-alert-backdrop" role="dialog" aria-modal="true" aria-labelledby="wm-notify-title">
      <section className="wm-alert wm-notify-prompt">
        <button className="wm-alert-close" type="button" aria-label="ปิด" onClick={close}><X size={22} /></button>
        <span className="wm-alert-icon"><BellRing size={34} /></span>
        <h2 id="wm-notify-title">เปิดการแจ้งเตือนออเดอร์</h2>
        {state.kind === "ask" ? (
          <>
            <p>ให้ Wynos Merchant แจ้งเตือนทันทีเมื่อมีออเดอร์ใหม่หรือลูกค้าส่งสลิป แม้ไม่ได้เปิดแอปอยู่</p>
            {error ? <small role="alert">{error}</small> : null}
            <button ref={allowRef} className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void allow()}>
              {busy ? "กำลังเปิด…" : "อนุญาตการแจ้งเตือน"}
            </button>
            <button className="wm-secondary wm-full" type="button" onClick={() => void previewMerchantOrderSound()}>ลองฟังเสียงแจ้งเตือน</button>
            <button className="wm-secondary wm-full" type="button" onClick={close}>ไว้ทีหลัง</button>
          </>
        ) : (
          <>
            <p>{state.reason === "denied"
              ? "มือถือปิดการแจ้งเตือนของแอปนี้อยู่ ไปที่การตั้งค่าของมือถือหรือเบราว์เซอร์ แล้วอนุญาตการแจ้งเตือนให้ Wynos Merchant จากนั้นเปิดแอปใหม่"
              : pushReasonDescription(state.reason)}</p>
            <button className="wm-secondary wm-full" type="button" onClick={close}>เข้าใจแล้ว</button>
          </>
        )}
      </section>
    </div>
  );
}
