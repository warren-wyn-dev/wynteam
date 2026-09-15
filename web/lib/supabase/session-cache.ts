import type { Session } from "@supabase/supabase-js";

let cachedSession: Session | null | undefined;

/**
 * Small in-memory bridge shared by the root Home auth gate and the route
 * gates used by the rest of the consumer app. Next.js keeps this module alive
 * across client-side navigation, so a route can paint immediately with the
 * already-known session instead of flashing a full-screen auth spinner every
 * time the user changes tabs/pages.
 *
 * Supabase remains authoritative: every mounted gate still verifies the
 * session in the background and auth-state events replace this cache.
 */
export function getCachedBrowserSession(): Session | null | undefined {
  return cachedSession;
}

export function cacheBrowserSession(session: Session | null): void {
  cachedSession = session;
}

export function clearCachedBrowserSession(): void {
  cachedSession = null;
}
