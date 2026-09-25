"use client";

import { useCallback, useRef, useState, type TouchEvent } from "react";

import { haptic } from "@/lib/haptics";

// Tuned to match components/home/home-screen.tsx's original pull-to-refresh
// feel exactly (see WYN-182) — Home is the shipped baseline every other
// screen using this hook should feel identical to.
const MAX_PULL_DISTANCE = 88;
const PULL_DAMPING = 0.48;
const REFRESH_THRESHOLD = 54;

type TouchGesture = { id: number; x: number; y: number; canPull: boolean };

export type UsePullToRefreshOptions = {
  /**
   * Gates the whole gesture off (no pullDistance changes, no refresh
   * trigger) without the caller needing to conditionally attach the touch
   * handlers. Accepts a plain boolean (the common case — e.g. the 4
   * staged-rollout screens passing their `isDeveloperAccount` gate result,
   * see lib/use-is-developer-account.ts) or a getter function for callers
   * that would otherwise have to read a ref during render to compute it
   * (React's react-hooks/refs rule forbids that) — Home passes
   * `() => mode === visibleModeRef.current` here (only pull while looking
   * at the tab whose data would actually be refreshed), resolved lazily
   * inside onTouchStart instead, matching where the original inline
   * implementation read it too.
   */
  enabled: boolean | (() => boolean);
  onRefresh: () => void | Promise<void>;
};

export type UsePullToRefreshResult = {
  pullDistance: number;
  refreshing: boolean;
  onTouchStart: (event: TouchEvent<HTMLElement>) => void;
  onTouchMove: (event: TouchEvent<HTMLElement>) => void;
  onTouchEnd: (event: TouchEvent<HTMLElement>) => void;
  onTouchCancel: () => void;
  /**
   * Manually fires the same de-duplicated refresh + spinner state the touch
   * gesture drives, without needing a completed drag. Home reuses this for
   * its existing "tap the already-active bottom-nav tab while scrolled to
   * top" refresh (see components/route-refresh-runtime.ts) so both triggers
   * share one spinner instead of drifting into two separate ones.
   */
  refresh: () => void;
};

/**
 * Extracted from components/home/home-screen.tsx's original inline touch
 * handlers (WYN-182) — this is ONLY the pull-gesture piece (canPull/
 * damping/threshold/haptic/spinner-driving state). Home's horizontal
 * tab-swipe gesture is a separate, unrelated concern and stays local to
 * home-screen.tsx, layered on top of this hook's handlers.
 *
 * Does not call `event.preventDefault()` anywhere, matching the original
 * Home implementation exactly (see WYN-182 design spec's note on Android
 * Chrome's native pull-to-refresh — mitigated app-wide via
 * `overscroll-behavior-y: contain` on html/body, not here).
 */
export function usePullToRefresh({ enabled, onRefresh }: UsePullToRefreshOptions): UsePullToRefreshResult {
  const [pullDistance, setPullDistance] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const touchGesture = useRef<TouchGesture | null>(null);
  const refreshingRef = useRef(false);

  const triggerRefresh = useCallback(() => {
    if (refreshingRef.current) return;
    refreshingRef.current = true;
    setRefreshing(true);
    setPullDistance(0);
    void Promise.resolve()
      .then(() => onRefresh())
      .catch(() => {
        // Route owners already render their own fetch errors. Keep the
        // spinner from leaving an unhandled rejection at the app root.
      })
      .finally(() => {
        refreshingRef.current = false;
        setRefreshing(false);
      });
  }, [onRefresh]);

  const onTouchStart = useCallback((event: TouchEvent<HTMLElement>) => {
    touchGesture.current = null;
    if (event.touches.length !== 1) return;
    const target = event.target;
    if (target instanceof Element && target.closest('input, textarea, select, [contenteditable="true"], [role="dialog"], .route-modal-backdrop, .wyn-post-media-track')) return;
    const touch = event.touches[0];
    if (!touch) return;
    const isEnabled = typeof enabled === "function" ? enabled() : enabled;
    touchGesture.current = {
      id: touch.identifier,
      x: touch.clientX,
      y: touch.clientY,
      canPull: isEnabled && window.scrollY <= 2 && !refreshingRef.current,
    };
  }, [enabled]);

  const onTouchMove = useCallback((event: TouchEvent<HTMLElement>) => {
    const start = touchGesture.current;
    if (!start) return;
    if (event.touches.length !== 1) {
      touchGesture.current = null;
      setPullDistance(0);
      return;
    }
    const touch = event.touches[0];
    if (!touch || touch.identifier !== start.id) return;
    if (!start.canPull || refreshingRef.current) return;
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    if (deltaY <= 0 || Math.abs(deltaY) <= Math.abs(deltaX) * 1.1) {
      setPullDistance((current) => (current ? 0 : current));
      return;
    }
    // Dampen the gesture so the refresh affordance feels native rather than
    // moving one-for-one with the finger.
    setPullDistance(Math.min(MAX_PULL_DISTANCE, deltaY * PULL_DAMPING));
  }, []);

  const onTouchEnd = useCallback((event: TouchEvent<HTMLElement>) => {
    const start = touchGesture.current;
    const touch = start && Array.from(event.changedTouches).find((item) => item.identifier === start.id);
    touchGesture.current = null;
    if (!start || !touch || event.touches.length !== 0) {
      setPullDistance(0);
      return;
    }
    const deltaX = touch.clientX - start.x;
    const deltaY = touch.clientY - start.y;
    const releasedPullDistance = Math.min(MAX_PULL_DISTANCE, Math.max(0, deltaY) * PULL_DAMPING);
    const shouldRefresh = start.canPull && releasedPullDistance >= REFRESH_THRESHOLD && deltaY > Math.abs(deltaX);
    if (shouldRefresh) {
      haptic();
      triggerRefresh();
      return;
    }
    setPullDistance(0);
  }, [triggerRefresh]);

  const onTouchCancel = useCallback(() => {
    touchGesture.current = null;
    setPullDistance(0);
  }, []);

  return { pullDistance, refreshing, onTouchStart, onTouchMove, onTouchEnd, onTouchCancel, refresh: triggerRefresh };
}
