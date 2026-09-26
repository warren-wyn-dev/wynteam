"use client";

import { usePathname } from "next/navigation";
import { useEffect } from "react";

import { listenForForegroundPush } from "@/lib/push-notifications";

const scrollMemory = new Map<string, number>();

function shouldRememberScroll(pathname: string): boolean {
  if (pathname === "/" || pathname === "/clubs" || pathname === "/chat" || pathname === "/search" || pathname === "/notifications") return true;
  return pathname.startsWith("/profile/");
}

/**
 * Lives in the root Next.js layout, so unlike individual route components it
 * is not remounted when the user changes screens. It gives the web app two
 * native-app behaviours:
 *
 * - keep scroll positions across the five primary destinations;
 * - remember the scroll position of root tabs/profile screens and restore it
 *   when the user comes back, instead of treating every tab tap as a brand-new
 *   page visit.
 *
 * Delayed restores stop immediately when the user touches/scrolls, so this
 * never fights an intentional gesture while a slow feed is still rendering.
 */
export function AppNavigationRuntime() {
  const pathname = usePathname();

  useEffect(() => {
    // Older iOS standalone WebKit can report navigator.standalone=true while
    // the CSS display-mode query returns false. Use either installed-app
    // signal for standard (non-overlapping) top-bar/header geometry.
    const mode = window.matchMedia("(display-mode: standalone)");
    const sync = () => {
      const iosInstalled = (navigator as Navigator & { standalone?: boolean }).standalone === true;
      const isIos = /iPhone|iPad|iPod/i.test(navigator.userAgent)
        || (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
      document.documentElement.classList.toggle("wyn-pwa-standalone", mode.matches || iosInstalled);
      document.documentElement.classList.toggle("wyn-ios-standalone", isIos && (mode.matches || iosInstalled));
    };
    sync();
    mode.addEventListener("change", sync);
    return () => {
      mode.removeEventListener("change", sync);
      document.documentElement.classList.remove("wyn-pwa-standalone");
      document.documentElement.classList.remove("wyn-ios-standalone");
    };
  }, []);

  useEffect(() => {
    // Firebase downloads/config should not compete with the first app paint.
    // Do not prompt: initialize only an existing permission after idle.
    if (typeof Notification === "undefined" || Notification.permission !== "granted") return;
    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(() => { void listenForForegroundPush(); }, { timeout: 1400 });
      return () => window.cancelIdleCallback(id);
    }
    const timer = window.setTimeout(() => { void listenForForegroundPush(); }, 400);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    // Offline support is important, but registration can wait until the
    // visible page has started painting. Reuse a root effect so it runs once.
    const register = () => {
      void navigator.serviceWorker.register("/sw.js").catch(() => undefined);
    };
    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(register, { timeout: 1800 });
      return () => window.cancelIdleCallback(id);
    }
    const timer = window.setTimeout(register, 700);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!shouldRememberScroll(pathname)) return;

    let cancelled = false;
    let interacted = false;
    const target = scrollMemory.get(pathname);
    const timers: number[] = [];

    const stopDelayedRestore = () => {
      interacted = true;
    };
    window.addEventListener("touchstart", stopDelayedRestore, { passive: true });
    window.addEventListener("wheel", stopDelayedRestore, { passive: true });
    window.addEventListener("pointerdown", stopDelayedRestore, { passive: true });

    if (target != null && target > 0) {
      const restore = () => {
        if (cancelled || interacted) return;
        const maxTop = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
        window.scrollTo({ top: Math.min(target, maxTop), behavior: "auto" });
      };

      window.requestAnimationFrame(() => window.requestAnimationFrame(restore));
      // Feeds/profile media may increase the document height after their first
      // paint. Retry briefly, but only until the user starts interacting.
      timers.push(window.setTimeout(restore, 180));
      timers.push(window.setTimeout(restore, 520));
    }

    return () => {
      cancelled = true;
      scrollMemory.set(pathname, window.scrollY);
      for (const timer of timers) window.clearTimeout(timer);
      window.removeEventListener("touchstart", stopDelayedRestore);
      window.removeEventListener("wheel", stopDelayedRestore);
      window.removeEventListener("pointerdown", stopDelayedRestore);
    };
  }, [pathname]);

  return null;
}
