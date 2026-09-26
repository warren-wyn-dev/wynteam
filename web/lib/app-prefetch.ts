/**
 * Prefetch shared app routes only after an authenticated page is visible and
 * the browser has idle time. Next's <Link> still prefetches a route when its
 * navigation item comes into view; this queue warms the remaining routes
 * without competing with the initial Feed/Profile/Chat request waterfall.
 *
 * This module contains route manifests only. It never preloads a different
 * account's private data, and no work starts from the signed-out layout.
 */
const PRIMARY_ROUTES = ["/", "/clubs", "/chat", "/search", "/notifications"] as const;
const warmed = new Set<string>();

type ConnectionHints = { saveData?: boolean; effectiveType?: string };

export function shouldWarmAppRoutes(
  online: boolean,
  visible: boolean,
  hints: ConnectionHints | undefined,
): boolean {
  return online && visible && !hints?.saveData &&
    hints?.effectiveType !== "slow-2g" && hints?.effectiveType !== "2g";
}

/**
 * Returns a cleanup so a route change can cancel the remaining requests.
 * Previously warmed routes stay in the local manifest cache for this tab.
 */
export function scheduleAppRoutePrefetch(
  prefetch: (href: string) => void,
  userId: string,
  currentPath: string,
): () => void {
  if (typeof window === "undefined" || !userId) return () => undefined;

  const hints = (navigator as Navigator & { connection?: ConnectionHints }).connection;
  if (!shouldWarmAppRoutes(navigator.onLine, document.visibilityState === "visible", hints)) {
    return () => undefined;
  }

  const ownProfile = `/profile/${encodeURIComponent(userId)}?from=tab`;
  const queue = [...PRIMARY_ROUTES, ownProfile].filter((href) =>
    !warmed.has(href) && href.split("?")[0] !== currentPath,
  );
  if (!queue.length) return () => undefined;

  let cancelled = false;
  let timer: number | undefined;
  let idle: number | undefined;

  const run = () => {
    if (cancelled || !shouldWarmAppRoutes(
      navigator.onLine,
      document.visibilityState === "visible",
      (navigator as Navigator & { connection?: ConnectionHints }).connection,
    )) return;

    const href = queue.shift();
    if (!href) return;
    try {
      prefetch(href);
      warmed.add(href);
    } catch {
      // A failed hint is non-essential. Links still navigate normally.
    }

    // Pace route-manifest requests so an initial data fetch can finish first.
    if (queue.length) timer = window.setTimeout(() => schedule(false), 220);
  };

  const schedule = (first: boolean) => {
    if (cancelled) return;
    if (typeof window.requestIdleCallback === "function") {
      idle = window.requestIdleCallback(run, { timeout: first ? 2500 : 4000 });
    } else {
      timer = window.setTimeout(run, first ? 650 : 220);
    }
  };

  schedule(true);
  return () => {
    cancelled = true;
    if (timer !== undefined) window.clearTimeout(timer);
    if (idle !== undefined && typeof window.cancelIdleCallback === "function") {
      window.cancelIdleCallback(idle);
    }
  };
}
