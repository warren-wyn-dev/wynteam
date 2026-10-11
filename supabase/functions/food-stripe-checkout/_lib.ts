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
