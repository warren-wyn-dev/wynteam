"use client";

import { useEffect } from "react";

import { reportClientFailure } from "@/lib/client-health";

/** Observe unexpected browser errors without collecting message text or PII. */
export function ClientErrorMonitor() {
  useEffect(() => {
    const onError = (event: ErrorEvent) => {
      // Ignore errors from extensions, cross-origin embeds and third-party
      // scripts: they are outside WYNOS's own application release surface.
      if (event.filename) {
        try {
          if (new URL(event.filename, window.location.href).origin !== window.location.origin) return;
        } catch { return; }
      }
      reportClientFailure("uncaught");
    };
    const onRejection = () => reportClientFailure("unhandled_rejection");
    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onRejection);
    return () => {
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onRejection);
    };
  }, []);

  return null;
}
