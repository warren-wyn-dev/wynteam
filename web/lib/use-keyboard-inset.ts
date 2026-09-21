"use client";

import { useEffect } from "react";

/**
 * Tracks how much the on-screen keyboard overlaps the bottom of the layout
 * viewport and publishes it as `--wyn-kb-inset` on <html>, plus a
 * `data-keyboard-open` attribute while the keyboard is open.
 *
 * Most of the time `interactiveWidget: "resizes-content"` (see
 * app/layout.tsx) already shrinks the layout viewport for us, so this comes
 * out to 0 and is a no-op. It only does real work as a fallback where that
 * isn't honored (older iOS, in-app webviews, some standalone-PWA cases),
 * where the visual viewport shrinks but the layout viewport does not.
 */
export function useKeyboardInset() {
  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;
    const root = document.documentElement;
    let raf = 0;
    const update = () => {
      raf = 0;
      const inset = Math.max(0, window.innerHeight - vv.height - vv.offsetTop);
      // Ignore sub-pixel noise so we don't flip data-keyboard-open off by a
      // rounding error while the keyboard is fully open.
      const rounded = Math.round(inset);
      root.style.setProperty("--wyn-kb-inset", `${rounded}px`);
      if (rounded > 40) root.setAttribute("data-keyboard-open", "true");
      else root.removeAttribute("data-keyboard-open");
    };
    const schedule = () => {
      if (raf) return;
      raf = requestAnimationFrame(update);
    };
    schedule();
    vv.addEventListener("resize", schedule);
    vv.addEventListener("scroll", schedule);
    return () => {
      vv.removeEventListener("resize", schedule);
      vv.removeEventListener("scroll", schedule);
      if (raf) cancelAnimationFrame(raf);
      root.style.removeProperty("--wyn-kb-inset");
      root.removeAttribute("data-keyboard-open");
    };
  }, []);
}
