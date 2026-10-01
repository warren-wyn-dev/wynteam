import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const auth = fs.readFileSync(new URL("../components/merchant/merchant-auth.tsx", import.meta.url), "utf8");
const merchantAccount = fs.readFileSync(new URL("../lib/merchant-account.ts", import.meta.url), "utf8");
const gate = fs.readFileSync(new URL("../components/merchant/merchant-route-gate.tsx", import.meta.url), "utf8");
const browser = fs.readFileSync(new URL("../lib/supabase/merchant-browser.ts", import.meta.url), "utf8");
const app = fs.readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");

test("Merchant uses a separate persisted auth session", () => {
  assert.match(browser, /wynos-merchant-auth-v1/);
  assert.match(app, /MerchantRouteGate/);
  assert.doesNotMatch(app, /DeveloperRouteGate/);
});

test("Merchant signup creates merchant-only identities", () => {
  assert.match(merchantAccount, /wynos_account_type:\s*"merchant"/);
  assert.match(auth, /บัญชี WYNOS Merchant แยกจากบัญชี WYNOS Social/);
  assert.doesNotMatch(auth, /ใช้บัญชี WYNOS เดียวกันได้/);
  assert.match(auth, /รองรับ Owner และ Staff หลายคน/);
});
