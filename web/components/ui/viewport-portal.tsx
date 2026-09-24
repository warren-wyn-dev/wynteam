"use client";

import { useSyncExternalStore, type ReactNode } from "react";
import { createPortal } from "react-dom";

/**
 * Fixed controls must live under body, outside PageTransition's transformed
 * motion.div, or iOS keyboard auto-panning moves them with the document.
 * useSyncExternalStore returns null during SSR/hydration and body afterwards,
 * avoiding both a hydration mismatch and synchronous setState in an effect.
 */
const subscribe = () => () => undefined;
const getBrowserHost = () => document.body;
const getServerHost = () => null;

export function ViewportPortal({ children }: { children: ReactNode }) {
  const host = useSyncExternalStore<HTMLElement | null>(subscribe, getBrowserHost, getServerHost);
  return host ? createPortal(children, host) : null;
}
