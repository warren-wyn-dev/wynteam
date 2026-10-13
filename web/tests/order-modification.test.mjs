import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import { renderToStaticMarkup } from "react-dom/server";
import { createElement } from "react";

const require = createRequire(import.meta.url);
const ts = require("typescript");
function compile(path, imports = {}) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const output = ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, jsx: ts.JsxEmit.ReactJSX,
  } }).outputText;
  const exports = {};
  runInNewContext(output, { exports, require: (name) => imports[name] ?? require(name) });
  return exports;
}
const library = compile("../lib/order-modification.ts", { "@/lib/order-recovery": {} });
const orderId = "00000000-0000-4000-8000-000000000001";
const itemId = "00000000-0000-4000-8000-000000000002";
const requestId = "00000000-0000-4000-8000-000000000003";
const key = "00000000-0000-4000-8000-000000000004";
const items = [{ id: itemId, item_name: "ข้าว", quantity: 2 }];
const request = { id: requestId, order_id: orderId, reason: "วัตถุดิบหมด",
  status: "pending_customer", created_at: "2026-10-13T05:00:00Z",
  proposed_items: [{ order_item_id: itemId, item_name: "ข้าว", original_quantity: 2, quantity: 1 }] };
const plain = (value) => JSON.parse(JSON.stringify(value));

test("merchant proposal records only reductions/removals and rejects unchanged, increased and invalid quantities", () => {
  assert.deepEqual(plain(library.buildModificationItems(items, { [itemId]: "1" })), [{ order_item_id: itemId, quantity: 1 }]);
  assert.deepEqual(plain(library.buildModificationItems(items, { [itemId]: "0" })), [{ order_item_id: itemId, quantity: 0 }]);
  for (const quantity of ["-1", "3", "1.5", "", "01", "2"]) {
    assert.throws(() => library.buildModificationItems(items, { [itemId]: quantity }));
  }
  assert.throws(() => library.buildModificationItems([], {}));
});

test("rows must belong to the requested order and have valid consent/item state", () => {
  assert.equal(library.parseOrderModifications([request], orderId)[0].status, "pending_customer");
  for (const changed of [{ order_id: key }, { status: "applied" }, { proposed_items: [] },
    { proposed_items: [{ ...request.proposed_items[0], quantity: 3 }] },
    { proposed_items: [request.proposed_items[0], request.proposed_items[0]] }]) {
    assert.throws(() => library.parseOrderModifications([{ ...request, ...changed }], orderId));
  }
});

test("missing, failed and non-boolean backend flags fail closed without reading request rows", async () => {
  for (const result of [{ data: null }, { data: { order_modifications: false } },
    { data: { order_modifications: "true" } }, { data: { order_modifications: true }, error: { message: "failed" } }]) {
    const client = { rpc: async () => result, from: () => assert.fail("disabled feature must not read rows") };
    assert.equal(await library.orderModificationsEnabled(client), false);
    assert.equal((await library.fetchOrderModifications(client, orderId)).enabled, false);
  }
  assert.equal(await library.orderModificationsEnabled({ rpc: async () => { throw new Error("offline"); } }), false);
});

test("merchant capability is explicit, store scoped and never inferred from the feature flag", async () => {
  const calls = [];
  const client = { rpc: async (name, args) => { calls.push({ name, args });
    return { data: { order_modifications: true } }; } };
  assert.equal((await library.fetchOrderModificationFeatures(client, key)).canManageOrders, false);
  assert.equal(calls[0].args.p_store_id, key);
  await assert.rejects(library.proposeOrderModification(client, { orderId, storeId: key,
    requestKey: key, reason: "หมด", items: [{ order_item_id: itemId, quantity: 1 }] }));
  assert.ok(calls.every((call) => call.name === "food_order_operations_features"));
});

test("enabled reads select consent records with order filter and bounded history", async () => {
  const calls = [];
  const query = { select: (value) => { calls.push(["select", value]); return query; },
    eq: (name, value) => { calls.push([name, value]); return query; },
    order: () => query, limit: (limit) => { calls.push(["limit", limit]); return Promise.resolve({ data: [request], error: null }); } };
  const client = { rpc: async () => ({ data: { order_modifications: true } }),
    from: (table) => { calls.push(["table", table]); return query; } };
  const result = await library.fetchOrderModifications(client, orderId);
  assert.equal(result.enabled, true);
  assert.equal(result.requests.length, 1);
  assert.ok(calls.some(([name, value]) => name === "order_id" && value === orderId));
  assert.ok(calls.some(([name, value]) => name === "limit" && value === 30));
});

test("disabled features and invalid proposals cannot invoke the write RPC", async () => {
  const calls = [];
  const client = { rpc: async (name) => { calls.push(name); return { data: { order_modifications: false } }; } };
  await assert.rejects(library.proposeOrderModification(client, { orderId, storeId: key, requestKey: key, reason: "หมด", items: [{ order_item_id: itemId, quantity: 1 }] }));
  await assert.rejects(library.respondOrderModification(client, requestId, false));
  await assert.rejects(library.proposeOrderModification(client, { orderId, storeId: key, requestKey: key, reason: " ", items: [] }));
  assert.ok(calls.every((name) => name === "food_order_operations_features"));
});

