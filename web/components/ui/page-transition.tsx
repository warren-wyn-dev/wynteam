"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { usePathname } from "next/navigation";

/**
 * Root-level page transition. Keyed by pathname so a real route change
 * (not an in-page tab switch, which doesn't touch the URL path) triggers a
 * directional slide + fade instead of the instant, jarring swap the
 * browser does by default.
 *
 * The bottom nav itself lives outside this transition entirely — see
 * AppBottomNavHost, rendered once in the root layout — so it never
 * remounts or fades on navigation, only the page content here does.
 *
 * WYN-175 (2026-09-19, Founder-approved Option B): the plain 70ms
 * opacity-only cross-fade this used to be read as too web-like — the
 * Founder chose a more visible, native-feeling transition over keeping
 * that minimal fade. Duration/easing port `WynMotion.standard` (220ms)
 * from the Flutter interaction system (ds-010-interaction-feedback.md)
 * to CSS-transform/opacity so the two platforms' "screen enters/exits"
 * feel share one timing language. Keep `mode="wait"` to preserve the
 * single-page DOM and fixed-position composer geometry. Shorten only the
 * outgoing transition, so the next route can mount sooner without altering
 * the approved 220ms arrival animation.
 *
 * `useReducedMotion()` mirrors iOS Reduce Motion / Android Remove
 * animations / prefers-reduced-motion (same flag Flutter's
 * `WynMotion.isReduced` reads). Per that doc's rule "ตัดการเดินทาง ไม่ตัด
 * สถานะ" (cut the distance traveled, not the state change), reduced
 * motion drops the slide and falls back to a same-duration fade so the
 * page still visibly changes, just without traveling across the screen.
 */
const SLIDE_DISTANCE = 24;
const DURATION = 0.22;
const EXIT_DURATION = 0.09;
const EASE: [number, number, number, number] = [0.22, 0.61, 0.36, 1];

export function PageTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const reducedMotion = useReducedMotion();
  const offset = reducedMotion ? 0 : SLIDE_DISTANCE;
  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        initial={{ opacity: 0, x: offset }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: -offset, transition: { duration: EXIT_DURATION, ease: EASE } }}
        transition={{ duration: DURATION, ease: EASE }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
