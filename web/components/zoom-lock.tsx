"use client";

import { useEffect } from "react";

/**
 * iOS Safari ignores `user-scalable=no` for pinch zoom, so cancel its
 * page-zoom gesture events. Pointer events still fire, so in-app pinch
 * handlers (profile photo cropper) keep working. Double-tap zoom is
 * removed by `touch-action: manipulation` in globals.css.
 */
export function ZoomLock() {
  useEffect(() => {
    const cancel = (event: Event) => event.preventDefault();
    const types = ["gesturestart", "gesturechange", "gestureend"] as const;
    for (const type of types) document.addEventListener(type, cancel, { passive: false });
    return () => { for (const type of types) document.removeEventListener(type, cancel); };
  }, []);
  return null;
}
