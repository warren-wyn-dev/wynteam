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
 * Stripe-only payments (ZOKY 2026-10-22): the customer picks PromptPay or
 * card in ZOKY, and the Checkout session is limited to that one method so the
 * recorded `payment_method_types[0]` is the method actually offered.
 * `undefined` = the body had no method (older clients): keep the account's
 * payment-method configuration exactly as before.
 */
export type FoodCheckoutMethod = "promptpay" | "card";

export function parseCheckoutMethod(value: unknown): FoodCheckoutMethod | undefined | null {
  if (value === undefined || value === null) return undefined;
  if (value === "promptpay" || value === "card") return value;
  return null;
}

/**
 * food_payment_policy_public() as read by this function (service role).
 * true = Stripe-only is on; false = legacy. A database without the function
 * (PGRST202, or 42883 from Postgres) is legacy, as in the web. Any other
 * error = null: the caller must not guess, so a card session can never be
 * opened by mistake while the policy is on.
 */
export function stripeOnlyFromPolicyResult(result: { data: unknown; error: { code?: unknown } | null }): boolean | null {
  if (result.error) {
    const code = result.error.code;
    return code === "PGRST202" || code === "42883" ? false : null;
  }
  if (result.data === true) return true;
  const row = Array.isArray(result.data) ? result.data[0] : result.data;
  return Boolean(row && typeof row === "object" && (row as { stripe_only?: unknown }).stripe_only === true);
}

/**
 * PromptPay-only under the policy (Founder 2026-10-23): no method (older
 * clients) means PromptPay and card is refused. Policy off: unchanged.
 */
export function resolveCheckoutMethod(
  method: FoodCheckoutMethod | undefined,
  stripeOnly: boolean,
): { method: FoodCheckoutMethod | undefined; error?: undefined } | { method?: undefined; error: "promptpay_only" } {
  if (!stripeOnly) return { method };
  if (method === "card") return { error: "promptpay_only" };
  return { method: "promptpay" };
}

/** True when an existing session already offers exactly `method`. */
export function sessionMatchesMethod(session: Record<string, unknown>, method: FoodCheckoutMethod | undefined): boolean {
  if (!method) return true;
  const types = session.payment_method_types;
  return Array.isArray(types) && types.length === 1 && types[0] === method;
}

/**
 * Checkout `expires_at` (unix seconds). Stripe's minimum is 30 minutes after
 * creation, so this is 31-32 minutes away, bucketed to the minute: retries in
 * the same minute send identical parameters and stay idempotent.
 */
export function checkoutExpiresAt(nowMs: number): number {
  return Math.floor(nowMs / 60_000) * 60 + 32 * 60;
}

/**
 * Idempotency key for creating a session. It covers every parameter that can
 * differ between two requests for the same attempt (method and expiry), so a
 * retry never collides with an earlier request that had other parameters.
 */
export function checkoutIdempotencyKey(
  orderId: string,
  attempt: number,
  method: FoodCheckoutMethod | undefined,
  expiresAt: number,
): string {
  return `wynos-food-${orderId}-${attempt}-${method ?? "any"}-${expiresAt}`;
}

/**
 * food-stripe-cancel ledger note (`food_stripe_payments.last_error`). The
 * optional `reason` only changes this note; anything unknown keeps the
 * original note, so behaviour is the same for older clients.
 */
export function stripeCancelLedgerNote(reason: unknown): string {
  if (reason === "order_cancelled") return "Customer cancelled the order";
  return "Customer switched to manual transfer";
}
