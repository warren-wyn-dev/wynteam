export const AUTO_REFUND_MARKER = "[AUTO_PAID_AFTER_CANCEL]";

/** Only a refund ID written by our own auto-refund path may resume GP booking. */
export function mayResumeAutomaticGpRefund(refundId: string | null, note: string | null): boolean {
  return Boolean(refundId && note === AUTO_REFUND_MARKER);
}

/**
 * Pure Stripe paid-after-cancel refund request assembly.
 * GP must be accounted for in satang; never silently drop an invalid fee.
 */
export function normalizedGpFeeSatang(value: unknown): number {
  const amount = Number(value ?? 0);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new Error("invalid_gp_fee_satang");
  }
  return amount;
}

export function paidAfterCancelRefundParams(
  orderId: string,
  paymentIntentId: string,
  gpFeeSatang: number,
): URLSearchParams {
  if (!orderId || !paymentIntentId) throw new Error("missing_refund_identifier");
  if (!Number.isSafeInteger(gpFeeSatang) || gpFeeSatang < 0) {
    throw new Error("invalid_gp_fee_satang");
  }

  const params = new URLSearchParams();
  params.set("payment_intent", paymentIntentId);
  params.set("reason", "requested_by_customer");
  if (gpFeeSatang > 0) params.set("refund_application_fee", "true");
  params.set("metadata[wynos_order_id]", orderId);
  params.set("metadata[wynos_reason]", "paid_after_cancel");
  return params;
}
