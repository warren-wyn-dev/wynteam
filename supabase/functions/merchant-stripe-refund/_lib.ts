export function refundResponseState(status: unknown): "pending" | "failed" {
  if (status === "failed" || status === "canceled") return "failed";
  if (status === "pending" || status === "requires_action" || status === "succeeded") return "pending";
  throw new Error("unknown_refund_status");
}

/** A customer refund alone does not prove that the separate GP fee was returned. */
export function verifiedApplicationFeeRefund(
  fee: Record<string, unknown>,
  expectedSatang: number,
  accountId: string,
  chargeId: string,
): number | null {
  if (!Number.isSafeInteger(expectedSatang) || expectedSatang <= 0) return null;
  if (typeof fee.id !== "string" || !fee.id.startsWith("fee_")) return null;
  if (fee.account !== accountId || fee.charge !== chargeId || fee.currency !== "thb") return null;
  if (fee.amount !== expectedSatang || fee.amount_refunded !== expectedSatang) return null;
  return expectedSatang;
}
