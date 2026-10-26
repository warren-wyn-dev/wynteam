import assert from "node:assert/strict";
import test from "node:test";
import { merchantDefaultReturnPath } from "../lib/merchant-auth-return.ts";
import { consumeReturnPath, rememberReturnPath } from "../lib/return-to.ts";

function sessionStorage(t) {
  const previous = globalThis.window;
  const values = new Map();
  globalThis.window = { sessionStorage: {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
    removeItem: (key) => values.delete(key),
  } };
  t.after(() => { globalThis.window = previous; });
}

test("fresh Merchant root sign-in returns to its rolled-out home", (t) => {
  sessionStorage(t);
  rememberReturnPath("/"); // Shared Social return-path rules intentionally reject root.
  assert.equal(consumeReturnPath() ?? merchantDefaultReturnPath("merchant.wynos.online"), "/");
});

test("direct Merchant login does not change the default on other origins", () => {
  for (const host of ["wynos.online", "zoky.wynos.online", "food.wynos.online", "localhost", "merchant.wynos.online.attacker.test", "preview.vercel.app"]) {
    assert.equal(merchantDefaultReturnPath(host), "/merchant", host);
  }
});

test("explicit safe Merchant, callback and deep-link returns win over the new default", (t) => {
  sessionStorage(t);
  for (const path of ["/merchant/flutter?order=test", "/merchant?payments=return&store=test", "/merchant?payments=refresh&store=test", "/merchant/signup", "/merchant"] ) {
    rememberReturnPath(path);
    assert.equal(consumeReturnPath() ?? merchantDefaultReturnPath("merchant.wynos.online"), path);
  }
});
