import assert from "node:assert/strict";

const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));

Deno.test("ZOKY-157: slip verification is refused under Stripe-only or an unreadable policy", () => {
  assert.match(source, /import \{ storePaymentPolicyRefusal \} from "\.\.\/food-payment-qr\/_lib\.ts";/);
  assert.match(source, /const refusal = storePaymentPolicyRefusal\(await admin\.rpc\("food_payment_policy_public"\)\);\s*if \(refusal\) return json\(\{ error: refusal\.error \}, refusal\.status\);/);
  const gate = source.indexOf("storePaymentPolicyRefusal(await admin.rpc");
  assert.ok(gate > source.indexOf("order.buyer_id !== user.id"), "ownership is checked first");
  assert.ok(gate < source.indexOf('.from("food-private")'), "the slip is never downloaded under the policy");
  assert.ok(gate < source.indexOf("https://api.slipok.com"), "SlipOK is never called under the policy");
  assert.ok(gate < source.indexOf('admin.rpc("food_record_payment_verification"'));
});
