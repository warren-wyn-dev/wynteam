import { assertEquals } from "jsr:@std/assert@1";

import { findLiveRefund } from "./_lib.ts";

// Synthetic ids only.
function reply(status: number, body: unknown, calls: string[] = []) {
  return (input: string, init?: RequestInit) => {
    calls.push(`${init?.method} ${input} ${(init?.headers as Record<string, string>)["Stripe-Account"]}`);
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  };
}

Deno.test("ZOKY-149: an existing full pending refund is adopted (not a failure)", async () => {
  const calls: string[] = [];
  const out = await findLiveRefund(reply(200, { data: [
    { id: "re_old", status: "failed", amount: 12000 },
    { id: "re_auto", status: "requires_action", amount: 12000 },
  ] }, calls), "sk_test_x", "acct_test_1", "pi_test_1", 12000);
  assertEquals(out, { kind: "full", id: "re_auto", status: "requires_action" });
  assertEquals(calls, ["GET https://api.stripe.com/v1/refunds?payment_intent=pi_test_1&limit=100 acct_test_1"]);
});

Deno.test("PR #1231: a partial live refund is never adopted as a full refund", async () => {
  assertEquals(await findLiveRefund(reply(200, { data: [{ id: "re_part", status: "succeeded", amount: 5000 }] }),
    "sk_test_x", "a", "pi", 12000), { kind: "partial", refundedSatang: 5000 });
  // Missing amounts or an unknown payment amount are not a full refund either.
  assertEquals(await findLiveRefund(reply(200, { data: [{ id: "re_n", status: "pending" }] }),
    "sk_test_x", "a", "pi", 12000), { kind: "partial", refundedSatang: 0 });
  assertEquals((await findLiveRefund(reply(200, { data: [{ id: "re_f", status: "succeeded", amount: 12000 }] }),
    "sk_test_x", "a", "pi", 0))?.kind, "partial");
  // Two live refunds that together cover the payment are adopted.
  assertEquals(await findLiveRefund(reply(200, { data: [
    { id: "re_a", status: "succeeded", amount: 7000 }, { id: "re_b", status: "pending", amount: 5000 },
  ] }), "sk_test_x", "a", "pi", 12000), { kind: "full", id: "re_b", status: "pending" });
});

Deno.test("ZOKY-149: only failed/canceled refunds or a Stripe error -> null (keep the error)", async () => {
  assertEquals(await findLiveRefund(reply(200, { data: [{ id: "re_x", status: "canceled", amount: 12000 }] }), "sk_test_x", "a", "pi", 12000), null);
  assertEquals(await findLiveRefund(reply(500, {}), "sk_test_x", "a", "pi", 12000), null);
  assertEquals(await findLiveRefund(() => Promise.reject(new TypeError("down")), "sk_test_x", "a", "pi", 12000), null);
});
