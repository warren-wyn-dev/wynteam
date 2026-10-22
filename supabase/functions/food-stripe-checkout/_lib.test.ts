import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  applicationFeeSatang,
  checkoutExpiresAt,
  checkoutIdempotencyKey,
  FOOD_WEB_ORIGIN,
  foodReturnOrigin,
  isFoodWebOrigin,
  parseCheckoutMethod,
  sessionMatchesMethod,
  stripeCancelLedgerNote,
} from "./_lib.ts";

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

Deno.test("Food web origins: ZOKY and legacy food are accepted (exact match)", () => {
  assertEquals(isFoodWebOrigin("https://zoky.wynos.online"), true);
  assertEquals(isFoodWebOrigin("https://food.wynos.online"), true);
});

Deno.test("Food web origins: look-alikes, other hosts and missing origins are refused", () => {
  for (const origin of [
    "https://zoky.wynos.online.evil.com",
    "https://evil.zoky.wynos.online",
    "https://zoky.wynos.online/",
    "https://zoky.wynos.online:443",
    "http://zoky.wynos.online",
    "https://ZOKY.wynos.online",
    "https://food.wynos.online.evil.com",
    "https://wynos.online",
    "https://merchant.wynos.online",
    "https://evil.com",
    "null",
    "",
    null,
    undefined,
  ]) {
    assertEquals(isFoodWebOrigin(origin), false, String(origin));
  }
});

Deno.test("Stripe return origin: allowlisted request origin, otherwise ZOKY", () => {
  assertEquals(FOOD_WEB_ORIGIN, "https://zoky.wynos.online");
  assertEquals(foodReturnOrigin("https://zoky.wynos.online"), "https://zoky.wynos.online");
  assertEquals(foodReturnOrigin("https://food.wynos.online"), "https://food.wynos.online");
  assertEquals(foodReturnOrigin("https://evil.com"), "https://zoky.wynos.online");
  assertEquals(foodReturnOrigin("https://zoky.wynos.online.evil.com"), "https://zoky.wynos.online");
  assertEquals(foodReturnOrigin("http://localhost:3000"), "https://zoky.wynos.online");
  assertEquals(foodReturnOrigin(null), "https://zoky.wynos.online");
});

Deno.test("checkout method: optional, promptpay or card only", () => {
  assertEquals(parseCheckoutMethod(undefined), undefined);
  assertEquals(parseCheckoutMethod(null), undefined);
  assertEquals(parseCheckoutMethod("promptpay"), "promptpay");
  assertEquals(parseCheckoutMethod("card"), "card");
  for (const bad of ["", "PromptPay", "bank_transfer", "card ", 1, true, ["card"], {}]) {
    assertEquals(parseCheckoutMethod(bad), null, JSON.stringify(bad));
  }
});

Deno.test("session reuse: only when it offers exactly the requested method", () => {
  assertEquals(sessionMatchesMethod({ payment_method_types: ["card", "promptpay"] }, undefined), true);
  assertEquals(sessionMatchesMethod({ payment_method_types: ["promptpay"] }, "promptpay"), true);
  assertEquals(sessionMatchesMethod({ payment_method_types: ["card"] }, "card"), true);
  assertEquals(sessionMatchesMethod({ payment_method_types: ["card"] }, "promptpay"), false);
  assertEquals(sessionMatchesMethod({ payment_method_types: ["card", "promptpay"] }, "card"), false);
  assertEquals(sessionMatchesMethod({}, "card"), false);
});

Deno.test("checkout expires_at: within Stripe's 30 min..24 h window, stable per minute", () => {
  const now = Date.UTC(2026, 9, 22, 10, 15, 42);
  const expiresAt = checkoutExpiresAt(now);
  const seconds = Math.floor(now / 1000);
  assertEquals(expiresAt - seconds >= 31 * 60, true);
  assertEquals(expiresAt - seconds <= 32 * 60, true);
  assertEquals(checkoutExpiresAt(Date.UTC(2026, 9, 22, 10, 15, 0)), expiresAt);
  assertEquals(checkoutExpiresAt(Date.UTC(2026, 9, 22, 10, 15, 59, 999)), expiresAt);
  assertEquals(checkoutExpiresAt(Date.UTC(2026, 9, 22, 10, 16, 0)), expiresAt + 60);
});

Deno.test("checkout idempotency key: differs by attempt, method and expiry", () => {
  const order = "11111111-1111-4111-8111-111111111111";
  const base = checkoutIdempotencyKey(order, 1, "card", 100);
  assertEquals(base, `wynos-food-${order}-1-card-100`);
  assertEquals(checkoutIdempotencyKey(order, 1, undefined, 100), `wynos-food-${order}-1-any-100`);
  assertEquals(new Set([
    base,
    checkoutIdempotencyKey(order, 2, "card", 100),
    checkoutIdempotencyKey(order, 1, "promptpay", 100),
    checkoutIdempotencyKey(order, 1, "card", 160),
  ]).size, 4);
});

Deno.test("cancel ledger note: reason only selects the note", () => {
  assertEquals(stripeCancelLedgerNote("order_cancelled"), "Customer cancelled the order");
  assertEquals(stripeCancelLedgerNote(undefined), "Customer switched to manual transfer");
  assertEquals(stripeCancelLedgerNote("anything"), "Customer switched to manual transfer");
  assertEquals(stripeCancelLedgerNote({ toString: () => "order_cancelled" }), "Customer switched to manual transfer");
});
