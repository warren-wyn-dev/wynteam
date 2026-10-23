// Pure mapping of Stripe refund events to food_apply_stripe_event states.
//
// ZOKY-153 / ZOKY-147: an order is marked refunded only when a Refund object
// itself reports `succeeded` for the full order amount (refund.created,
// refund.updated, charge.refund.updated). `charge.refunded` is recorded but
// never marks the order refunded: Stripe counts a refund that is still
// pending in `amount_refunded`, and a PromptPay refund stays pending until
// the customer gives Stripe a bank account (and may then fail). The
// automatic refund worker owns the final state of its own refunds.
// ZOKY-154: the Refund must also belong to the order's own PaymentIntent
// (food_orders.stripe_payment_intent_id). A refund of a duplicate payment is
// recorded only; it never marks the order refunded while the first payment
// is still held.

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

/** The Refund's PaymentIntent id (string or expanded object). */
export function refundPaymentIntent(object: Record<string, unknown>): string | null {
  const value = object.payment_intent;
  if (typeof value === "string") return value || null;
  if (value && typeof value === "object") return str((value as Record<string, unknown>).id);
  return null;
}

/** True when the order total and PaymentIntent are needed to decide (a succeeded Refund object). */
export function refundEventNeedsOrderTotal(eventType: string, object: Record<string, unknown>): boolean {
  return REFUND_OBJECT_EVENTS.has(eventType) && object.status === "succeeded";
}

/** expectedSatang: the order total in satang (null when unknown);
 * orderPaymentIntent: food_orders.stripe_payment_intent_id (null when unknown). */
export function refundEventState(
  eventType: string,
  object: Record<string, unknown>,
  expectedSatang: number | null,
  orderPaymentIntent: string | null,
): RefundEventState {
  if (REFUND_OBJECT_EVENTS.has(eventType) && object.status === "succeeded") {
    const amount = num(object.amount);
    const full = expectedSatang != null && expectedSatang > 0 && amount === expectedSatang;
    const pi = refundPaymentIntent(object);
    const ownPayment = pi != null && orderPaymentIntent != null && pi === orderPaymentIntent;
    return { state: full && ownPayment ? "refunded" : "noop", refundId: str(object.id), amount };
  }
  if (eventType === "refund.failed") return { state: "noop", refundId: str(object.id), amount: null };
  // charge.refunded, and refunds that are pending / requires_action / failed.
  return { state: "noop", refundId: null, amount: null };
}