test("proposal retries preserve the caller's idempotency key and never submit totals or payment writes", async () => {
  const calls = [];
  const client = { rpc: async (name, args) => {
    calls.push({ name, args });
    return { data: name === "food_order_operations_features" ? { order_modifications: true, can_manage_orders: true } : requestId };
  }, from: () => assert.fail("proposal must only use protected RPC") };
  const input = { orderId, storeId: key, requestKey: key, reason: " หมด ", items: [{ order_item_id: itemId, quantity: 0 }] };
  await library.proposeOrderModification(client, input);
  await library.proposeOrderModification(client, input);
  const writes = calls.filter((call) => call.name === "merchant_propose_food_order_modification");
  assert.equal(writes.length, 2);
  assert.equal(writes[0].args.p_request_key, key);
  assert.equal(writes[1].args.p_request_key, key);
  assert.deepEqual(Object.keys(writes[0].args).sort(), ["p_items", "p_order_id", "p_reason", "p_request_key"]);
});

test("accept/reject calls only consent RPC and validates authoritative returned status", async () => {
  const calls = [];
  const client = { rpc: async (name, args) => {
    calls.push({ name, args });
    return { data: name === "food_order_operations_features" ? { order_modifications: true }
      : args.p_accept ? "accepted_pending_execution" : "rejected" };
  }, from: () => assert.fail("consent must not update order/payment tables") };
  assert.equal(await library.respondOrderModification(client, requestId, true), "accepted_pending_execution");
  assert.equal(await library.respondOrderModification(client, requestId, false), "rejected");
  assert.deepEqual(calls.filter((call) => call.args).map((call) => call.name), ["food_respond_order_modification", "food_respond_order_modification"]);
  const bad = { rpc: async (name) => ({ data: name === "food_order_operations_features"
    ? { order_modifications: true } : "applied" }) };
  await assert.rejects(library.respondOrderModification(bad, requestId, true));
});

test("selected order events are scoped and join/rejoin callbacks can recover missed consent", () => {
  const observed = {};
  const channel = { on: (_kind, filter, handler) => { Object.assign(observed, { filter, handler }); return channel; },
    subscribe: (handler) => { observed.status = handler; return channel; } };
  const statuses = [];
  let changed = 0;
  library.subscribeOrderModificationEvents({ channel: () => channel }, orderId, () => { changed += 1; }, (status) => statuses.push(status));
  assert.equal(observed.filter.filter, `order_id=eq.${orderId}`);
  assert.equal(observed.filter.table, "food_order_events");
  observed.handler({});
  observed.status("SUBSCRIBED");
  observed.status("SUBSCRIBED");
  assert.equal(changed, 1);
  assert.deepEqual(statuses, ["SUBSCRIBED", "SUBSCRIBED"]);
});

function components(state) {
  const mocked = { ...library, useOrderModifications: () => ({ enabled: true, canManageOrders: true, requests: [request], error: "", reload: async () => {}, ...state }) };
  const imports = { "@/lib/order-modification": mocked };
  return { food: compile("../components/food/food-order-modification.tsx", imports).FoodOrderModification,
    merchant: compile("../components/merchant/merchant-order-modification.tsx", imports).MerchantOrderModification };
}

test("customer panel says consent only, offers reject, and accepted state has no further decision buttons", () => {
  const panel = components({});
  const output = renderToStaticMarkup(createElement(panel.food, { client: {}, orderId }));
  assert.match(output, /รายการอาหารและยอดเงินยังไม่เปลี่ยน/);
  assert.match(output, /ไม่ยินยอม ใช้รายการเดิม/);
  const accepted = components({ requests: [{ ...request, status: "accepted_pending_execution" }] });
  const done = renderToStaticMarkup(createElement(accepted.food, { client: {}, orderId }));
  assert.match(done, /ยืนยันคำขอแล้ว รอร้านดำเนินการ/);
  assert.doesNotMatch(done, /<button/);
});

test("feature OFF renders nothing and merchant role gating hides editor while replacement remains blocked", () => {
  const disabled = components({ enabled: false, requests: [] });
  assert.equal(renderToStaticMarkup(createElement(disabled.food, { client: {}, orderId })), "");
  const order = { id: orderId, store_id: key, buyer_id: key, status: "preparing", food_order_items: items };
  assert.equal(renderToStaticMarkup(createElement(disabled.merchant, { client: {}, order, canManageOrders: true })), "");
  const panel = components({ requests: [] });
  const readonly = renderToStaticMarkup(createElement(panel.merchant, { client: {}, order, canManageOrders: false }));
  assert.doesNotMatch(readonly, /<form/);
  const editable = renderToStaticMarkup(createElement(panel.merchant, { client: {}, order, canManageOrders: true }));
  assert.match(editable, /<form/);
  assert.match(editable, /เปลี่ยนเป็นเมนูอื่น · ยังไม่พร้อมใช้งาน/);
  const noServerRole = components({ requests: [], canManageOrders: false });
  assert.doesNotMatch(renderToStaticMarkup(createElement(noServerRole.merchant, { client: {}, order, canManageOrders: true })), /<form/);
});
