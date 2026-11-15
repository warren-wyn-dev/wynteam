import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import test from "node:test";

registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith("@/")) return next(new URL(`../${specifier.slice(2)}.ts`, import.meta.url).href, context);
    return next(specifier, context);
  },
});
const { createFoodCustomerOrder, isOrderRequestReusedError, newOrderRequestId } = await import("../lib/food-customer.ts");

const STORE = "10000000-0000-4000-8000-000000000001";
const ORDER = "30000000-0000-4000-8000-000000000003";
const input = (extra = {}) => ({
  recipientName: "ทดสอบ", recipientPhone: "0812345678", shippingAddress: "1 ถนนทดสอบ", customerNote: "",
  items: [{ menu_item_id: "m1", quantity: 2, note: "", selected_options: [] }], location: null, ...extra,
});
function client(handlers) {
  const calls = [];
  return {
    calls,
    async rpc(name, args) {
      calls.push({ name, args });
      return handlers[name] ? handlers[name](args) : { data: null, error: null };
    },
  };
}

test("without a request id the order path is unchanged", async () => {
  const c = client({ food_create_order: () => ({ data: ORDER, error: null }) });
  assert.equal(await createFoodCustomerOrder(c, STORE, input()), ORDER);
  assert.deepEqual(c.calls.map((call) => call.name), ["food_create_order"]);
});

test("a new request is claimed, the order created once and recorded", async () => {
  const c = client({
    food_order_request_claim: () => ({ data: { status: "new" }, error: null }),
    food_create_order: () => ({ data: ORDER, error: null }),
  });
  const id = newOrderRequestId();
  assert.equal(await createFoodCustomerOrder(c, STORE, input({ requestId: id })), ORDER);
  assert.deepEqual(c.calls.map((call) => call.name), ["food_order_request_claim", "food_create_order", "food_order_request_done"]);
  assert.equal(c.calls[0].args.p_request_id, id);
  assert.equal(c.calls[0].args.p_store_id, STORE);
  assert.match(c.calls[0].args.p_payload_hash, /^[0-9a-f]{64}$/);
  assert.deepEqual(c.calls[2].args, { p_request_id: id, p_order_id: ORDER });
});

test("the payload hash follows the order content, not the request id", async () => {
  const hashes = [];
  for (const [id, extra] of [["a", {}], ["b", {}], ["c", { customerNote: "ไม่เผ็ด" }]]) {
    const c = client({ food_order_request_claim: () => ({ data: { status: "new" }, error: null }), food_create_order: () => ({ data: ORDER, error: null }) });
    await createFoodCustomerOrder(c, STORE, input({ requestId: id, ...extra }));
    hashes.push(c.calls[0].args.p_payload_hash);
  }
  assert.equal(hashes[0], hashes[1]);
  assert.notEqual(hashes[0], hashes[2]);
});

test("a request that already has an order returns it and creates nothing", async () => {
  const c = client({ food_order_request_claim: () => ({ data: { status: "done", order_id: ORDER }, error: null }) });
  assert.equal(await createFoodCustomerOrder(c, STORE, input({ requestId: newOrderRequestId() })), ORDER);
  assert.deepEqual(c.calls.map((call) => call.name), ["food_order_request_claim"]);
});

test("a pending request waits for the first attempt and returns its order", async () => {
  let claims = 0;
  const c = client({ food_order_request_claim: () => ({ data: ++claims === 1 ? { status: "pending" } : { status: "done", order_id: ORDER }, error: null }) });
  assert.equal(await createFoodCustomerOrder(c, STORE, input({ requestId: newOrderRequestId() })), ORDER);
  assert.equal(claims, 2);
  assert.ok(!c.calls.some((call) => call.name === "food_create_order"));
});

test("a failed order releases the claim and rethrows, so the next try can create it", async () => {
  const c = client({
    food_order_request_claim: () => ({ data: { status: "new" }, error: null }),
    food_create_order: () => ({ data: null, error: { message: "store is closed" } }),
  });
  const id = newOrderRequestId();
  await assert.rejects(() => createFoodCustomerOrder(c, STORE, input({ requestId: id })), /store is closed/);
  assert.deepEqual(c.calls.map((call) => call.name), ["food_order_request_claim", "food_create_order", "food_order_request_release"]);
  assert.deepEqual(c.calls[2].args, { p_request_id: id });
});

test("while the database functions are missing the order is created as before", async () => {
  for (const code of ["PGRST202", "42883"]) {
    const c = client({
      food_order_request_claim: () => ({ data: null, error: { code, message: "missing" } }),
      food_create_order: () => ({ data: ORDER, error: null }),
    });
    assert.equal(await createFoodCustomerOrder(c, STORE, input({ requestId: newOrderRequestId() })), ORDER);
    assert.deepEqual(c.calls.map((call) => call.name), ["food_order_request_claim", "food_create_order"]);
  }
});

test("any other claim error stops the order instead of risking a duplicate", async () => {
  const c = client({ food_order_request_claim: () => ({ data: null, error: { code: "42501", message: "permission denied" } }) });
  await assert.rejects(() => createFoodCustomerOrder(c, STORE, input({ requestId: newOrderRequestId() })), /permission denied/);
  assert.ok(!c.calls.some((call) => call.name === "food_create_order"));
});

test("the order id is returned even if recording it fails", async () => {
  const c = client({
    food_order_request_claim: () => ({ data: { status: "new" }, error: null }),
    food_create_order: () => ({ data: ORDER, error: null }),
    food_order_request_done: () => { throw new Error("network"); },
  });
  assert.equal(await createFoodCustomerOrder(c, STORE, input({ requestId: newOrderRequestId() })), ORDER);
});

test("the reused-id error is recognised and the app generates a new id", async () => {
  assert.equal(isOrderRequestReusedError(new Error("request id reused for a different order")), true);
  assert.equal(isOrderRequestReusedError(new Error("store is closed")), false);
  assert.equal(isOrderRequestReusedError("x"), false);
  assert.notEqual(newOrderRequestId(), newOrderRequestId());
  const app = (await import("node:fs")).readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  assert.match(app, /orderRequestRef\.current \?\?= newOrderRequestId\(\)/);
  assert.match(app, /isOrderRequestReusedError\(error\)/);
  assert.match(app, /orderRequestRef\.current = null;\n/);
});
