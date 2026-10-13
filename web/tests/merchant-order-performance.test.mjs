import assert from "node:assert/strict";
import { test } from "node:test";
import { fetchMerchantOrderPerformance, merchantOrderPerformanceError } from "../lib/merchant-order-performance.ts";

test("report asks the server for the store and inclusive date cohort and preserves unknown rates", async () => {
  const calls = [];
  const summary = await fetchMerchantOrderPerformance({ rpc: async (...args) => {
    calls.push(args);
    return { data: { from: "2026-10-13", to: "2026-10-13", total_orders: 0,
      acceptance_rate: null, merchant_cancel_rate: null, average_preparation_minutes: null, top_items: [] }, error: null };
  } }, "store-one", { from: "2026-10-13", to: "2026-10-13" });
  assert.deepEqual(calls, [["merchant_order_performance", { p_store_id: "store-one", p_from: "2026-10-13", p_to: "2026-10-13" }]]);
  assert.equal(summary.acceptanceRate, null);
  assert.equal(summary.merchantCancelRate, null);
  assert.equal(summary.averagePreparationMinutes, null);
  assert.deepEqual(summary.topItems, []);
});

test("disabled or unapplied additive report stays hidden, other RPC errors remain errors", async () => {
  for (const error of [{ message: "merchant performance is not enabled" }, { code: "PGRST202", message: "Could not find the function" }]) {
    assert.equal(await fetchMerchantOrderPerformance({ rpc: async () => ({ error }) }, "store", { from: "2026-10-13", to: "2026-10-13" }), null);
  }
  await assert.rejects(fetchMerchantOrderPerformance({ rpc: async () => ({ error: { message: "merchant manager access required" } }) }, "store", { from: "2026-10-13", to: "2026-10-13" }), /merchant manager access required/);
});

test("JSON numeric strings and deleted menu snapshots retain actual server metrics", async () => {
  const summary = await fetchMerchantOrderPerformance({ rpc: async () => ({ data: {
    total_orders: "10", accepted_orders: "6", acceptance_eligible_orders: "9", acceptance_rate: "66.67",
    merchant_cancelled_orders: "1", merchant_cancel_rate: "11.11", preparation_samples: "3", average_preparation_minutes: "0",
    top_items: [{ menu_item_id: null, item_name: "เมนูที่ลบแล้ว", quantity: "5", orders: "2" }],
  }, error: null }) }, "store", { from: "2026-10-13", to: "2026-10-13" });
  assert.equal(summary.totalOrders, 10);
  assert.equal(summary.acceptanceRate, 66.67);
  assert.equal(summary.averagePreparationMinutes, 0);
  assert.deepEqual(summary.topItems, [{ menuItemId: null, itemName: "เมนูที่ลบแล้ว", quantity: 5, orders: 2 }]);
  assert.equal("income" in summary, false);
  assert.equal("gp" in summary, false);
});

test("unexpected backend errors are presented without database details", () => {
  assert.equal(merchantOrderPerformanceError(new Error("private database details")), "โหลดสถิติคำสั่งซื้อไม่สำเร็จ กรุณาลองอีกครั้ง");
  assert.match(merchantOrderPerformanceError(new Error("merchant manager access required")), /เฉพาะเจ้าของ/);
  assert.match(merchantOrderPerformanceError(new Error("date range is too long")), /366/);
});
