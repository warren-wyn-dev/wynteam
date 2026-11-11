"use client";

import { useEffect } from "react";

const WYNCHAT_ORIGIN = "https://wynchat.wynos.online";

// When Zoky is opened inside WynChat (a mini app in a sandboxed iframe), tell WynChat the page is ready so it does not offer
// the "open full screen" fallback. Does nothing in a normal browser tab. The message goes only to WynChat's own origin.
export function WynChatReady() {
  useEffect(() => {
    if (window.parent === window) return;
    try {
      window.parent.postMessage({ type: "wynchat:ready" }, WYNCHAT_ORIGIN);
    } catch {
      /* a parent that cannot be reached simply never hears it */
    }
  }, []);
  return null;
}
