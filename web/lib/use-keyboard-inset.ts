"use client";

import { useEffect } from "react";

/**
 * Fallback for browsers that shrink only visualViewport on keyboard open.
 * On recent iOS/Android interactiveWidget:resizes-content already shrinks
 * the layout viewport: the extra inset must stay zero (no double shift).
 * Ignore viewport changes from URL bars unless the comment input is focused.
 */
export function useKeyboardInset() {
  useEffect(() => {
    const vv = window.visualViewport;
    if (!vv) return;
    const root = document.documentElement;
    let raf = 0;
    const update = () => {
      raf = 0;
      const focus = document.activeElement;
      const composerFocused = focus instanceof HTMLElement && Boolean(focus.closest(".detail-composer-shell"));
      const overlap = composerFocused ? Math.max(0, window.innerHeight - vv.height - vv.offsetTop) : 0;
      const rounded = Math.round(overlap);
      root.style.setProperty("--wyn-kb-inset", `${rounded}px`);
      if (composerFocused && rounded > 40) root.setAttribute("data-keyboard-open", "true");
      else root.removeAttribute("data-keyboard-open");
    };
    const schedule = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };
    schedule();
    vv.addEventListener("resize", schedule);
    vv.addEventListener("scroll", schedule);
    window.addEventListener("resize", schedule);
    document.addEventListener("focusin", schedule);
    document.addEventListener("focusout", schedule);
    return () => {
      vv.removeEventListener("resize", schedule);
      vv.removeEventListener("scroll", schedule);
      window.removeEventListener("resize", schedule);
      document.removeEventListener("focusin", schedule);
      document.removeEventListener("focusout", schedule);
      if (raf) cancelAnimationFrame(raf);
      root.style.removeProperty("--wyn-kb-inset");
      root.removeAttribute("data-keyboard-open");
    };
  }, []);
}
