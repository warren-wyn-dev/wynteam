"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";

import { listenForForegroundPush } from "@/lib/push-notifications";

const scrollMemory = new Map<string, number>();
const PREFETCH_ROUTES = ["/", "/clubs", "/chat", "/search", "/notifications"] as const;

function shouldRememberScroll(pathname: string): boolean {
  if (pathname === "/" || pathname === "/clubs" || pathname === "/chat" || pathname === "/search" || pathname === "/notifications") return true;
  return pathname.startsWith("/profile/");
}

/**
 * Lives in the root Next.js layout, so unlike individual route components it
 * is not remounted when the user changes screens. It gives the web app two
 * native-app behaviours:
 *
 * - warm the code/data route manifests for the five primary destinations;
 * - remember the scroll position of root tabs/profile screens and restore it
 *   when the user comes back, instead of treating every tab tap as a brand-new
 *   page visit.
 *
 * Delayed restores stop immediately when the user touches/scrolls, so this
 * never fights an intentional gesture while a slow feed is still rendering.
 */
export function AppNavigationRuntime() {
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    // Older iOS standalone WebKit can report navigator.standalone=true while
    // the CSS display-mode query returns false. Keep the opaque status-area
    // background active in either installed-app signal.
    const mode = window.matchMedia("(display-mode: standalone)");
    const sync = () => {
      const iosInstalled = (navigator as Navigator & { standalone?: boolean }).standalone === true;
      document.documentElement.classList.toggle("wyn-pwa-standalone", mode.matches || iosInstalled);
    };
    sync();
    mode.addEventListener("change", sync);
    return () => {
      mode.removeEventListener("change", sync);
      document.documentElement.classList.remove("wyn-pwa-standalone");
    };
  }, []);

  useEffect(() => {
    for (const href of PREFETCH_ROUTES) router.prefetch(href);
  }, [router]);

  useEffect(() => {
    // Never prompts — only starts listening if a previous session already
    // has notification permission granted, so a returning user keeps
    // getting foreground pushes without this component ever requesting it.
    void listenForForegroundPush();
  }, []);

  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    // Registered once for the whole session; the worker itself only caches
    // immutable static assets (see public/sw.js), so a stale registration
    // never hides new app code or data.
    navigator.serviceWorker.register("/sw.js").catch(() => undefined);
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
