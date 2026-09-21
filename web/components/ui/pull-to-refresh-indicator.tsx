"use client";

import type { UsePullToRefreshResult } from "@/lib/use-pull-to-refresh";

/**
 * Shared visual for every screen using usePullToRefresh (lib/use-pull-to-
 * refresh.ts) — a small floating circular badge that peeks in from behind
 * the screen's header as you pull and settles just below it while
 * refreshing, matching a native pull-to-refresh indicator.
 *
 * Always position: fixed, not inline in the document flow: several of
 * these screens (Profile, Club detail) have header/bio/meta/tabs content
 * tall enough that an inline indicator (this repo's original approach, on
 * Home) renders buried below all that chrome, often off-screen, instead
 * of visible where the pull gesture actually happens (see WYN-184-era
 * `.wyn-profile-topbar` overlap this fixed the same class of bug for).
 *
 * `topOffset` is the screen's own header height (e.g. "60px" for the
 * standard AppChrome title bar, "52px" for `.wyn-profile-topbar`, or a sum
 * for a header with its own tab row underneath) — the badge settles just
 * below it, clear of back/title/settings controls, and peeks in from
 * behind it while dragging.
 */
export function PullToRefreshIndicator({
  pull,
  topOffset,
  refreshingLabel,
}: {
  pull: UsePullToRefreshResult;
  topOffset: string;
  refreshingLabel: string;
}) {
  if (pull.pullDistance <= 0 && !pull.refreshing) return null;
  return (
    <div
      aria-label={pull.refreshing ? refreshingLabel : "ลากลงเพื่อรีเฟรช"}
      aria-live="polite"
      style={{ position: "fixed", top: `calc(${topOffset} + env(safe-area-inset-top, 0px))`, left: 0, right: 0, height: 0, zIndex: 60, pointerEvents: "none" }}
    >
      <div
        style={{
          position: "absolute",
          top: pull.refreshing ? 14 : Math.max(-18, Math.min(14, -18 + pull.pullDistance * 0.4)),
          left: "50%",
          width: 32,
          height: 32,
          borderRadius: "50%",
          background: "var(--wyn-surface)",
          boxShadow: "0 2px 10px rgb(0 0 0 / 12%)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          opacity: pull.refreshing ? 1 : Math.max(0, Math.min(1, pull.pullDistance / 40)),
          transform: `translateX(-50%) scale(${pull.refreshing ? 1 : Math.max(0.6, Math.min(1, 0.6 + pull.pullDistance / 220))})`,
          transition: pull.refreshing ? "top 180ms ease, opacity 180ms ease, transform 180ms ease" : "none",
        }}
      >
        <div className="route-system-spinner tiny" />
      </div>
    </div>
  );
}
