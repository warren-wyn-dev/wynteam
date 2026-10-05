"use client";

import { BellRing } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { money, type FoodOrder } from "@/lib/food-merchant";
import { MERCHANT_ALERT_PREFS_EVENT, merchantAlertQuietNow, readMerchantAlertPreferences, type MerchantAlertPreferences } from "@/lib/merchant-notification-preferences";

/**
 * WYN-198: a loud, full-screen alert for orders that need the store now.
 * The sound (WYN-200, Wynos's own) repeats every ALERT_REPEAT_MS until the
 * store opens the order or the order is accepted (WYN-202: no time limit).
 */
const ALERT_REPEAT_MS = 2500;

type WebkitWindow = Window & { webkitAudioContext?: typeof AudioContext };

let sharedContext: AudioContext | null = null;

function audioContext(): AudioContext | null {
  if (typeof window === "undefined") return null;
  if (sharedContext) return sharedContext;
  const Context = window.AudioContext ?? (window as WebkitWindow).webkitAudioContext;
  if (!Context) return null;
  try {
    sharedContext = new Context();
  } catch {
    return null;
  }
  return sharedContext;
}

// WYN-200: Wynos's own order sound, synthesized by
// scripts/generate-merchant-order-sound.py (no third-party audio).
export const MERCHANT_ORDER_SOUND_URL = "/sounds/wynos-merchant-order.wav";
let orderSound: Promise<AudioBuffer | null> | null = null;

function loadOrderSound(context: AudioContext) {
  orderSound ??= fetch(MERCHANT_ORDER_SOUND_URL)
    .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject(new Error("sound"))))
    .then((bytes) => context.decodeAudioData(bytes))
    .catch(() => {
      orderSound = null; // try again next time
      return null;
    });
  return orderSound;
}

/** The old synthesized tones, used only if the sound file cannot load. */
function playFallbackTones(context: AudioContext) {
  const start = context.currentTime;
  [880, 1175, 880, 1175].forEach((frequency, index) => {
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    const at = start + index * 0.22;
    oscillator.type = "sine";
    oscillator.frequency.value = frequency;
    gain.gain.setValueAtTime(0.0001, at);
    gain.gain.exponentialRampToValueAtTime(0.35, at + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.2);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(at);
    oscillator.stop(at + 0.21);
  });
}

function playChime() {
  const context = audioContext();
  if (!context) return false;
  if (context.state !== "running") {
    // Phones suspend audio in the background; try to resume (may need a tap).
    void context.resume().catch(() => undefined);
    return false;
  }
  void loadOrderSound(context).then((buffer) => {
    if (!buffer) {
      playFallbackTones(context);
      return;
    }
    const source = context.createBufferSource();
    source.buffer = buffer;
    source.connect(context.destination);
    source.start();
  });
  return true;
}

/**
 * Play the order sound once from a tap (e.g. "ลองฟังเสียง"). The tap also
 * unlocks audio, so later alerts can ring on their own.
 */
export async function previewMerchantOrderSound() {
  const context = audioContext();
  if (!context) return false;
  try {
    await context.resume();
  } catch {
    return false;
  }
  return playChime();
}

/** Browsers only allow sound after a tap, so unlock audio on the first one. */
export function useMerchantSoundUnlock() {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    let watched: AudioContext | null = null;
    // Track the real state: the browser can suspend audio again (app sent to
    // the background), and then the alert must ask for a tap again.
    const sync = () => setReady(watched?.state === "running");
    const unlock = () => {
      const context = audioContext();
      if (!context) return;
      if (watched !== context) {
        watched?.removeEventListener("statechange", sync);
        watched = context;
        context.addEventListener("statechange", sync);
      }
      void context.resume().then(sync).catch(() => undefined);
    };
    window.addEventListener("pointerdown", unlock);
    window.addEventListener("keydown", unlock);
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
      watched?.removeEventListener("statechange", sync);
    };
  }, []);
  return ready;
}

export function NewOrderAlert({
  order,
  count,
  soundReady,
  onOpen,
}: {
  order: FoodOrder;
  /** How many orders are waiting in the alert queue, this one included. */
  count: number;
  soundReady: boolean;
  onOpen: () => void;
}) {
  const openRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const [alertPrefs, setAlertPrefs] = useState<MerchantAlertPreferences>(readMerchantAlertPreferences);

  // WYN-202 (Founder): it rings until the store opens the order or the order
  // is accepted, so there is no close button and Escape does nothing. Focus
  // stays inside; opening the order hands focus to the order sheet.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
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
  }, []);

  useEffect(() => {
    const syncPrefs = () => setAlertPrefs(readMerchantAlertPreferences());
    window.addEventListener(MERCHANT_ALERT_PREFS_EVENT, syncPrefs);
    window.addEventListener("storage", syncPrefs);
    return () => {
      window.removeEventListener(MERCHANT_ALERT_PREFS_EVENT, syncPrefs);
      window.removeEventListener("storage", syncPrefs);
    };
  }, []);

  useEffect(() => {
    openRef.current?.focus();
    const ring = () => {
      const prefs = readMerchantAlertPreferences();
      if (merchantAlertQuietNow(prefs)) return;
      if (prefs.sound_enabled) playChime();
      if (prefs.vibration_enabled && typeof navigator !== "undefined" && "vibrate" in navigator) {
        navigator.vibrate?.([300, 120, 300]);
      }
    };
    ring();
    // No time limit: rings until this alert unmounts (order opened or accepted).
    const timer = window.setInterval(ring, ALERT_REPEAT_MS);
    return () => window.clearInterval(timer);
  }, [order.id]);

  const items = order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0;
  const slipWaiting = order.payment_status === "submitted";

  return (
    <div ref={dialogRef} className="wm-alert-backdrop" role="alertdialog" aria-modal="true" aria-labelledby="wm-alert-title">
      <section className="wm-alert">
        <span className="wm-alert-icon"><BellRing size={34} /></span>
        <h2 id="wm-alert-title">{slipWaiting ? "ลูกค้าโอนเงินแล้ว" : "ออเดอร์ใหม่"}</h2>
        <strong className="wm-alert-number">#{order.order_number}</strong>
        <p>{`${order.recipient_name} · ${items} รายการ · ${money(order.total)}`}</p>
        {count > 1 ? <small>{`มีอีก ${count - 1} ออเดอร์รออยู่`}</small> : null}
        {alertPrefs.sound_enabled && !merchantAlertQuietNow(alertPrefs) && !soundReady ? <small>แตะที่หน้าจอหนึ่งครั้งเพื่อเปิดเสียงแจ้งเตือน</small> : null}
        {merchantAlertQuietNow(alertPrefs) ? <small>Quiet Hours เปิดอยู่ — ระบบยังแสดงออเดอร์ แต่ไม่ส่งเสียงหรือสั่น</small> : null}
        <button ref={openRef} className="wm-primary wm-full" type="button" onClick={onOpen}>
          {slipWaiting ? "ดูสลิปและรับออเดอร์" : "ดูออเดอร์"}
        </button>
      </section>
    </div>
  );
}
