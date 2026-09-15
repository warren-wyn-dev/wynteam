"use client";

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
  if (!message) return null;
  return (
    <div className="wyn-toast" role="status" aria-live="polite">
      <span>{message}</span>
    </div>
  );
}
