"use client";

import { AnimatePresence, motion } from "framer-motion";
import { usePathname } from "next/navigation";

/**
 * Root-level page transition. Keyed by pathname so a real route change
 * (not an in-page tab switch, which doesn't touch the URL path) triggers a
 * quick cross-fade + slide instead of the instant, jarring swap the browser
 * does by default.
 *
 * The bottom nav itself lives outside this transition entirely — see
 * AppBottomNavHost, rendered once in the root layout — so it never
 * remounts or fades on navigation, only the page content here does.
 *
 * Kept deliberately short and opacity-only. `mode="wait"` keeps exactly
 * one page's DOM mounted at a time instead of letting the outgoing and
 * incoming full-page trees overlap in normal flow — but it runs the exit
 * and enter fades sequentially, not together, so the total
 * dip-to-transparent-and-back is 2x the duration below. Now that
 * navigation itself is usually instant (see lib/mount-cache.ts), that
 * became the only thing still reading as a "flicker" on every page change,
 * so the duration is kept just long enough to avoid an instant jarring cut,
 * not to be a visible animation.
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
        transition={{ duration: 0.07, ease: "easeOut" }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
