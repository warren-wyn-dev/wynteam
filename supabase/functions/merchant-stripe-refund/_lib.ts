// ZOKY-149: when Stripe refuses a new refund (e.g. charge_already_refunded
// because the automatic refund worker or the Dashboard already asked for
// one), look for a refund that already exists before reporting a failure.
export type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;
export type LiveRefund = { id: string; status: string };

/** First refund for the PaymentIntent that is not failed/canceled, or null
 * (also null when Stripe cannot be asked; the caller then keeps its error). */
export async function findLiveRefund(
  fetchFn: FetchFn,
  secret: string,
  account: string,
  paymentIntent: string,
): Promise<LiveRefund | null> {
  try {
    const response = await fetchFn(
      `https://api.stripe.com/v1/refunds?payment_intent=${encodeURIComponent(paymentIntent)}&limit=100`,
      {
        method: "GET",
        headers: { Authorization: `Basic ${btoa(secret + ":")}`, "Stripe-Account": account },
        signal: AbortSignal.timeout(7500),
      },
    );
    if (!response.ok) return null;
    const body = await response.json().catch(() => ({})) as { data?: unknown };
    const list = Array.isArray(body.data) ? body.data as Record<string, unknown>[] : [];
    const live = list.find((r) =>
      r && typeof r.id === "string" && typeof r.status === "string" && !["failed", "canceled"].includes(r.status)
    );
    return live ? { id: live.id as string, status: live.status as string } : null;
  } catch {
    return null;
  }
}
