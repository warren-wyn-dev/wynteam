// ZOKY (the customer Food web, formerly WYNOS Food) origins. Founder decision
// 2026-10-18: zoky.wynos.online is the canonical origin. food.wynos.online keeps
// serving Food in phase 1 and redirects to ZOKY in phase 2 (web/proxy.ts,
// ZOKY_LEGACY_FOOD_REDIRECT), and stays a Food origin in this logic throughout,
// so a session, PKCE verifier or rollback on it keeps working (no cross-origin auth).
export const FOOD_PRODUCTION_HOST = "zoky.wynos.online";
export const FOOD_PRODUCTION_ORIGIN = "https://zoky.wynos.online";
export const FOOD_LEGACY_HOST = "food.wynos.online";

const FOOD_APP_HOSTS = new Set([FOOD_PRODUCTION_HOST, FOOD_LEGACY_HOST]);
// Social hosts that may open Food pages but must hand Food over to ZOKY.
const FOOD_HANDOFF_HOSTS = new Set(["wynos.online", "www.wynos.online"]);

/** A host that serves the Food app at "/" (ZOKY, or food.wynos.online during the move). */
export function isFoodAppHost(hostname: string): boolean {
  return FOOD_APP_HOSTS.has(hostname.toLowerCase());
}

/** The origin Food auth (OAuth return, email links) should use from this page. */
export function foodAuthOriginFor(hostname: string, currentOrigin: string): string {
  const host = hostname.toLowerCase();
  if (FOOD_APP_HOSTS.has(host)) return currentOrigin;
  if (FOOD_HANDOFF_HOSTS.has(host)) return FOOD_PRODUCTION_ORIGIN;
  return currentOrigin;
}

/** Food home after sign-in: "/" on a Food origin, ZOKY from WYNOS Social, else /food here. */
export function foodHomeUrlFor(hostname: string, currentOrigin: string): string {
  const host = hostname.toLowerCase();
  const foodAtRoot = FOOD_APP_HOSTS.has(host) || FOOD_HANDOFF_HOSTS.has(host);
  return new URL(foodAtRoot ? "/" : "/food", foodAuthOriginFor(host, currentOrigin)).href;
}
