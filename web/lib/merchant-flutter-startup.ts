export const MERCHANT_FLUTTER_STARTUP_EVENT = "zoky-merchant-startup";

export type MerchantFlutterStartup = {
  viewId: number;
  phase: "content-ready";
  elapsedMs: number;
  fontWarmupMs: number;
  fontWarmupTimedOut: boolean;
};

function startupDetail(value: unknown): MerchantFlutterStartup | undefined {
  if (!value || typeof value !== "object") return;
  const detail = value as Partial<MerchantFlutterStartup>;
  if (!Number.isSafeInteger(detail.viewId) || detail.viewId! < 0 ||
      detail.phase !== "content-ready" || typeof detail.fontWarmupTimedOut !== "boolean" ||
      typeof detail.elapsedMs !== "number" || !Number.isFinite(detail.elapsedMs) || detail.elapsedMs < 0 ||
      typeof detail.fontWarmupMs !== "number" || !Number.isFinite(detail.fontWarmupMs) || detail.fontWarmupMs < 0) return;
  return detail as MerchantFlutterStartup;
}

/** UX readiness only; all session and store authorization remains in the bridge. */
export function observeMerchantFlutterStartup({
  onReady,
  onTimeout,
  onSlow,
  target = window,
  timeoutMs = 20_000,
  failAfterMs = 90_000,
}: {
  onReady: (detail: MerchantFlutterStartup) => void;
  onTimeout: () => void;
  /**
   * When given, the first timeout is not fatal: the view keeps loading and a
   * late ready signal still reveals it (slow mobile networks, Founder
   * 2026-11-01). onTimeout then fires only after failAfterMs.
   */
  onSlow?: () => void;
  target?: EventTarget;
  timeoutMs?: number;
  failAfterMs?: number;
}) {
  let viewId: number | undefined;
  let disposed = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const early = new Map<number, MerchantFlutterStartup>();
  const dispose = () => {
    disposed = true;
    clearTimeout(timer);
    early.clear();
    target.removeEventListener(MERCHANT_FLUTTER_STARTUP_EVENT, receive);
  };
  const finish = (detail: MerchantFlutterStartup) => {
    dispose();
    onReady(detail);
  };
  function receive(event: Event) {
    if (disposed) return;
    const detail = startupDetail((event as CustomEvent<unknown>).detail);
    if (!detail) return;
    if (viewId === undefined) {
      // Install before addView, including engines that publish synchronously.
      // Bound this buffer while the shared engine is loading.
      if (early.size === 8 && !early.has(detail.viewId)) early.delete(early.keys().next().value!);
      early.set(detail.viewId, detail);
    } else if (detail.viewId === viewId) finish(detail);
  }
  target.addEventListener(MERCHANT_FLUTTER_STARTUP_EVENT, receive);
  return {
    watch(id: number) {
      if (disposed) return;
      if (!Number.isSafeInteger(id) || id < 0 || viewId !== undefined) throw new Error("merchant_flutter_invalid_view");
      viewId = id;
      const pending = early.get(id);
      early.clear();
      if (pending) { finish(pending); return; }
      // Engine initialization has its own timeout. This bounds store/font startup.
      // A hidden page does not paint frames, so its time does not count.
      const doc = typeof document === "undefined" ? undefined : document;
      const arm = (ms: number, fire: () => void) => {
        timer = setTimeout(() => {
          if (disposed) return;
          if (doc?.visibilityState === "hidden") {
            const resume = () => {
              if (doc.visibilityState === "hidden") return;
              doc.removeEventListener("visibilitychange", resume);
              if (!disposed) arm(ms, fire);
            };
            doc.addEventListener("visibilitychange", resume);
            return;
          }
          fire();
        }, ms);
      };
      const fail = () => { dispose(); onTimeout(); };
      if (onSlow) arm(timeoutMs, () => { onSlow(); arm(Math.max(0, failAfterMs - timeoutMs), fail); });
      else arm(timeoutMs, fail);
    },
    dispose,
  };
}

type StartupStage = "start" | "entrypoint" | "engine" | "view" | "content";

/** Bounded, local-only timings for Safari/Web Inspector; no account or store data. */
export function markMerchantFlutterStartup(stage: StartupStage, detail?: MerchantFlutterStartup) {
  const name = `merchant:flutter:${stage}`;
  performance.clearMarks(name);
  performance.mark(name, detail ? { detail: {
    elapsedMs: detail.elapsedMs,
    fontWarmupMs: detail.fontWarmupMs,
    fontWarmupTimedOut: detail.fontWarmupTimedOut,
  } } : undefined);
}
