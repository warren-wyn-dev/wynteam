type OrderRecoveryEnvironment = {
  document: Pick<Document, "visibilityState" | "addEventListener" | "removeEventListener">;
  window: Pick<Window, "addEventListener" | "removeEventListener">;
};

/** Re-fetch authoritative state after missed events, without overlapping refreshes. */
export function createOrderRecovery(
  reload: () => void | Promise<unknown>,
  environment: OrderRecoveryEnvironment,
  delayMs = 120,
) {
  let live = true;
  let running = false;
  let queued = false;
  let timer: ReturnType<typeof setTimeout> | null = null;

  const schedule = () => {
    if (!live || running || timer !== null) return;
    timer = setTimeout(() => { void refresh(); }, delayMs);
  };

  const refresh = async () => {
    timer = null;
    if (!live) return;
    queued = false;
    running = true;
    try {
      await reload();
    } catch {
      // The caller owns the error message; a later event can retry recovery.
    } finally {
      running = false;
      if (live && queued) schedule();
    }
  };

  const request = () => {
    if (!live) return;
    queued = true;
    schedule();
  };
  const onVisible = () => {
    if (environment.document.visibilityState === "visible") request();
  };
  const onOnline = () => request();
  environment.document.addEventListener("visibilitychange", onVisible);
  environment.window.addEventListener("online", onOnline);

  return {
    request,
    onSubscriptionStatus: (status: string) => {
      // Supabase emits this after the initial join and every successful rejoin.
      if (status === "SUBSCRIBED") request();
    },
    dispose: () => {
      live = false;
      queued = false;
      if (timer !== null) clearTimeout(timer);
      timer = null;
      environment.document.removeEventListener("visibilitychange", onVisible);
      environment.window.removeEventListener("online", onOnline);
    },
  };
}
