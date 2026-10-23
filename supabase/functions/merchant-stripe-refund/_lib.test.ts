import { assertEquals } from "jsr:@std/assert@1";

import { findLiveRefund } from "./_lib.ts";

// Synthetic ids only.
function reply(status: number, body: unknown, calls: string[] = []) {
  return (input: string, init?: RequestInit) => {
    calls.push(`${init?.method} ${input} ${(init?.headers as Record<string, string>)["Stripe-Account"]}`);
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  };
}

Deno.test("ZOKY-149: an existing pending refund is found (not a failure)", async () => {
  const calls: string[] = [];
  const out = await findLiveRefund(reply(200, { data: [
    { id: "re_old", status: "failed" },
    { id: "re_auto", status: "requires_action" },
  ] }, calls), "sk_test_x", "acct_test_1", "pi_test_1");
  assertEquals(out, { id: "re_auto", status: "requires_action" });
  assertEquals(calls, ["GET https://api.stripe.com/v1/refunds?payment_intent=pi_test_1&limit=100 acct_test_1"]);
});

Deno.test("ZOKY-149: only failed/canceled refunds or a Stripe error -> null (keep the error)", async () => {
  assertEquals(await findLiveRefund(reply(200, { data: [{ id: "re_x", status: "canceled" }] }), "sk_test_x", "a", "pi"), null);
  assertEquals(await findLiveRefund(reply(500, {}), "sk_test_x", "a", "pi"), null);
  assertEquals(await findLiveRefund(() => Promise.reject(new TypeError("down")), "sk_test_x", "a", "pi"), null);
});
