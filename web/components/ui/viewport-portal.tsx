"use client";

import { useEffect, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";

/**
 * Render viewport-fixed controls outside PageTransition's transformed
 * motion.div. Fixed descendants of a transformed ancestor are relative to
 * that ancestor and scroll away when iOS auto-pans for its keyboard.
 * Keeping the portal within the React tree retains contexts and events.
 */
export function ViewportPortal({ children }: { children: ReactNode }) {
  const [host, setHost] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setHost(document.body);
  }, []);
  return host ? createPortal(children, host) : null;
}
