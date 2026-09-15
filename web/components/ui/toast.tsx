"use client";

import { AnimatePresence, motion } from "framer-motion";
import { useCallback, useEffect, useRef, useState } from "react";

/**
 * Minimal transient toast for reporting a failed optimistic update after its
 * local state has already been rolled back (e.g. a like or follow that
 * didn't actually save). Auto-dismisses; message replaces mirror the
 * existing `.audit-undo-toast` bottom-sheet style used elsewhere.
 */
export function useToast(durationMs = 3200) {
  const [message, setMessage] = useState<string | null>(null);
  const timer = useRef<number | null>(null);

  const showToast = useCallback((next: string) => {
    setMessage(next);
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setMessage(null), durationMs);
  }, [durationMs]);

  useEffect(() => () => {
    if (timer.current) window.clearTimeout(timer.current);
  }, []);

  return { toastMessage: message, showToast };
}

export function Toast({ message }: { message: string | null }) {
  return (
    <AnimatePresence>
      {message ? (
        <motion.div
          className="wyn-toast"
          role="status"
          aria-live="polite"
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 16 }}
          transition={{ duration: 0.2, ease: "easeOut" }}
        >
          <span>{message}</span>
        </motion.div>
      ) : null}
    </AnimatePresence>
  );
}
