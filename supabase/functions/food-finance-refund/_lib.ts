export type RefundJob = { request_id: string; order_id: string; lease: string; refund_id: string | null;
  food_satang: number; delivery_satang: number; gp_satang: number; payment_intent_id: string; stripe_account_id: string; livemode: boolean; attempts?: number; created_at?: string };
export async function executeRefund(job: RefundJob, secret: string, request: typeof fetch = fetch) {
  const mode = /^(?:sk|rk)_test_/.test(secret) ? false : /^(?:sk|rk)_live_/.test(secret) ? true : null;
  const amount = Number(job.food_satang) + Number(job.delivery_satang), gp = Number(job.gp_satang);
  if (mode === null || mode !== job.livemode || !Number.isSafeInteger(amount) || amount <= 0
      || !Number.isSafeInteger(gp) || gp < 0 || gp > amount
      || !/^pi_[A-Za-z0-9]+$/.test(job.payment_intent_id) || !/^acct_[A-Za-z0-9]+$/.test(job.stripe_account_id)) throw Error("invalid_refund_job");
  const call = async (path: string, method: string, account: string | null, params?: URLSearchParams, suffix = "payment") => {
    const response = await request(`https://api.stripe.com/v1/${path}`, { method,
      headers: { Authorization: `Basic ${btoa(secret + ":")}`, ...(account ? { "Stripe-Account": account } : {}),
        "Content-Type": "application/x-www-form-urlencoded", "Idempotency-Key": `zoky-refund-${job.request_id}-${suffix}` },
      ...(params ? { body: params } : {}), redirect: "error", signal: AbortSignal.timeout(7500) });
    if (!response.ok) throw Error("provider_refund_request_failed");
    return await response.json() as Record<string, unknown>;
  };
  if (job.refund_id && !/^re_[A-Za-z0-9]+$/.test(job.refund_id)) throw Error("invalid_refund_id");
  const params = new URLSearchParams({ payment_intent: job.payment_intent_id, amount: String(amount), reason: "requested_by_customer",
    "metadata[wynos_order_id]": job.order_id, "metadata[wynos_refund_request_id]": job.request_id });
  const old = job.created_at ? Date.now() - new Date(job.created_at).getTime() > 20 * 3600000 : false;
  let recovered: Record<string, unknown> | undefined;
  if (!job.refund_id && (Number(job.attempts) > 1 || old)) {
    const list = await call(`refunds?payment_intent=${job.payment_intent_id}&limit=100`, "GET", job.stripe_account_id);
    recovered = (Array.isArray(list.data) ? list.data : []).find((r) => (r as { metadata?: Record<string, string> }).metadata?.wynos_refund_request_id === job.request_id) as Record<string, unknown> | undefined;
    if (!recovered && (old || list.has_more === true)) throw Error("refund_reconciliation_required");
  }
  const refund = recovered ?? await call(job.refund_id ? `refunds/${job.refund_id}` : "refunds", job.refund_id ? "GET" : "POST", job.stripe_account_id, job.refund_id ? undefined : params);
  if (typeof refund.id !== "string" || !/^re_[A-Za-z0-9]+$/.test(refund.id) || refund.payment_intent !== job.payment_intent_id
      || refund.currency !== "thb" || refund.amount !== amount) throw Error("refund_response_mismatch");
  if (refund.status !== "succeeded") return { id: refund.id, feeId: null, state: ["pending"].includes(String(refund.status)) ? "pending" : "needs_review" };
  let feeId: string | null = null;
  if (gp > 0) {
    if (typeof refund.charge !== "string" || !/^ch_[A-Za-z0-9]+$/.test(refund.charge)) throw Error("refund_charge_missing");
    const charge = await call(`charges/${refund.charge}`, "GET", job.stripe_account_id);
    if (charge.payment_intent !== job.payment_intent_id || typeof charge.application_fee !== "string" || !/^fee_[A-Za-z0-9]+$/.test(charge.application_fee)) throw Error("application_fee_missing");
    const fee = await call(`application_fees/${charge.application_fee}`, "GET", null);
    if (fee.account !== job.stripe_account_id || fee.charge !== refund.charge || fee.currency !== "thb") throw Error("application_fee_mismatch");
    let recoveredFee: Record<string, unknown> | undefined;
    if (Number(job.attempts) > 1 || old) {
      const list = await call(`application_fees/${charge.application_fee}/refunds?limit=100`, "GET", null);
      recoveredFee = (Array.isArray(list.data) ? list.data : []).find((r) => (r as { metadata?: Record<string, string> }).metadata?.wynos_refund_request_id === job.request_id) as Record<string, unknown> | undefined;
      if (!recoveredFee && (old || list.has_more === true)) throw Error("fee_reconciliation_required");
    }
    const returned = recoveredFee ?? await call(`application_fees/${charge.application_fee}/refunds`, "POST", null,
      new URLSearchParams({ amount: String(gp), "metadata[wynos_refund_request_id]": job.request_id }), "gp");
    if (returned.fee !== charge.application_fee || returned.amount !== gp || typeof returned.id !== "string" || !/^fr_[A-Za-z0-9]+$/.test(returned.id)) throw Error("fee_refund_mismatch");
    feeId = returned.id;
  }
  return { id: refund.id, feeId, state: "succeeded" };
}
