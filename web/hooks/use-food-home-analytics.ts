"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useRef, useState, type MouseEvent } from "react";
import { createFoodHomeAnalytics, isFoodHomePlacement, type FoodHomeAnalytics, type FoodHomePlacementKind } from "@/lib/food-home-analytics";

const SELECTOR = "[data-food-home-kind][data-food-home-id]";
type ObservedPlacement = {
  kind: FoodHomePlacementKind;
  id: string;
  timer?: ReturnType<typeof setTimeout>;
  qualified: boolean;
};

/** Observe the existing DOM; analytics must not add layout or alter navigation. */
export function observeFoodHomeAnalytics(root: HTMLElement, analytics: FoodHomeAnalytics): () => void {
  if (typeof IntersectionObserver === "undefined") return () => {};
  const placements = new Map<Element, ObservedPlacement>();
  let stopped = false;
  const clearTimer = (placement: ObservedPlacement) => {
    if (placement.timer !== undefined) clearTimeout(placement.timer);
    placement.timer = undefined;
  };
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      const placement = placements.get(entry.target);
      if (!placement || stopped) continue;
      if (!entry.isIntersecting || entry.intersectionRatio < 0.5 || document.visibilityState !== "visible") {
        clearTimer(placement);
      } else if (!placement.qualified && placement.timer === undefined) {
        placement.timer = setTimeout(() => {
          placement.timer = undefined;
          if (stopped || document.visibilityState !== "visible" || !root.contains(entry.target)) return;
          placement.qualified = true;
          void analytics.observeImpression(placement.kind, placement.id);
        }, 1000);
      }
    }
  }, { threshold: [0, 0.5] });

  const refresh = () => {
    if (stopped) return;
    const elements = new Set<Element>(root.querySelectorAll(SELECTOR));
    if (root.matches(SELECTOR)) elements.add(root);
    for (const [element, placement] of placements) {
      if (!elements.has(element)
        || element.getAttribute("data-food-home-kind") !== placement.kind
        || element.getAttribute("data-food-home-id") !== placement.id) {
        clearTimer(placement);
        placements.delete(element);
        observer.unobserve(element);
      }
    }
    for (const element of elements) {
      if (placements.has(element)) continue;
      const kind = element.getAttribute("data-food-home-kind");
      const id = element.getAttribute("data-food-home-id");
      if (!isFoodHomePlacement(kind, id) || id === null) continue;
      placements.set(element, { kind, id, qualified: false });
      observer.observe(element);
    }
  };
  const visibilityChanged = () => {
    for (const [element, placement] of placements) {
      clearTimer(placement);
      // A fresh intersection is required after returning from a hidden tab.
      // The viewport may have changed while observers were suspended.
      if (document.visibilityState === "visible" && !placement.qualified) {
        observer.unobserve(element);
        observer.observe(element);
      }
    }
  };
  const mutations = typeof MutationObserver === "undefined" ? null : new MutationObserver(refresh);
  mutations?.observe(root, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["data-food-home-kind", "data-food-home-id"],
  });
  document.addEventListener("visibilitychange", visibilityChanged);
  refresh();

  return () => {
    stopped = true;
    observer.disconnect();
    mutations?.disconnect();
    document.removeEventListener("visibilitychange", visibilityChanged);
    for (const placement of placements.values()) clearTimer(placement);
    placements.clear();
  };
}

export function useFoodHomeAnalytics(client: SupabaseClient) {
  const recorder = useRef<FoodHomeAnalytics | null>(null);
  const [root, setRoot] = useState<HTMLElement | null>(null);
  const analyticsRef = useCallback((node: HTMLElement | null) => setRoot(node), []);

  useEffect(() => {
    const next = createFoodHomeAnalytics(client);
    recorder.current = next;
    return () => {
      next.dispose();
      if (recorder.current === next) recorder.current = null;
    };
  }, [client]);

  useEffect(() => {
    if (root && recorder.current) return observeFoodHomeAnalytics(root, recorder.current);
  }, [client, root]);

  const onAnalyticsClickCapture = useCallback((event: MouseEvent<HTMLElement>) => {
    if (!(event.target instanceof Element)) return;
    const target = event.target.closest(`button${SELECTOR},a[href]${SELECTOR}`);
    if (!target || !event.currentTarget.contains(target)
      || target.matches(":disabled,[aria-disabled='true']")) return;
    const kind = target.getAttribute("data-food-home-kind");
    const id = target.getAttribute("data-food-home-id");
    if (isFoodHomePlacement(kind, id) && id !== null) void recorder.current?.recordClick(kind, id);
  }, []);

  return { analyticsRef, onAnalyticsClickCapture };
}
