import { assertEquals } from "jsr:@std/assert@1";
import { REFUND_RECONCILE_MARKER, requiresRefundReconciliation } from "./_state.ts";

Deno.test("ambiguous Stripe outcome blocks repeated refunds", () => {
  assertEquals(requiresRefundReconciliation("pending", `${REFUND_RECONCILE_MARKER} ยังยืนยันผลไม่ได้`), true);
  assertEquals(requiresRefundReconciliation("pending", "Refund pending (normal flow)"), false);
  assertEquals(requiresRefundReconciliation("failed", `${REFUND_RECONCILE_MARKER} old marker`), false);
  assertEquals(requiresRefundReconciliation("refunded", `${REFUND_RECONCILE_MARKER} old marker`), false);
  assertEquals(requiresRefundReconciliation("pending", null), false);
});
