import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");

const sql = read("../supabase/migrations/20261008113000_food_unpaid_payment_timeout.sql");
const worker = read("../supabase/functions/food-unpaid-timeout/index.ts");
const checkout = read("../supabase/functions/food-stripe-checkout/index.ts");
const config = read("../supabase/config.toml");
const ui = read("components/food/wynos-food-developer-app.tsx");

test("10-minute deadline starts on new orders only and manual merchant orders are excluded", () => {
  assert.match(sql, /add column if not exists payment_due_at timestamptz/);
  assert.match(sql, /alter column payment_due_at[\s\S]*set default \(now\(\) \+ interval '10 minutes'\)/);
  assert.doesNotMatch(sql, /update public\.food_orders[\s\S]*set payment_due_at\s*=/);
  assert.match(sql, /v_order\.source <> 'app'/);
  assert.match(worker, /\.eq\("source", "app"\)/);
});

test("cancellation is locked and only affects unpaid, unaccepted matching orders", () => {
  assert.match(sql, /for update;/);
  assert.match(sql, /v_order\.status <> 'pending_acceptance'/);
  assert.match(sql, /v_order\.payment_status not in \('pending','issue'\)/);
  assert.match(sql, /v_order\.paid_at is not null/);
  assert.match(sql, /v_order\.stripe_checkout_session_id is distinct from p_expected_session_id/);
  assert.match(sql, /auto_cancelled_unpaid/);
  assert.match(sql, /food_campaign_release_on_cancel|trg_food_guard_late_slip/);
  assert.match(sql, /old\.status = 'cancelled'/);
  assert.match(sql, /new\.payment_status = 'submitted'/);
});

test("live Stripe Checkout is expired or deferred, never blindly cancelled", () => {
  assert.match(worker, /stripeSession\(secret, payment\.stripe_account_id, sessionId, true\)/);
  assert.match(worker, /session\.status === "complete"/);
  assert.match(worker, /session\.payment_status === "paid"/);
  assert.match(worker, /session\.status !== "expired"/);
  assert.ok(worker.indexOf('session.status !== "expired"') < worker.indexOf('admin.rpc("food_timeout_cancel"'));
  assert.match(checkout, /payment_deadline_expired/);
  assert.match(checkout, /\.eq\("status", "pending_acceptance"\)/);
  assert.match(checkout, /payment_due_at\.gt/);
});

test("worker requires vault-backed auth and is scheduled every minute", () => {
  assert.match(worker, /food_timeout_cron_authorized/);
  assert.match(sql, /vault\.create_secret/);
  assert.match(sql, /cron\.schedule\('wynos-food-unpaid-timeout','\* \* \* \* \*'/);
  assert.match(config, /\[functions\.food-unpaid-timeout\][\s\S]*verify_jwt = false/);
  assert.match(worker, /x-wynos-cron-key/);
});

test("customer is warned and gets a countdown, notifications identify auto-cancellation", () => {
  assert.match(ui, /กรุณาชำระเงินหรือส่งสลิปภายใน 10 นาที/);
  assert.match(ui, /const secondsLeft = order\.payment_due_at/);
  assert.match(ui, /หมดเวลาชำระเงินแล้ว/);
  assert.match(sql, /ถูกยกเลิกอัตโนมัติ เพราะไม่ชำระเงินภายใน 10 นาที/);
});
