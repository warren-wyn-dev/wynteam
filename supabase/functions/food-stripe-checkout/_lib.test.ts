import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { applicationFeeSatang } from "./_lib.ts";

Deno.test("no GP: fee is 0", () => {
  assertEquals(applicationFeeSatang({ gp_satang: 0, total_satang: 12000 }, 12000), 0);
});

Deno.test("GP is passed through in satang", () => {
  assertEquals(applicationFeeSatang({ gp_satang: 1410, total_satang: 11000 }, 11000), 1410);
});

Deno.test("GP equal to the whole amount is allowed", () => {
  assertEquals(applicationFeeSatang({ gp_satang: 9000, total_satang: 9000 }, 9000), 9000);
});

Deno.test("missing or invalid quotes are refused", () => {
  assertThrows(() => applicationFeeSatang(null, 100), Error, "gp_quote_missing");
  assertThrows(() => applicationFeeSatang({ gp_satang: -1, total_satang: 100 }, 100), Error, "gp_quote_invalid");
  assertThrows(() => applicationFeeSatang({ gp_satang: 1.5, total_satang: 100 }, 100), Error, "gp_quote_invalid");
  assertThrows(() => applicationFeeSatang({ gp_satang: "x", total_satang: 100 }, 100), Error, "gp_quote_invalid");
});

Deno.test("quote for a different amount is refused", () => {
  assertThrows(() => applicationFeeSatang({ gp_satang: 10, total_satang: 101 }, 100), Error, "gp_quote_amount_mismatch");
});

Deno.test("fee above the amount is refused", () => {
  assertThrows(() => applicationFeeSatang({ gp_satang: 101, total_satang: 100 }, 100), Error, "gp_quote_exceeds_amount");
});
