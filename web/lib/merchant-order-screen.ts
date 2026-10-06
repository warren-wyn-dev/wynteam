"use client";

import { useCallback, useEffect, useState, useSyncExternalStore } from "react";

/**
 * "หน้าจอรับออเดอร์" (Founder, 2026-10-06): a store leaves Merchant open at
 * the counter and the screen never sleeps, so the order sound (which phones
 * only play while the page is open) always rings. Uses the Screen Wake Lock
 * API; the browser drops the lock whenever the page is hidden, so it is taken
 * again each time Merchant comes back to the front.
 */
const KEY = "wynos.merchant.order-screen.v1";
const EVENT = "wynos:merchant-order-screen";

type WakeLockSentinelLike = { released: boolean; release: () => Promise<void>; addEventListener: (type: "release", listener: () => void) => void };
type WakeLockNavigator = Navigator & { wakeLock?: { request: (type: "screen") => Promise<WakeLockSentinelLike> } };

export function orderScreenSupported(): boolean {
  return typeof navigator !== "undefined" && Boolean((navigator as WakeLockNavigator).wakeLock?.request);
}

function readOn(): boolean {
  try { return window.localStorage.getItem(KEY) === "1"; } catch { return false; }
}

function writeOn(on: boolean) {
  try {
    if (on) window.localStorage.setItem(KEY, "1");
    else window.localStorage.removeItem(KEY);
  } catch { /* private mode: still works for this visit */ }
  window.dispatchEvent(new Event(EVENT));
}

function subscribe(onChange: () => void) {
  window.addEventListener(EVENT, onChange);
  window.addEventListener("storage", onChange);
  return () => {
    window.removeEventListener(EVENT, onChange);
    window.removeEventListener("storage", onChange);
  };
}

/** Whether the mode is on, whether the screen is actually being kept awake, and a setter. */
export function useMerchantOrderScreen() {
  // External stores: the saved choice, and browser support (false on the
  // server so the first client render matches it).
  const on = useSyncExternalStore(subscribe, readOn, () => false);
  const supported = useSyncExternalStore(subscribe, orderScreenSupported, () => false);
  const [locked, setAwake] = useState(false);

  useEffect(() => {
    if (!on || !supported) return;
    let sentinel: WakeLockSentinelLike | null = null;
    let live = true;
    const acquire = async () => {
      if (document.visibilityState !== "visible" || (sentinel && !sentinel.released)) return;
      try {
        const next = await (navigator as WakeLockNavigator).wakeLock!.request("screen");
        if (!live) {
          void next.release();
          return;
        }
        sentinel = next;
        setAwake(true);
        next.addEventListener("release", () => { if (live) setAwake(false); });
      } catch {
        // Low battery mode or a browser policy can refuse; the bar says so.
        setAwake(false);
      }
    };
    void acquire();
    const onVisible = () => { if (document.visibilityState === "visible") void acquire(); };
    // A refused or dropped lock is retried on the next tap as well.
    const onTap = () => { void acquire(); };
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("pointerdown", onTap);
    return () => {
      live = false;
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("pointerdown", onTap);
      if (sentinel && !sentinel.released) void sentinel.release().catch(() => undefined);
      setAwake(false);
    };
  }, [on, supported]);

  const setOn = useCallback((next: boolean) => writeOn(next), []);
  return { on, awake: on && supported && locked, supported, setOn };
}
