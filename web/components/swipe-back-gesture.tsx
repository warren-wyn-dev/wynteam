"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef } from "react";

// Same five tab roots AppNavigationRuntime treats specially: there is no
// meaningful "back" from a root tab, and Home already uses a left/right
// touch drag itself (switching feed mode), so a global edge-swipe there
// would fight that gesture instead of doing anything useful.
const ROOT_ROUTES = new Set(["/", "/clubs", "/chat", "/search", "/notifications"]);

const EDGE_WIDTH = 24;
const TRIGGER_DISTANCE = 80;
const MAX_VERTICAL_DRIFT_RATIO = 0.5;

/**
 * iOS/Android give a native app "swipe from the left edge to go back" on any
 * screen pushed on top of another. A web app loses that the moment it runs
 * standalone (no browser chrome, so no Safari-provided edge-swipe either).
 * This restores it for WYNOS's own pushed screens (post detail, profile,
 * chat conversation, settings, …) by calling the same `router.back()` every
 * in-app back button already uses — it's the same navigation, just reachable
 * by gesture too.
 */
export function SwipeBackGesture() {
  const pathname = usePathname();
  const router = useRouter();
  const pathnameRef = useRef(pathname);
  const gesture = useRef<{ x: number; y: number; tracking: boolean } | null>(null);

  useEffect(() => {
    pathnameRef.current = pathname;
  }, [pathname]);

  useEffect(() => {
    const onTouchStart = (event: TouchEvent) => {
      if (ROOT_ROUTES.has(pathnameRef.current)) return;
      const touch = event.touches[0];
      if (!touch || touch.clientX > EDGE_WIDTH) return;
      gesture.current = { x: touch.clientX, y: touch.clientY, tracking: true };
    };

    const onTouchMove = (event: TouchEvent) => {
      const start = gesture.current;
      const touch = event.touches[0];
      if (!start?.tracking || !touch) return;
      const deltaY = Math.abs(touch.clientY - start.y);
      const deltaX = touch.clientX - start.x;
      // A drag that's gone more vertical than horizontal is a scroll, not a
      // back gesture — stop tracking so it doesn't fire on release.
      if (deltaY > Math.abs(deltaX) * MAX_VERTICAL_DRIFT_RATIO && deltaY > 12) {
        start.tracking = false;
      }
    };

    const onTouchEnd = (event: TouchEvent) => {
      const start = gesture.current;
      gesture.current = null;
      if (!start?.tracking) return;
      const touch = event.changedTouches[0];
      if (!touch) return;
      if (touch.clientX - start.x >= TRIGGER_DISTANCE) router.back();
    };

    const onTouchCancel = () => { gesture.current = null; };

    window.addEventListener("touchstart", onTouchStart, { passive: true });
    window.addEventListener("touchmove", onTouchMove, { passive: true });
    window.addEventListener("touchend", onTouchEnd, { passive: true });
    window.addEventListener("touchcancel", onTouchCancel, { passive: true });
    return () => {
      window.removeEventListener("touchstart", onTouchStart);
      window.removeEventListener("touchmove", onTouchMove);
      window.removeEventListener("touchend", onTouchEnd);
      window.removeEventListener("touchcancel", onTouchCancel);
    };
  }, [router]);

  return null;
}
