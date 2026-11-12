// ZOKY-FULFILL-001: the customer app's pickup / COD helpers and RPC routing.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../lib/food-customer.ts", import.meta.url), "utf8");
const app = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
const out = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const mod = { exports: {} };
runInNewContext(out, {
  module: mod,
  exports: mod.exports,
  Intl,
  Date,
  Number,
  String,
  Array,
  Error,
  require: (name) => ({
    "@/lib/image-location": { withoutLocation: (file) => file },
    "@/lib/upload-image": { imageUploadType: () => "image/jpeg" },
    "@/lib/supabase/clock-skew-fetch": { sessionErrorCopy: () => null },
  })[name] ?? {},
});
const food = mod.exports;

function recordingClient(data) {
  const calls = [];
  return {
    calls,
    rpc: async (name, params) => {
      calls.push({ name, params });
      return { data, error: null };
    },
  };
}

const line = { menu_item_id: "m1", quantity: 2, note: "", selected_options: [] };

test("stores without the new columns keep delivery only", () => {
  assert.deepEqual([...food.storeFulfillmentModes({})], ["delivery"]);
  assert.equal(food.storeHasFulfillmentOptions({}), false);
});

test("store modes follow the store's switches", () => {
  assert.deepEqual([...food.storeFulfillmentModes({ pickup_enabled: true, delivery_enabled: true })], ["delivery", "pickup"]);
  assert.deepEqual([...food.storeFulfillmentModes({ pickup_enabled: true, delivery_enabled: false })], ["pickup"]);
  assert.deepEqual([...food.storeFulfillmentModes({ pickup_enabled: false, delivery_enabled: true })], ["delivery"]);
});

test("pickup orders use pickup words on the reused statuses", () => {
  assert.equal(food.foodOrderStatusLabelFor({ status: "ready_for_delivery", fulfillment_type: "pickup" }), "พร้อมให้รับที่ร้าน");
  assert.equal(food.foodOrderStatusLabelFor({ status: "delivered", fulfillment_type: "pickup" }), "รับอาหารแล้ว");
  assert.equal(food.foodOrderStatusLabelFor({ status: "ready_for_delivery", fulfillment_type: "delivery" }), "พร้อมจัดส่ง");
  assert.equal(food.foodOrderStatusLabelFor({ status: "delivered" }), "จัดส่งสำเร็จ");
});

test("pickup times show on the Bangkok clock", () => {
  assert.equal(food.foodPickupTimeLabel("2026-10-26T07:30:00Z"), "14:30");
  assert.equal(food.foodPickupTimeLabel(null), "");
  assert.equal(food.foodPickupTimeLabel("not a date"), "");
});

test("quotes without a fulfillment type keep the v1 / v2 RPCs", async () => {
  const client = recordingClient({ subtotal: 100 });
  await food.quoteFoodCustomerOrder(client, "s1", [line]);
  await food.quoteFoodCustomerOrder(client, "s1", [line], null, "food50");
  assert.deepEqual(client.calls.map((call) => call.name), ["food_quote_order", "food_quote_order_v2"]);
});

test("pickup quotes call v3 and return the offered slots", async () => {
  const client = recordingClient({ subtotal: 100, pickup_slots: ["2026-10-26T07:30:00+00:00"], cod_available: false, fulfillment_type: "pickup" });
  const quote = await food.quoteFoodCustomerOrder(client, "s1", [line], null, null, "pickup");
  assert.equal(client.calls[0].name, "food_quote_order_v3");
  assert.equal(client.calls[0].params.p_fulfillment_type, "pickup");
  assert.equal("p_latitude" in client.calls[0].params, false);
  assert.deepEqual([...quote.pickup_slots], ["2026-10-26T07:30:00+00:00"]);
  assert.equal(quote.fulfillment_type, "pickup");
});

test("pickup orders are created through v3 with the chosen slot", async () => {
  const client = recordingClient("order-1");
  const id = await food.createFoodCustomerOrder(client, "s1", {
    recipientName: "A", recipientPhone: "0812345678", shippingAddress: "รับเองที่ร้าน",
    items: [line], location: null, fulfillmentType: "pickup", pickupAt: "2026-10-26T07:30:00Z", paymentMethod: "transfer",
  });
  assert.equal(id, "order-1");
  const call = client.calls[0];
  assert.equal(call.name, "food_create_order_v3");
  assert.equal(call.params.p_fulfillment_type, "pickup");
  assert.equal(call.params.p_pickup_at, "2026-10-26T07:30:00Z");
  assert.equal(call.params.p_payment_method, "transfer");
});

test("delivery COD orders send no pickup time", async () => {
  const client = recordingClient("order-2");
  await food.createFoodCustomerOrder(client, "s1", {
    recipientName: "A", recipientPhone: "0812345678", shippingAddress: "x",
    items: [line], location: { latitude: 13.7, longitude: 100.5 },
    fulfillmentType: "delivery", pickupAt: "2026-10-26T07:30:00Z", paymentMethod: "cod",
  });
  const call = client.calls[0];
  assert.equal(call.name, "food_create_order_v3");
  assert.equal(call.params.p_pickup_at, null);
  assert.equal(call.params.p_payment_method, "cod");
});

test("legacy orders still use the original create RPC", async () => {
  const client = recordingClient("order-3");
  await food.createFoodCustomerOrder(client, "s1", {
    recipientName: "A", recipientPhone: "0812345678", shippingAddress: "x", items: [line], location: null,
  });
  assert.equal(client.calls[0].name, "food_create_order");
});

test("cancel requests go through the server RPC", async () => {
  const client = recordingClient(null);
  await food.requestFoodOrderCancel(client, "order-1", "  มาไม่ทัน  ");
  assert.equal(JSON.stringify(client.calls[0]), JSON.stringify({ name: "food_request_cancel", params: { p_order_id: "order-1", p_note: "มาไม่ทัน" } }));
});

test("server fulfilment errors have Thai copy", () => {
  assert.equal(food.foodCustomerError(new Error("invalid_pickup_time")), "เวลารับที่เลือกใช้ไม่ได้แล้ว กรุณาเลือกเวลาใหม่");
  assert.equal(food.foodCustomerError(new Error("cod_not_available")), "ร้านนี้ไม่รับเงินสดปลายทางสำหรับออเดอร์นี้");
  assert.equal(food.foodCustomerError(new Error("cancel already requested")), "ส่งคำขอยกเลิกไปแล้ว รอร้านตัดสินใจ");
});

test("COD orders never show the transfer payment screen", () => {
  assert.match(app, /const awaitingPayment = !isCod && \["pending", "issue"\]\.includes\(order\.payment_status\);/);
  assert.match(app, /!foodIsCodOrder\(order\) && \["pending", "issue"\]\.includes\(order\.payment_status\)/);
});

test("pickup tracking skips the out-for-delivery step", () => {
  assert.match(app, /TRACKING_STEPS\.filter\(\(step\) => step\.status !== "out_for_delivery"\)/);
});

test("pickup slots refresh every minute and the code waits for payment", () => {
  assert.match(app, /setInterval\(\(\) => setPickupTick\(\(tick\) => tick \+ 1\), 60_000\)/);
  assert.match(app, /`pickup\|\$\{pickupTick\}\|/);
  assert.match(app, /isPickup && !isCancelled && !awaitingPayment && order\.status !== "delivered" && order\.pickup_code/);
});
