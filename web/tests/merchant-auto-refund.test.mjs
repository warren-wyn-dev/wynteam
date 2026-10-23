// ZOKY Stripe-only payments + automatic refunds (Founder 2026-10-22): Merchant web.
// Synthetic data and fake clients only; no network, no real Supabase/Stripe.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { retryStripeRefund } from "../lib/merchant-core.ts";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const app = read("../components/merchant/wynos-merchant-app.tsx");
const panels = read("../components/merchant/merchant-core-panels.tsx");
const css = read("../app/merchant/merchant.css");

const rpcClient = (result) => {
  const calls = [];
  return { calls, rpc: async (name, args) => { calls.push({ name, args }); return result; } };
};

test("retry only asks the server to requeue the refund for this order", async () => {
  const client = rpcClient({ data: null, error: null });
  await retryStripeRefund(client, "order-1");
  assert.deepEqual(client.calls, [{ name: "merchant_retry_stripe_refund", args: { p_order_id: "order-1" } }]);
});

test("retry errors are shown in Thai; a missing RPC is not reported as a raw error", async () => {
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "PGRST202", message: "Could not find the function" } }), "o"), /ยังลองคืนเงินอีกครั้งไม่ได้/);
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "P0001", message: "ไม่มีสิทธิ์จัดการร้านนี้" } }), "o"), /ไม่มีสิทธิ์จัดการร้านนี้/);
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "42501", message: "permission denied" } }), "o"), /ลองคืนเงินอีกครั้งไม่สำเร็จ/);
});

test("refund box: automatic box when an automatic refund exists, manual Stripe button otherwise", () => {
  assert.match(panels, /stripeOnly = false,/);
  // ZOKY-149: one owner of Stripe refunds, in both policy states.
  assert.match(panels, /void fetchFoodAutoRefundSignals\(client, order\.id\)/);
  assert.match(panels, /foodAutoRefundActive\(order, signals \?\? null\) \|\| \(signals === null && stripeOnly\)/);
  assert.match(panels, /if \(stripeOrder && signals === undefined && status !== "refunded"\) \{/);
  assert.match(panels, /if \(autoRefund\) \{/);
  // No manual button while the job check is still running.
  assert.match(panels, /aria-busy="true">\s*<p role="status">กำลังตรวจสอบสถานะการคืนเงิน…<\/p>/);
  assert.match(panels, /const view = merchantAutoRefundView\(order, stripeOnly, signals\?\.needsAttention === true\);/);
  assert.match(panels, /await retryStripeRefund\(client, order\.id\);/);
  assert.match(panels, /\{view\.canRetry \? \(\s*<button[\s\S]*?ลองคืนเงินอีกครั้ง/);
  assert.doesNotMatch(panels, /ระบบกำลังคืนเงินให้ลูกค้า ไม่ต้องกดคืนเงินเอง/);
  // The manual Stripe refund button remains for orders with no automatic refund (CTO C3).
  assert.match(panels, /await requestStripeRefund\(client, order\.id, note\);/);
  assert.match(panels, /"คืนเงินผ่าน Stripe"/);
  assert.ok(panels.indexOf("if (autoRefund) {") < panels.indexOf("await requestStripeRefund(client, order.id, note);"));
  assert.match(app, /<RefundControls\s+client=\{client\}\s+order=\{order\}\s+stripeOnly=\{stripeOnly\}/);
});

test("retry error codes are shown in Thai", async () => {
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "P0001", message: "no_failed_refund" } }), "o"), /ยังลองใหม่ไม่ได้/);
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "P0001", message: "stripe_refund_not_eligible" } }), "o"), /คืนเงินผ่าน Stripe ไม่ได้/);
  await assert.rejects(retryStripeRefund(rpcClient({ error: { code: "P0001", message: "order management role required" } }), "o"), /ไม่มีสิทธิ์จัดการคืนเงิน/);
});

test("PromptPay-only readiness and copy for the store", () => {
  assert.match(app, /accepting: option\.accepting_orders && option\.promptpay/);
  assert.match(app, /ZOKY รับชำระด้วยพร้อมเพย์ผ่าน Stripe เท่านั้น/);
  assert.match(app, /ถ้าลูกค้าชำระด้วยพร้อมเพย์ ลูกค้าต้องกรอกเลขบัญชีในอีเมลจาก Stripe ก่อนเงินจะคืน/);
  assert.doesNotMatch(app, /ร้านจะคืนเงินให้คุณ/);
});

test("manual payment confirmation is hidden for Stripe-only customer orders except legacy slips", () => {
  assert.match(app, /const manualPaymentAllowed = !stripeOnly \|\| order\.source === "manual" \|\| order\.payment_status === "submitted";/);
  assert.match(app, /manualPaymentAllowed && order\.payment_status === "pending" \? \(\s*<button className="wm-secondary wm-full"[\s\S]{0,200}?>ทำเครื่องหมายว่าชำระแล้ว<\/button>/);
  assert.equal((app.match(/>ทำเครื่องหมายว่าชำระแล้ว</g) ?? []).length, 2);
  assert.equal((app.match(/manualPaymentAllowed && order\.payment_status === "pending" \? \(/g) ?? []).length, 2);
  assert.match(app, /รอลูกค้าชำระผ่าน Stripe · ระบบยืนยันการชำระเงินให้อัตโนมัติ/);
  // Legacy submitted slips keep the existing confirm/issue actions.
  assert.match(app, />เงินเข้าแล้ว · รับออเดอร์</);
  assert.match(app, />ยืนยันเงินเข้า</);
  assert.match(app, />สลิปมีปัญหา</);
});

test("cancel confirmation mentions the automatic refund under the policy", () => {
  assert.match(app, /if \(!window\.confirm\(cancelConfirmText\(order, stripeOnly\)\)\) return;/);
  assert.match(app, /if \(!stripeOnly \|\| order\.payment_status !== "paid"\) return "ยืนยันยกเลิกออเดอร์นี้\?";/);
  assert.match(app, /ระบบจะคืนเงินเต็มจำนวนให้ลูกค้าอัตโนมัติ/);
});

test("store not ready: banner and CTA into the existing Stripe setup; receiving form hidden", () => {
  assert.match(app, /fetchFoodPaymentPolicy\(client\)\.then\(\(on\) => \{ if \(live\) setStripeOnly\(on\); \}\)/);
  assert.match(app, /fetchStorePaymentOptions\(client, \[paymentStoreId\]\)/);
  assert.match(app, /function StripeOnlyNotReadyBanner\(\{ onOpen \}: \{ onOpen: \(\) => void \}\)/);
  assert.match(app, /<button className="wm-primary" type="button" onClick=\{onOpen\}>เปิดรับชำระเงิน<\/button>/);
  assert.match(app, /setStoreEditSection\("payment"\);\s*setStoreEditing\(true\);/);
  assert.match(app, /document\.getElementById\("wm-store-section-payment"\)\?\.scrollIntoView\(\{ block: "start" \}\)/);
  assert.match(app, /\{stripeOnly \? null : \(\s*<details className="wm-payment-fallback">/);
  assert.match(app, /done: stripeOnly \? store\.stripe_payments_enabled === true : store\.stripe_payments_enabled === true \|\| \(filled\(store\.promptpay_name\)/);
  assert.match(app, /<MerchantPaymentSetup/);
  assert.match(css, /\.wm-stripe-only-banner > \.wm-primary \{ flex: 1 0 100%; min-height: 44px; \}/);
});
