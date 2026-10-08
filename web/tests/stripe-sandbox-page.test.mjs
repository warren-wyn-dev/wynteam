import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const page = readFileSync(new URL("../app/stripe-sandbox/page.tsx", import.meta.url), "utf8");

test("Sandbox checkout page is guarded by a dedicated flag and exact Supabase project URL", () => {
  assert.match(page, /NEXT_PUBLIC_WYNOS_STRIPE_SANDBOX/);
  assert.match(page, /pcatuxtenluqzjzzwsvl\.supabase\.co/);
  assert.match(page, /!ENABLED/);
});

test("Test checkout requires signed-in buyer, their own orders and Stripe URL", () => {
  assert.match(page, /\.eq\("buyer_id", userId\)/);
  assert.match(page, /client\.functions\.invoke\("food-stripe-checkout"/);
  assert.match(page, /url\.hostname !== "checkout\.stripe\.com"/);
  assert.match(page, /\["pending", "issue"\]/);
});

test("No Stripe API secret or live endpoint is embedded in the test page", () => {
  assert.doesNotMatch(page, /(?:sk|rk)_(?:test|live)_/);
  assert.doesNotMatch(page, /\/v1\/checkout\/sessions/);
  assert.doesNotMatch(page, /kqokpocajhfbidcxpvhh/);
});


test("Diagnostic UI never prints environment values or discloses secrets", () => {
  assert.match(page, /SANDBOX_FLAG_OK/);
  assert.match(page, /SANDBOX_URL_OK/);
  assert.match(page, /PUBLISHABLE_KEY_PRESENT/);
  assert.match(page, /replace\(\/\\\/\+\$\//);
  assert.match(page, /ตั้งค่าแล้ว/);
  assert.doesNotMatch(page, /process\.env\.STRIPE_SECRET_KEY/);
});
