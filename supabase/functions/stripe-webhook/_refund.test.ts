import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { normalizedGpFeeSatang, paidAfterCancelRefundParams } from "./_refund.ts";

Deno.test("refund with 0 GP leaves application fee unchanged", () => {
  const params = paidAfterCancelRefundParams("ord-1", "pi_1", 0);
  assertEquals(params.get("payment_intent"), "pi_1");
  assertEquals(params.has("refund_application_fee"), false);
  assertEquals(params.get("metadata[wynos_order_id]"), "ord-1");
  assertEquals(params.get("metadata[wynos_reason]"), "paid_after_cancel");
});

Deno.test("refund reverses application fee for collected GP", () => {
  const params = paidAfterCancelRefundParams("ord-2", "pi_2", 1410);
  assertEquals(params.get("refund_application_fee"), "true");
  assertEquals(params.get("reason"), "requested_by_customer");
});

Deno.test("amount handles Postgres bigint string and rejects invalid values", () => {
  assertEquals(normalizedGpFeeSatang("150"), 150);
  assertEquals(normalizedGpFeeSatang(null), 0);
  for (const bad of [-1, 3.25, "NaN", "bad", Infinity, Number.MAX_SAFE_INTEGER + 1]) {
    assertThrows(() => normalizedGpFeeSatang(bad), Error, "invalid_gp_fee_satang");
  }
});

Deno.test("refund IDs and fee must be valid", () => {
  assertThrows(() => paidAfterCancelRefundParams("", "pi_1", 0), Error, "missing_refund_identifier");
  assertThrows(() => paidAfterCancelRefundParams("ord-1", "", 0), Error, "missing_refund_identifier");
  assertThrows(() => paidAfterCancelRefundParams("ord-1", "pi_1", -1), Error, "invalid_gp_fee_satang");
});
