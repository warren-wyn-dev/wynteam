"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { useCallback, useEffect, useRef, useState } from "react";

export type ToastAction = { label: string; onClick: () => void };

/**
 * Transient feedback for optimistic actions. An optional Undo action runs only
 * on a real button click; replacing/dismissing a toast clears the old callback.
 */
export function useToast(durationMs = 3200) {
  const [toast, setToast] = useState<{ message: string; action?: ToastAction } | null>(null);
  const timer = useRef<number | null>(null);

  const dismissToast = useCallback(() => {
    if (timer.current !== null) window.clearTimeout(timer.current);
    timer.current = null;
    setToast(null);
  }, []);

  const showToast = useCallback((message: string, action?: ToastAction) => {
    setToast({ message, action });
    if (timer.current !== null) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      setToast(null);
      timer.current = null;
    }, durationMs);
  }, [durationMs]);

  useEffect(() => () => {
    if (timer.current !== null) window.clearTimeout(timer.current);
  }, []);

  return {
    toastMessage: toast?.message ?? null,
    toastAction: toast?.action ?? null,
    showToast,
    dismissToast,
  };
}

export function Toast({
  message,
  action,
  onDismiss,
}: {
  message: string | null;
  action?: ToastAction | null;
  onDismiss?: () => void;
}) {
  const reduceMotion = useReducedMotion();

  return (
    <AnimatePresence>
      {message ? (
        <motion.div
          className="wyn-toast"
          role="status"
          aria-live="polite"
          initial={reduceMotion ? false : { opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={reduceMotion ? undefined : { opacity: 0, y: 16 }}
          transition={{ duration: reduceMotion ? 0 : 0.2, ease: "easeOut" }}
        >
          <span>{message}</span>
          {action ? (
            <button
              className="wyn-toast-action"
              type="button"
              onClick={() => {
                onDismiss?.();
                action.onClick();
              }}
            >{action.label}</button>
          ) : null}
        </motion.div>
      ) : null}
    </AnimatePresence>
  );
}
