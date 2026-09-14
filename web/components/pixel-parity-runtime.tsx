"use client";

import { useEffect } from "react";

/**
 * Tiny presentation-only bridge for values rendered by legacy route components
 * that cannot be expressed as CSS. Flutter Beta4 caps the Home chat badge at
 * 9+, while the migrated React component historically capped at 99+.
 *
 * This owns no data and performs no network writes; it only normalizes the
 * already-rendered badge label so the production pixels follow Flutter's
 * current contract until the legacy Home component is retired.
 */
export function PixelParityRuntime() {
  useEffect(() => {
    const sync = () => {
      document.querySelectorAll<HTMLElement>(".home-chat-badge").forEach((badge) => {
        const text = badge.textContent?.trim() ?? "";
        const count = Number.parseInt(text, 10);
        if (Number.isFinite(count) && count > 9 && text !== "9+") badge.textContent = "9+";
      });
    };

    sync();
    const observer = new MutationObserver(sync);
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    return () => observer.disconnect();
  }, []);

  return null;
}
