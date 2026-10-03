"use client";

import { BellRing, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { money, type FoodOrder } from "@/lib/food-merchant";

/**
 * WYN-198: a loud, full-screen alert for orders that need the store now.
 * The sound is generated with Web Audio (no audio file) and repeats until the
 * store opens or dismisses the order, for at most ALERT_MAX_MS.
 */
const ALERT_REPEAT_MS = 2500;
const ALERT_MAX_MS = 3 * 60 * 1000;

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

function playChime() {
  const context = audioContext();
  if (!context || context.state !== "running") return false;
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
  return true;
}

/** Browsers only allow sound after a tap, so unlock audio on the first one. */
export function useMerchantSoundUnlock() {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    const unlock = () => {
      const context = audioContext();
      if (!context) return;
      void context.resume().then(() => setReady(context.state === "running")).catch(() => undefined);
    };
    window.addEventListener("pointerdown", unlock);
    window.addEventListener("keydown", unlock);
    return () => {
      window.removeEventListener("pointerdown", unlock);
      window.removeEventListener("keydown", unlock);
    };
  }, []);
  return ready;
}

export function NewOrderAlert({
  order,
  count,
  soundReady,
  onOpen,
  onDismiss,
}: {
  order: FoodOrder;
  /** How many orders are waiting in the alert queue, this one included. */
  count: number;
  soundReady: boolean;
  onOpen: () => void;
  onDismiss: () => void;
}) {
  const openRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const dismissRef = useRef(onDismiss);
  useEffect(() => { dismissRef.current = onDismiss; }, [onDismiss]);

  // Modal for keyboard users: focus stays inside, Escape closes, and focus
  // returns to where it was when the alert closes.
  useEffect(() => {
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        dismissRef.current();
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
    return () => {
      document.removeEventListener("keydown", onKey);
      if (previous?.isConnected) previous.focus();
    };
  }, []);

  useEffect(() => {
    openRef.current?.focus();
    const startedAt = Date.now();
    const ring = () => {
      playChime();
      if (typeof navigator !== "undefined" && "vibrate" in navigator) navigator.vibrate?.([300, 120, 300]);
    };
    ring();
    const timer = window.setInterval(() => {
      if (Date.now() - startedAt > ALERT_MAX_MS) {
        window.clearInterval(timer);
        return;
      }
      ring();
    }, ALERT_REPEAT_MS);
    return () => window.clearInterval(timer);
  }, [order.id]);

  const items = order.food_order_items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0;
  const slipWaiting = order.payment_status === "submitted";

  return (
    <div ref={dialogRef} className="wm-alert-backdrop" role="alertdialog" aria-modal="true" aria-labelledby="wm-alert-title">
      <section className="wm-alert">
        <button className="wm-alert-close" type="button" aria-label="ปิด" onClick={onDismiss}><X size={22} /></button>
        <span className="wm-alert-icon"><BellRing size={34} /></span>
        <h2 id="wm-alert-title">{slipWaiting ? "ลูกค้าโอนเงินแล้ว" : "ออเดอร์ใหม่"}</h2>
        <strong className="wm-alert-number">#{order.order_number}</strong>
        <p>{`${order.recipient_name} · ${items} รายการ · ${money(order.total)}`}</p>
        {count > 1 ? <small>{`มีอีก ${count - 1} ออเดอร์รออยู่`}</small> : null}
        {!soundReady ? <small>แตะที่หน้าจอหนึ่งครั้งเพื่อเปิดเสียงแจ้งเตือน</small> : null}
        <button ref={openRef} className="wm-primary wm-full" type="button" onClick={onOpen}>
          {slipWaiting ? "ดูสลิปและรับออเดอร์" : "ดูออเดอร์"}
        </button>
      </section>
    </div>
  );
}
