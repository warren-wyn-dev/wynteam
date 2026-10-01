import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const auth = fs.readFileSync(new URL("../components/merchant/merchant-auth.tsx", import.meta.url), "utf8");
const app = fs.readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");

test("Merchant reuses the normal WYNOS auth session", () => {
  assert.match(auth, /getSupabaseBrowserClient/);
  assert.match(auth, /signInWithEmail/);
  assert.match(app, /DeveloperRouteGate/);
  assert.match(app, /signedOutPath="\/merchant\/login"/);
  assert.doesNotMatch(app, /MerchantRouteGate/);
});

test("Merchant keeps store tenancy separate from the shared WYNOS identity", () => {
  assert.match(auth, /ใช้บัญชี WYNOS เดิมได้/);
  assert.match(auth, /ร้านมี Merchant Account ของตัวเอง/);
  assert.match(auth, /รองรับ Owner และ Staff หลายคน/);
  assert.doesNotMatch(auth, /signUpMerchantWithEmail/);
  assert.doesNotMatch(auth, /บัญชี WYNOS Merchant แยกจากบัญชี WYNOS Social/);
});
