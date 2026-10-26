import { assertEquals, assertMatch, assertThrows } from "jsr:@std/assert@1";
import { buildPromptPayPayload, crc16Ccitt, promptPayProxy, storePaymentPolicyRefusal } from "./_lib.ts";

Deno.test("PromptPay mobile proxy normalizes to Thai country format", () => {
  assertEquals(promptPayProxy("081-234-5678"), { tag: "01", value: "0066812345678" });
});

Deno.test("PromptPay accepts 13-digit national/tax IDs", () => {
  assertEquals(promptPayProxy("1-2345-67890-12-3"), { tag: "02", value: "1234567890123" });
});

Deno.test("PromptPay rejects unsupported IDs", () => {
  assertThrows(() => promptPayProxy("1234"));
});

Deno.test("PromptPay payload includes exact amount and a valid CRC", () => {
  const payload = buildPromptPayPayload("0812345678", 159);
  assertMatch(payload, /5406159\.00/);
  assertMatch(payload, /5303764/);
  assertMatch(payload, /5802TH/);
  const body = payload.slice(0, -4);
  assertEquals(payload.slice(-4), crc16Ccitt(body));
});

Deno.test("ZOKY-157: store QR/slips refused under Stripe-only; policy off or missing RPC keeps legacy", () => {
  const refused = { status: 409, error: "stripe_only_payments" };
  assertEquals(storePaymentPolicyRefusal({ data: true, error: null }), refused);
  assertEquals(storePaymentPolicyRefusal({ data: [{ stripe_only: true }], error: null }), refused);
  assertEquals(storePaymentPolicyRefusal({ data: { stripe_only: true }, error: null }), refused);
  // Policy NULL/off before activation: legacy unchanged.
  assertEquals(storePaymentPolicyRefusal({ data: false, error: null }), null);
  assertEquals(storePaymentPolicyRefusal({ data: null, error: null }), null);
  assertEquals(storePaymentPolicyRefusal({ data: "true", error: null }), null);
  // Function not deployed yet (migration not applied): legacy.
  assertEquals(storePaymentPolicyRefusal({ data: null, error: { code: "PGRST202" } }), null);
  assertEquals(storePaymentPolicyRefusal({ data: null, error: { code: "42883" } }), null);
});

Deno.test("ZOKY-157: any other policy error fails closed (503)", () => {
  const closed = { status: 503, error: "payment_policy_unavailable" };
  for (const error of [{ code: "57014" }, { code: "42501" }, { code: "" }, { code: undefined }, {}]) {
    assertEquals(storePaymentPolicyRefusal({ data: null, error }), closed);
  }
});
