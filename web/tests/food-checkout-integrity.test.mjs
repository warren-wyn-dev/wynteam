import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import ts from "typescript";
import { checkoutIntentKey, checkoutIntentUsesV3, clearCheckoutIntent } from "../lib/food-checkout-intent.ts";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const exports = {};
vm.runInNewContext(compiled, { exports, require: () => ({}), Set, Map, Date, Number, String, Error, console });

function client(replies) {
  const calls = [];
  return { calls, rpc: async (name, params) => { calls.push({ name, params }); return replies(name, params); } };
}
const input = { recipientName: "Test", recipientPhone: "000", shippingAddress: "fixture",
  items: [{ menu_item_id: "menu", quantity: 1 }], location: null };

test("the same checkout intent reuses its key; successful checkout clears it", async () => {
  const values = new Map();
  const storage = { getItem: (k) => values.get(k), setItem: (k,v) => values.set(k,v), removeItem: (k) => values.delete(k) };
  const a = await checkoutIntentKey("buyer", input, storage);
  assert.equal(await checkoutIntentKey("buyer", input, storage), a);
  assert.notEqual(await checkoutIntentKey("other", input, storage), a);
  assert.ok(![...values.values()].some((v) => v.includes("fixture")), "no raw address is persisted");
  clearCheckoutIntent("buyer", storage);
  assert.notEqual(await checkoutIntentKey("buyer", input, storage), a);
});
test("unknown outcomes retain one key across refresh, quote and cart changes", async () => {
  const denied = { getItem(){ throw Error(); }, setItem(){ throw Error(); }, removeItem(){ throw Error(); } };
  const a = await checkoutIntentKey("private", input, denied);
  assert.equal(await checkoutIntentKey("private", input, denied), a);
  assert.equal(await checkoutIntentKey("private", { ...input, items: [],expectedTotal:100 }, denied), a);
});
test("v3 quote reads fee and authoritative total without applying frontend arithmetic", async () => {
  const api = client((name) => name === "food_checkout_features"
    ? { data: { checkout_v3: true } }
    : { data: { subtotal: 59.99, small_order_fee: 15, total: 84.99, pricing_rule_version: "food_checkout_v3" } });
  const quote = await exports.quoteFoodCustomerOrder(api, "store", input.items);
  assert.equal(quote.total, 84.99); assert.equal(quote.small_order_fee,15);
  assert.equal(api.calls[1].name, "food_quote_order_v3");
});
test("old database lacking feature RPC keeps legacy quote; outages do not silently downgrade", async () => {
  const old = client((name) => name === "food_checkout_features"
    ? { error: { code: "PGRST202", message: "missing" } } : { data: { total: 100 } });
  await exports.quoteFoodCustomerOrder(old, "store", input.items);
  assert.equal(old.calls[1].name,"food_quote_order");
  const down = client(() => ({ error: { code: "NETWORK", message: "network down" } }));
  await assert.rejects(exports.quoteFoodCustomerOrder(down, "store", input.items), /network down/);
  assert.equal(down.calls.length,1);
});
test("v3 creation carries same intent + displayed quote, never retries via legacy RPC", async () => {
  const api = client((name) => name === "food_resolve_checkout_request" ? { data:null } : ({ error: { message: "lost response" } }));
  await assert.rejects(exports.createFoodCustomerOrder(api,"store",{ ...input,
    pricingRuleVersion: "food_checkout_v3",idempotencyKey:"key",expectedTotal:84.99 }),/lost response/);
  assert.equal(api.calls.length,2);
  assert.equal(api.calls[1].name,"food_create_order_v3");
  assert.equal(api.calls[1].params.p_expected_total,84.99);
  assert.equal(api.calls[1].params.p_idempotency_key,"key");
});

test("lost reply followed by repricing resolves the already committed order, never creates a second", async () => {
  const key = await checkoutIntentKey("lost-response", {...input,expectedTotal:60},null);
  assert.equal(await checkoutIntentKey("lost-response",{...input,expectedTotal:100},null),key);
  const api = client((name) => {
    assert.equal(name,"food_resolve_checkout_request");
    return { data:"original-order" };
  });
  assert.equal(await exports.createFoodCustomerOrder(api,"store",{...input,pricingRuleVersion:"food_checkout_v3",expectedTotal:100,idempotencyKey:key}),"original-order");
  assert.equal(api.calls.length,1);
});

test("feature disabled after lost reply cannot downgrade unresolved v3 intent to legacy", async () => {
  const key = await checkoutIntentKey("disabled",{...input,pricingRuleVersion:"food_checkout_v3"},null);
  assert.equal(await checkoutIntentKey("disabled",{...input,pricingRuleVersion:null},null),key);
  assert.equal(checkoutIntentUsesV3("disabled",null),true);
  const api = client((name) => { assert.equal(name,"food_resolve_checkout_request"); return {data:"existing-order"}; });
  assert.equal(await exports.createFoodCustomerOrder(api,"store",{...input,pricingRuleVersion:null,idempotencyKey:key,resolveIdempotentIntent:true}),"existing-order");
  assert.equal(api.calls.length,1);
});
test("v3 refuses absent keys/scheduled orders; legacy no-coupon path remains unchanged", async () => {
  const api = client(() => ({ data: "order" }));
  await assert.rejects(exports.createFoodCustomerOrder(api,"store",{ ...input,pricingRuleVersion:"food_checkout_v3" }),/idempotency/);
  await assert.rejects(exports.createFoodCustomerOrder(api,"store",{ ...input,pricingRuleVersion:"food_checkout_v3",idempotencyKey:"k",scheduledFor:"tomorrow" }),/not supported/);
  assert.equal(await exports.createFoodCustomerOrder(api,"store",input),"order");
  assert.equal(api.calls.length,1); assert.equal(api.calls[0].name,"food_create_order");
});
