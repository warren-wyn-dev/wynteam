// ZOKY-149: when Stripe refuses a new refund (e.g. charge_already_refunded
// because the automatic refund worker or the Dashboard already asked for
// one), look for refunds that already exist before reporting a failure.
// A refund is adopted only when the live (not failed/canceled) refunds cover
// the full payment (D4/D6: full refunds only); a partial one is reported so
// a person checks it instead of the order claiming a full refund.
export type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;
export type LiveRefund =
  | { kind: "full"; id: string; status: string }
  | { kind: "partial"; refundedSatang: number };

/** null when there is no live refund, or when Stripe cannot be asked (the
 * caller then keeps its own error). */
export async function findLiveRefund(
  fetchFn: FetchFn,
  secret: string,
  account: string,
  paymentIntent: string,
  amountSatang: number,
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
    const live = list.filter((r) =>
      r && typeof r.id === "string" && typeof r.status === "string" && !["failed", "canceled"].includes(r.status)
    );
    if (live.length === 0) return null;
    const total = live.reduce((sum, r) => sum + (typeof r.amount === "number" && Number.isFinite(r.amount) ? r.amount : 0), 0);
    if (!(amountSatang > 0) || total < amountSatang) return { kind: "partial", refundedSatang: total };
    const pick = live.find((r) => r.status !== "succeeded") ?? live[0];
    return { kind: "full", id: pick.id as string, status: pick.status as string };
  } catch {
    return null;
  }
}
