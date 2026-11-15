import assert from "node:assert/strict";

const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));

Deno.test("ZOKY-157: the policy is checked before the store's PromptPay is read", () => {
  assert.match(source, /const refusal = storePaymentPolicyRefusal\(await admin\.rpc\("food_payment_policy_public"\)\);\s*if \(refusal\) return json\(\{ error: refusal\.error \}, refusal\.status\);/);
  const gate = source.indexOf("storePaymentPolicyRefusal(await admin.rpc");
  assert.ok(gate > source.indexOf("order.buyer_id !== user.id"), "ownership is checked first");
  assert.ok(gate < source.indexOf('.from("food_stores")'), "no store payment details are read under the policy");
  assert.ok(gate < source.indexOf("buildPromptPayPayload(store.promptpay_id"));
});
