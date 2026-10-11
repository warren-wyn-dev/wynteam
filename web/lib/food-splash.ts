// The Food launch splash (app/food/layout.tsx) stays up until the screen
// underneath has its data, so people never see a blank loading skeleton.
// The boot script defines window.__fxSplashReady; it keeps the splash for at
// least 1 s, and CSS plus a timer fade it out after ~4 s even if no screen
// reports ready. Calling this when the splash was already shown is a no-op.
export function markFoodSplashReady() {
  if (typeof window === "undefined") return;
  (window as Window & { __fxSplashReady?: () => void }).__fxSplashReady?.();
}
