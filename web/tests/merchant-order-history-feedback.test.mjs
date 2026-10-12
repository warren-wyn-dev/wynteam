import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const merchant = fs.readFileSync(new URL("../components/merchant/wynos-merchant-app.tsx", import.meta.url), "utf8");
const lib = fs.readFileSync(new URL("../lib/food-merchant.ts", import.meta.url), "utf8");
const history = fs.readFileSync(new URL("../components/merchant/merchant-order-history.tsx", import.meta.url), "utf8");
const feedback = fs.readFileSync(new URL("../components/merchant/merchant-feedback.tsx", import.meta.url), "utf8");
const style = fs.readFileSync(new URL("../app/merchant/merchant.css", import.meta.url), "utf8");

const source = lib.match(/export function isRecentCompletedOrder\(order: FoodOrder, now = Date\.now\(\)\): boolean \{[\s\S]*?\n\}/)?.[0];
assert.ok(source, "24-hour predicate must exist");
const recent = vm.runInNewContext(source.replace("export function", "function").replace("order: FoodOrder, now = Date.now()): boolean", "order, now = Date.now())") + "\nisRecentCompletedOrder");

test("Done tab shows delivered/cancelled orders for 24h from terminal event, never deletes", () => {
  const now = Date.parse("2026-10-12T10:00:00Z");
  const template = { status: "delivered", delivered_at: new Date(now - 23 * 3600000).toISOString(), cancelled_at: null };
  assert.equal(recent(template, now), true);
  assert.equal(recent({ ...template, delivered_at: new Date(now - 24 * 3600000 + 1).toISOString() }, now), true);
  assert.equal(recent({ ...template, delivered_at: new Date(now - 24 * 3600000).toISOString() }, now), false);
  assert.equal(recent({ ...template, delivered_at: new Date(now + 3600000).toISOString() }, now), false);
  assert.equal(recent({ ...template, status: "cancelled", delivered_at: null, cancelled_at: new Date(now - 1000).toISOString() }, now), true);
  assert.equal(recent({ ...template, status: "preparing" }, now), false);
  assert.equal(recent({ ...template, status: "cancelled", delivered_at: null, cancelled_at: null }, now), false);
  assert.match(merchant, /return isRecentCompletedOrder\(order, now\)/);
  assert.match(merchant, /setInterval\(\(\) => setOrderClock\(Date\.now\(\)\), 30_000\)/);
});

test("Order history is store-scoped, paginated and restricted to terminal orders", () => {
  assert.match(lib, /\.eq\("store_id", storeId\)/);
  assert.match(lib, /\.in\("status", \["delivered", "cancelled"\]\)/);
  assert.match(lib, /\.ilike\("order_number"/);
  assert.match(lib, /\.range\(offset, offset \+ limit\)/);
  assert.match(history, /fetchMerchantOrderHistoryPage/);
  assert.match(history, /onOpenOrder\(order\)/);
  assert.match(history, /ประวัติออเดอร์/);
  assert.doesNotMatch(history, /deleteFoodOrder|removeFoodOrder/);
});

test("Feedback uses verified store review RPC and role-gated replies", () => {
  assert.match(feedback, /fetchMerchantStoreReviews\(client, store\.id, 100\)/);
  assert.match(feedback, /fetchMerchantStaff\(client, store\.id\)/);
  assert.match(feedback, /member\?\.role === "owner"/);
  assert.match(feedback, /replyMerchantStoreReview\(client, review\.id, draft\)/);
  assert.match(feedback, /onlyUnanswered/);
});

test("History and feedback appear under More without adding bottom tabs", () => {
  assert.match(merchant, /tab === "history"/);
  assert.match(merchant, /tab === "feedback"/);
  assert.match(merchant, /onOpenTab\("history"\)/);
  assert.match(merchant, /onOpenTab\("feedback"\)/);
  assert.match(style, /\.wm-history-controls/);
  assert.match(style, /\.wm-feedback-summary/);
});
