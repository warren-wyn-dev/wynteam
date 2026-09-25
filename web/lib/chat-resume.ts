/** Refetch missed Realtime messages after connectivity or visibility recovers. */
type ListenerTarget = {
  addEventListener(type: string, listener: () => void): void;
  removeEventListener(type: string, listener: () => void): void;
};
type ResumeEnvironment = {
  window: ListenerTarget & { navigator: { onLine: boolean } };
  document: ListenerTarget & { visibilityState: string };
};

export function attachChatResume(
  refresh: () => void | Promise<void>,
  env: ResumeEnvironment | null =
    typeof window === "undefined" || typeof document === "undefined"
      ? null : { window, document },
): () => void {
  if (!env) return () => undefined;
  let active = true;
  let inFlight = false;
  const eligible = () => env.window.navigator.onLine !== false &&
    env.document.visibilityState === "visible";
  const revalidate = () => {
    if (!active || inFlight || !eligible()) return;
    inFlight = true;
    void Promise.resolve().then(() => {
      if (active && eligible()) return refresh();
    }).catch(() => undefined).finally(() => { inFlight = false; });
  };
  env.window.addEventListener("online", revalidate);
  env.document.addEventListener("visibilitychange", revalidate);
  return () => {
    active = false;
    env.window.removeEventListener("online", revalidate);
    env.document.removeEventListener("visibilitychange", revalidate);
  };
}
