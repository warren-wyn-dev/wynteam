import { useEffect } from "react";

/**
 * Lets the persistent bottom nav (components/bottom-navigation.tsx) ask the
 * currently-mounted page to refresh its own data, for the "tap the already-
 * active tab again while already scrolled to the top" gesture (the same
 * pattern X/Instagram use). The nav lives outside every page's own render
 * tree (see components/app-bottom-nav-runtime.tsx), so it has no direct
 * reference to a specific page's refetch function — this is just a plain
 * pub/sub to bridge that gap for whichever page happens to be listening.
 */
const listeners = new Set<() => void>();

export function triggerRouteRefresh() {
  listeners.forEach((listener) => listener());
}

export function useRouteRefreshListener(onRefresh: () => void) {
  useEffect(() => {
    listeners.add(onRefresh);
    return () => {
      listeners.delete(onRefresh);
    };
  }, [onRefresh]);
}
