export type RefundTarget = { orderId: string; paymentIntent: string; account: string; amount: number; fee: number; livemode: boolean; refundId: string | null };

/** Same immutable request and idempotency key as the merchant fallback. */
export function refundParams(target: RefundTarget) {
  const params = new URLSearchParams();
  params.set("payment_intent", target.paymentIntent);
  params.set("reason", "requested_by_customer");
  if (target.fee > 0) params.set("refund_application_fee", "true");
  params.set("metadata[wynos_order_id]", target.orderId);
  return params;
}

export async function processRefund(target: RefundTarget, secret: string, request: typeof fetch = fetch) {
  const mode = /^(?:sk|rk)_test_/.test(secret) ? false : /^(?:sk|rk)_live_/.test(secret) ? true : null;
  if (mode === null || mode !== target.livemode) throw new Error("stripe_environment_mismatch");
  if (!/^acct_[A-Za-z0-9]+$/.test(target.account) || !/^pi_[A-Za-z0-9]+$/.test(target.paymentIntent)
      || !Number.isSafeInteger(target.amount) || target.amount <= 0
      || !Number.isSafeInteger(target.fee) || target.fee < 0 || target.fee > target.amount) throw new Error("invalid_refund_target");
  if (target.refundId && !/^re_[A-Za-z0-9]+$/.test(target.refundId)) throw new Error("invalid_refund_id");
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(secret + ":")}`, "Stripe-Account": target.account,
    "Content-Type": "application/x-www-form-urlencoded",
    "Idempotency-Key": `wynos-refund-${target.orderId}`,
  };
  const response = await request("https://api.stripe.com/v1/refunds" + (target.refundId ? `/${encodeURIComponent(target.refundId)}` : ""), {
    method: target.refundId ? "GET" : "POST", headers,
    ...(target.refundId ? {} : { body: refundParams(target) }),
    signal: AbortSignal.timeout(7500), redirect: "error",
  });
  if (!response.ok) throw new Error(response.status >= 500 || response.status === 429 ? "stripe_transient" : "stripe_rejected");
  const result = await response.json() as Record<string, unknown>;
  if (typeof result.id !== "string" || !/^re_[A-Za-z0-9]+$/.test(result.id)
      || result.payment_intent !== target.paymentIntent || result.amount !== target.amount
      || result.currency !== "thb" || (typeof result.livemode === "boolean" && result.livemode !== mode)) throw new Error("refund_response_mismatch");
  const status = result.status;
  if (status !== "succeeded" && status !== "pending" && status !== "requires_action" && status !== "failed" && status !== "canceled") throw new Error("refund_status_unknown");
  if (status === "succeeded" && target.fee > 0) {
    // A Dashboard refund might have returned the payment without its GP.
    // Verify the platform fee itself before reversing our GP ledger.
    if (typeof result.charge !== "string" || !/^ch_[A-Za-z0-9]+$/.test(result.charge)) throw new Error("refund_charge_missing");
    const chargeResponse = await request(`https://api.stripe.com/v1/charges/${result.charge}`, {
      headers, redirect: "error", signal: AbortSignal.timeout(5000),
    });
    if (!chargeResponse.ok) throw new Error("fee_check_failed");
    const charge = await chargeResponse.json() as Record<string, unknown>;
    const feeId = charge.application_fee;
    if (typeof feeId !== "string" || !/^fee_[A-Za-z0-9]+$/.test(feeId)) throw new Error("fee_check_failed");
    const feeResponse = await request(`https://api.stripe.com/v1/application_fees/${feeId}`, {
      headers: { Authorization: headers.Authorization }, redirect: "error", signal: AbortSignal.timeout(5000),
    });
    if (!feeResponse.ok) throw new Error("fee_check_failed");
    const fee = await feeResponse.json() as Record<string, unknown>;
    if (fee.account !== target.account || fee.charge !== result.charge || fee.currency !== "thb"
        || fee.amount !== target.fee || typeof fee.amount_refunded !== "number" || fee.amount_refunded < target.fee) throw new Error("fee_not_returned");
  }
  return { id: result.id, status };
}
