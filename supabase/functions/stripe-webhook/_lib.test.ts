import { assertEquals } from "jsr:@std/assert@1";

import {
  isRefundEvent,
  refundEventNeedsOrderTotal,
  refundEventState,
  refundPaymentIntent,
  refundRecheckPaymentIntent,
} from "./_lib.ts";

// Synthetic ids only.
Deno.test("ZOKY-153: charge.refunded never marks the order refunded (pending refunds count in amount_refunded)", () => {
  const charge = { id: "ch_test_1", amount: 12000, amount_refunded: 12000, refunded: true };
  assertEquals(isRefundEvent("charge.refunded"), true);
  assertEquals(refundEventNeedsOrderTotal("charge.refunded", charge), false);
  assertEquals(refundEventState("charge.refunded", charge, 12000, "pi_test_1"), { state: "noop", refundId: null, amount: null });
});

Deno.test("a succeeded full Refund marks refunded (refund.created / refund.updated / charge.refund.updated)", () => {
  const refund = { id: "re_test_1", status: "succeeded", amount: 12000, payment_intent: "pi_test_1" };
  for (const type of ["refund.created", "refund.updated", "charge.refund.updated"]) {
    assertEquals(refundEventNeedsOrderTotal(type, refund), true);
    assertEquals(refundEventState(type, refund, 12000, "pi_test_1"), { state: "refunded", refundId: "re_test_1", amount: 12000 });
  }
  // Expanded payment_intent object.
  assertEquals(refundPaymentIntent({ payment_intent: { id: "pi_test_x" } }), "pi_test_x");
});

Deno.test("partial, unknown-total, pending, requires_action and failed refunds are noop", () => {
  assertEquals(refundEventState("refund.updated", { id: "re_p", status: "succeeded", amount: 5000 }, 12000, "pi").state, "noop");
  assertEquals(refundEventState("refund.updated", { id: "re_u", status: "succeeded", amount: 12000 }, null, "pi").state, "noop");
  assertEquals(refundEventState("refund.updated", { id: "re_z", status: "succeeded", amount: 0 }, 0, "pi").state, "noop");
  for (const status of ["pending", "requires_action", "failed", "canceled"]) {
    const refund = { id: "re_w", status, amount: 12000 };
    assertEquals(refundEventNeedsOrderTotal("refund.updated", refund), false);
    assertEquals(refundEventState("refund.updated", refund, 12000, "pi"), { state: "noop", refundId: null, amount: null });
  }
  assertEquals(refundEventState("refund.failed", { id: "re_f", status: "failed" }, 12000, "pi"),
    { state: "noop", refundId: "re_f", amount: null });
  assertEquals(isRefundEvent("checkout.session.completed"), false);
});

Deno.test("ZOKY-154: a full refund of ANOTHER PaymentIntent (duplicate payment) never marks the order refunded", () => {
  const dup = { id: "re_dup", status: "succeeded", amount: 12000, payment_intent: "pi_test_dup" };
  assertEquals(refundEventState("refund.updated", dup, 12000, "pi_test_first"), { state: "noop", refundId: "re_dup", amount: 12000 });
  // Unknown order PaymentIntent or a refund without one: noop (the worker owns its refunds).
  assertEquals(refundEventState("refund.updated", dup, 12000, null).state, "noop");
  assertEquals(refundEventState("refund.updated", { id: "re_x", status: "succeeded", amount: 12000 }, 12000, "pi_test_first").state, "noop");
  // The first payment's own refund still resolves the order.
  assertEquals(refundEventState("refund.updated", { ...dup, payment_intent: "pi_test_first" }, 12000, "pi_test_first").state, "refunded");
});

Deno.test("ZOKY-156: a succeeded refund of a duplicate payment rechecks the duplicate's review job, order stays noop", () => {
  const dup = { id: "re_dup", status: "succeeded", amount: 12000, payment_intent: "pi_test_dup" };
  for (const type of ["refund.created", "refund.updated", "charge.refund.updated"]) {
    assertEquals(refundEventState(type, dup, 12000, "pi_test_first").state, "noop");
    assertEquals(refundRecheckPaymentIntent(type, dup), "pi_test_dup");
  }
  assertEquals(refundRecheckPaymentIntent("refund.updated", { ...dup, payment_intent: { id: "pi_test_dup" } }), "pi_test_dup");
});

Deno.test("ZOKY-156: the remainder of a partial refund rechecks the parked job; pending/failed/charge.refunded do not", () => {
  const rest = { id: "re_rest", status: "succeeded", amount: 7000, payment_intent: "pi_test_first" };
  assertEquals(refundEventState("refund.updated", rest, 12000, "pi_test_first").state, "noop");
  assertEquals(refundRecheckPaymentIntent("refund.updated", rest), "pi_test_first");
  // A full own refund marks refunded and also rechecks a parked job.
  assertEquals(refundRecheckPaymentIntent("refund.updated", { ...rest, amount: 12000 }), "pi_test_first");
  for (const status of ["pending", "requires_action", "failed", "canceled"]) {
    assertEquals(refundRecheckPaymentIntent("refund.updated", { ...rest, status }), null);
  }
  assertEquals(refundRecheckPaymentIntent("charge.refunded", { id: "ch_1", payment_intent: "pi_test_first", amount_refunded: 12000 }), null);
  assertEquals(refundRecheckPaymentIntent("refund.failed", { id: "re_f", status: "failed", payment_intent: "pi_test_first" }), null);
  assertEquals(refundRecheckPaymentIntent("refund.updated", { id: "re_n", status: "succeeded", amount: 7000 }), null);
});
