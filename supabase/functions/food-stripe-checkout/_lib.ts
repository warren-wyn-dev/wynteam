/**
 * GP v1 (supabase/migrations/20261011140000_merchant_gp_v1.sql): the WYNOS GP
 * on an order is collected as a Stripe application fee. The amount comes
 * from the database (food_order_gp_quote, the order's snapshotted rate);
 * this only checks it before it reaches Stripe. Returns 0 when there is no
 * GP (the default today) so the checkout is exactly as before.
 */
export function applicationFeeSatang(quote: unknown, amountSatang: number): number {
  if (!quote || typeof quote !== "object") throw new Error("gp_quote_missing");
  const q = quote as Record<string, unknown>;
  const gp = Number(q.gp_satang);
  const total = Number(q.total_satang);
  if (!Number.isSafeInteger(gp) || gp < 0) throw new Error("gp_quote_invalid");
  // The quote must be for the amount being charged; anything else means the
  // order changed under us and the fee could be wrong.
  if (total !== amountSatang) throw new Error("gp_quote_amount_mismatch");
  if (gp > amountSatang) throw new Error("gp_quote_exceeds_amount");
  return gp;
}

/**
 * Trusted Food customer web origins for live-mode Stripe calls (ZOKY-135).
 * ZOKY (zoky.wynos.online) is canonical; food.wynos.online stays accepted for
 * the domain transition and rollback. Exact string match only: no suffix,
 * wildcard or regex matching.
 */
export const FOOD_WEB_ORIGIN = "https://zoky.wynos.online";
export const FOOD_WEB_ORIGINS: ReadonlySet<string> = new Set([
  FOOD_WEB_ORIGIN,
  "https://food.wynos.online",
]);

export function isFoodWebOrigin(origin: string | null | undefined): boolean {
  return typeof origin === "string" && FOOD_WEB_ORIGINS.has(origin);
}

/**
 * Origin for Stripe success/cancel URLs: the request's origin only when it is
 * on the allowlist, otherwise ZOKY. Never an arbitrary request origin.
 */
export function foodReturnOrigin(origin: string | null | undefined): string {
  return isFoodWebOrigin(origin) ? origin as string : FOOD_WEB_ORIGIN;
}

/**
 * A separately configured Sandbox browser may return to its own app routes.
 * This setting never authorizes a live-mode request or a live return URL.
 * Configuration is a comma-separated list of exact HTTPS origins: no paths,
 * credentials, query strings, fragments, wildcards or URL normalization.
 */
function testReturnOrigin(
  origin: string | null | undefined,
  stripeLiveMode: boolean | null | undefined,
  configuredOrigins: string | null | undefined,
): string | null {
  if (stripeLiveMode !== false || !origin || !configuredOrigins) return null;
  const exactHttpsOrigin = (value: string): string | null => {
    if (value.includes("*")) return null;
    try {
      const url = new URL(value);
      return url.protocol === "https:" && !url.username && !url.password && url.origin === value
        ? value
        : null;
    } catch { return null; }
  };
  const candidate = exactHttpsOrigin(origin);
  if (!candidate) return null;
  return configuredOrigins.split(",").some((entry) => exactHttpsOrigin(entry.trim()) === candidate)
    ? candidate
    : null;
}

export function foodReturnBaseUrl(
  origin: string | null | undefined,
  stripeLiveMode: boolean | null | undefined,
  configuredTestOrigins: string | null | undefined,
): string {
  const testOrigin = testReturnOrigin(origin, stripeLiveMode, configuredTestOrigins);
  // Preview hosts do not have the canonical host's root-to-Food rewrite.
  return testOrigin && !isFoodWebOrigin(testOrigin)
    ? `${testOrigin}/food`
    : foodReturnOrigin(origin);
}

export function merchantReturnBaseUrl(
  origin: string | null | undefined,
  stripeLiveMode: boolean | null | undefined,
  configuredTestOrigins: string | null | undefined,
): string {
  const canonicalOrigin = "https://merchant.wynos.online";
  const testOrigin = testReturnOrigin(origin, stripeLiveMode, configuredTestOrigins);
  return testOrigin && testOrigin !== canonicalOrigin
    ? `${testOrigin}/merchant`
    : canonicalOrigin;
}
