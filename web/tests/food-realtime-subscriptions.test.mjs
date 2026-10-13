import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import * as optionRules from "../lib/food-option-rules.ts";

const require = createRequire(import.meta.url);
const ts = require("typescript");
function library(path) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;
  const exports = {};
  runInNewContext(compiled, {
    exports,
    require: (name) => name === "@/lib/food-option-rules" ? optionRules : {},
  });
  return exports;
}

const customer = library("../lib/food-customer.ts");
const merchant = library("../lib/food-merchant.ts");
function subscriptionClient() {
  const observed = {};
  const channel = {
    on: (event, filter, handler) => { Object.assign(observed, { event, filter, handler }); return channel; },
    subscribe: (statusHandler) => { observed.statusHandler = statusHandler; return channel; },
  };
  return { observed, channel, client: { channel: (name) => { observed.name = name; return channel; } } };
}

test("Food subscribes to only its buyer and forwards join/rejoin status to recovery", () => {
  const mock = subscriptionClient();
  let changes = 0;
  const statuses = [];
  assert.equal(customer.subscribeFoodCustomerOrders(mock.client, "buyer-1", () => { changes += 1; }, (status) => statuses.push(status)), mock.channel);
  assert.equal(mock.observed.filter.filter, "buyer_id=eq.buyer-1");
  assert.equal(mock.observed.filter.table, "food_orders");
  mock.observed.handler({ eventType: "UPDATE" });
  mock.observed.statusHandler("SUBSCRIBED");
  mock.observed.statusHandler("SUBSCRIBED");
  assert.equal(changes, 1);
  assert.deepEqual(statuses, ["SUBSCRIBED", "SUBSCRIBED"]);
});

test("Merchant keeps its store filter and unchanged order event payload", () => {
  const mock = subscriptionClient();
  const payload = { eventType: "UPDATE", new: { id: "order-1", payment_status: "paid" }, old: {} };
  let received;
  let joined = 0;
  merchant.subscribeMerchantOrders(mock.client, "store-1", (next) => { received = next; }, (status) => { if (status === "SUBSCRIBED") joined += 1; });
  assert.equal(mock.observed.filter.filter, "store_id=eq.store-1");
  mock.observed.handler(payload);
  mock.observed.statusHandler("SUBSCRIBED");
  assert.equal(received, payload);
  assert.equal(joined, 1);
});

test("legacy subscription callers can omit the added callback", () => {
  const food = subscriptionClient();
  const store = subscriptionClient();
  assert.equal(customer.subscribeFoodCustomerOrders(food.client, "buyer-1", () => {}), food.channel);
  assert.equal(merchant.subscribeMerchantOrders(store.client, "store-1", () => {}), store.channel);
  assert.equal(food.observed.statusHandler, undefined);
  assert.equal(store.observed.statusHandler, undefined);
});

test("Merchant menu save sends normalized minimums while retaining store ownership scope", async () => {
  let payload;
  const filters = [];
  const query = { eq: (key, value) => { filters.push([key, value]); return query; }, then: (resolve) => resolve({ error: null }) };
  const client = { from: (table) => { assert.equal(table, "food_menu_items"); return { update: (next) => { payload = next; return query; } }; } };
  await merchant.saveMenuItem(client, "store-1", {
    id: "menu-1", name: "Food", category: "อาหาร", description: "", price: "100", is_available: true,
    options: [{ id: "toppings", name: "Toppings", required: false, min_select: 2, max_select: 2,
      choices: [{ id: "egg", name: "Egg", price: "10" }, { id: "tofu", name: "Tofu", price: "5" }] }],
  });
  assert.equal(payload.options[0].min_select, 2);
  assert.equal(payload.options[0].required, true);
  assert.deepEqual(filters, [["id", "menu-1"], ["store_id", "store-1"]]);
});

test("invalid option minimums are rejected before issuing a menu write", async () => {
  let wrote = false;
  const client = { from: () => { wrote = true; throw new Error("unexpected database write"); } };
  await assert.rejects(merchant.saveMenuItem(client, "store-1", {
    name: "Food", category: "อาหาร", description: "", price: "100", is_available: true,
    options: [{ id: "toppings", name: "Toppings", required: true, min_select: 2, max_select: 1,
      choices: [{ id: "egg", name: "Egg", price: "10" }] }],
  }));
  assert.equal(wrote, false);
});
