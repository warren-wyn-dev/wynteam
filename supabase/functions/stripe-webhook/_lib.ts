// Pure mapping of Stripe refund events to food_apply_stripe_event states.
//
// ZOKY-153 / ZOKY-147: an order is marked refunded only when a Refund object
// itself reports `succeeded` for the full order amount (refund.created,
// refund.updated, charge.refund.updated). `charge.refunded` is recorded but
// never marks the order refunded: Stripe counts a refund that is still
// pending in `amount_refunded`, and a PromptPay refund stays pending until
// the customer gives Stripe a bank account (and may then fail). The
// automatic refund worker owns the final state of its own refunds.

export type RefundEventState = {
  state: "refunded" | "noop";
  refundId: string | null;
  amount: number | null;
};

const REFUND_OBJECT_EVENTS = new Set(["refund.created", "refund.updated", "charge.refund.updated"]);

function str(value: unknown) { return typeof value === "string" ? value : null; }
function num(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : null; }

export function isRefundEvent(eventType: string): boolean {
  return eventType === "charge.refunded" || eventType === "refund.failed" || REFUND_OBJECT_EVENTS.has(eventType);
}

/** True when the order total is needed to decide (a succeeded Refund object). */
export function refundEventNeedsOrderTotal(eventType: string, object: Record<string, unknown>): boolean {
  return REFUND_OBJECT_EVENTS.has(eventType) && object.status === "succeeded";
}

/** expectedSatang: the order total in satang (null when unknown). */
export function refundEventState(
  eventType: string,
  object: Record<string, unknown>,
  expectedSatang: number | null,
): RefundEventState {
  if (REFUND_OBJECT_EVENTS.has(eventType) && object.status === "succeeded") {
    const amount = num(object.amount);
    const full = expectedSatang != null && expectedSatang > 0 && amount === expectedSatang;
    return { state: full ? "refunded" : "noop", refundId: str(object.id), amount };
  }
  if (eventType === "refund.failed") return { state: "noop", refundId: str(object.id), amount: null };
  // charge.refunded, and refunds that are pending / requires_action / failed.
  return { state: "noop", refundId: null, amount: null };
}
