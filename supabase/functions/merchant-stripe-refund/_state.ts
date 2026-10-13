/**
 * Mark ambiguous Stripe results for a human-safe reconciliation path.
 * Never reissue a merchant refund just because a network response is missing.
 */
export const REFUND_RECONCILE_MARKER = "[RECONCILE]";

export function requiresRefundReconciliation(
  refundStatus: string | null | undefined,
  refundNote: string | null | undefined,
): boolean {
  return refundStatus === "pending" && Boolean(refundNote?.startsWith(REFUND_RECONCILE_MARKER));
}
