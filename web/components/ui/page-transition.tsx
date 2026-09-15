"use client";

import { AnimatePresence, motion } from "framer-motion";
import { usePathname } from "next/navigation";

/**
 * Root-level page transition. Keyed by pathname so a real route change
 * (not an in-page tab switch, which doesn't touch the URL path) triggers a
 * quick cross-fade + slide instead of the instant, jarring swap the browser
 * does by default.
 *
 * Kept deliberately short, subtle, and opacity-only: each page's own
 * AppChrome renders its own `position: fixed` bottom nav rather than the
 * root layout owning one persistent instance, so the nav bar is technically
 * inside this transition too. Animating `transform` (e.g. a slide/`y`
 * offset) on an ancestor would create a new containing block for those
 * fixed-position descendants and make the nav jump during the transition —
 * opacity doesn't have that side effect, so it's the only property animated
 * here. `mode="wait"` keeps exactly one page's DOM mounted at a time (the
 * short duration below keeps the resulting gap imperceptible) instead of
 * letting the outgoing and incoming full-page trees overlap in normal flow.
 */
export function PageTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.16, ease: "easeOut" }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
