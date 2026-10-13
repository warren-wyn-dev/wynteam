import assert from "node:assert/strict";
import { test } from "node:test";

import { refundResponseState, verifiedApplicationFeeRefund } from "./_lib.ts";

test("pending and action-required refunds stay pending", () => {
  assert.equal(refundResponseState("pending"), "pending");
  assert.equal(refundResponseState("requires_action"), "pending");
});

test("successful API response leaves the final order status to the webhook", () => {
  assert.equal(refundResponseState("succeeded"), "pending");
});

test("provider failures and cancellation are not shown as successful requests", () => {
  assert.equal(refundResponseState("failed"), "failed");
  assert.equal(refundResponseState("canceled"), "failed");
});

test("missing or new provider status cannot be mistaken for success", () => {
  for (const status of [undefined, null, "", "unknown", 200]) {
    assert.throws(() => refundResponseState(status), /unknown_refund_status/);
  }
});

const fee = { id: "fee_test", account: "acct_test", charge: "ch_test", currency: "thb", amount: 1500, amount_refunded: 1500 };

test("full GP refund is recorded only from a verified application fee", () => {
  assert.equal(verifiedApplicationFeeRefund(fee, 1500, "acct_test", "ch_test"), 1500);
});

test("pending, missing and partial GP refund evidence cannot credit the full fee", () => {
  for (const amount_refunded of [undefined, 0, 500, "1500", 1500.1]) {
    assert.equal(verifiedApplicationFeeRefund({ ...fee, amount_refunded }, 1500, "acct_test", "ch_test"), null);
  }
  assert.equal(verifiedApplicationFeeRefund({}, 1500, "acct_test", "ch_test"), null);
});

test("fee evidence is pinned to the charged account, charge, amount and currency", () => {
  for (const change of [{ account: "acct_other" }, { charge: "ch_other" }, { currency: "usd" }, { amount: 1600 }, { id: "re_other" }]) {
    assert.equal(verifiedApplicationFeeRefund({ ...fee, ...change }, 1500, "acct_test", "ch_test"), null);
  }
});

test("invalid ledger amounts never produce GP credits", () => {
  for (const expected of [0, -1, 1500.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assert.equal(verifiedApplicationFeeRefund(fee, expected, "acct_test", "ch_test"), null);
  }
});
