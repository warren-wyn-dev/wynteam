/** Reconcile Chat after sleep, network recovery or returning to a tab.
 * Realtime subscriptions do not replay every event that happened offline.
 * Focus, online and visibility may all fire at once, so coalesce bursts.
 */
export function attachChatResume(onResume: () => void, cooldownMs = 3_000): () => void {
  if (typeof window === "undefined" || typeof document === "undefined") return () => {};
  let lastResumeAt = Number.NEGATIVE_INFINITY;
  const resume = () => {
    if (document.visibilityState !== "visible" || navigator.onLine === false) return;
    const now = Date.now();
    if (now - lastResumeAt < cooldownMs) return;
    lastResumeAt = now;
    onResume();
  };
  window.addEventListener("focus", resume);
  window.addEventListener("online", resume);
  document.addEventListener("visibilitychange", resume);
  return () => {
    window.removeEventListener("focus", resume);
    window.removeEventListener("online", resume);
    document.removeEventListener("visibilitychange", resume);
  };
}
