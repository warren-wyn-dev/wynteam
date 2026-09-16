/**
 * Fires a short device vibration for an action that would trigger haptic
 * feedback in a native app (like, follow, redrop, refresh). No-ops silently
 * where the Vibration API doesn't exist or is disallowed (iOS Safari never
 * implements it; some browsers require a prior user gesture in the same
 * task, which every call site here already has).
 */
export function haptic(pattern: number | number[] = 10) {
  if (typeof navigator === "undefined" || typeof navigator.vibrate !== "function") return;
  try {
    navigator.vibrate(pattern);
  } catch {
    // Vibration is best-effort UI polish, never worth surfacing an error for.
  }
}
