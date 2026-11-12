import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

// Founder 2026-10-26: customers pay only by transfer to the store and attach a
// slip; the store confirms every slip. Stripe is paused, not removed.
const app = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
const customer = readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8");

test("customer app offers no Stripe checkout", () => {
  assert.doesNotMatch(app, /startFoodStripeCheckout|payWithStripe|จ่ายด้วยบัตร/);
  assert.doesNotMatch(app, /stripe_payments_enabled/);
});

test("slips wait for the store instead of automatic verification", () => {
  assert.doesNotMatch(customer, /functions\.invoke\("food-verify-slip"/);
  const submit = customer.slice(customer.indexOf("export async function submitFoodPayment"));
  assert.match(submit.slice(0, 600), /return \{ status: "manual_review", provider: "manual" \};/);
});

test("orders already sent to Stripe Checkout can still switch to a slip", () => {
  assert.match(app, /prepareFoodManualPayment\(client, order\.id\)/);
});
