import { assertEquals, assertMatch, assertThrows } from "jsr:@std/assert@1";
import { buildPromptPayPayload, crc16Ccitt, promptPayProxy } from "./_lib.ts";

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
