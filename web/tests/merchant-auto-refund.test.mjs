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

test("refund box: automatic state and retry under the policy, existing controls otherwise", () => {
  assert.match(panels, /stripeOnly = false,/);
  assert.match(panels, /if \(stripeOnly && order\.payment_provider === "stripe"\) \{/);
  assert.match(panels, /await retryStripeRefund\(client, order\.id\);/);
  assert.match(panels, /\{status === "failed" \? \(\s*<>[\s\S]*?ลองคืนเงินอีกครั้ง/);
  assert.match(panels, /"กำลังคืนเงิน" : status === "refunded" \? "คืนเงินแล้ว" : status === "failed" \? "คืนเงินไม่สำเร็จ"/);
  // The manual Stripe refund button remains for the legacy path (policy off).
  assert.match(panels, /await requestStripeRefund\(client, order\.id, note\);/);
  assert.match(panels, /"คืนเงินผ่าน Stripe"/);
  assert.match(app, /<RefundControls\s+client=\{client\}\s+order=\{order\}\s+stripeOnly=\{stripeOnly\}/);
});

test("manual payment confirmation is hidden for Stripe-only customer orders except legacy slips", () => {
  assert.match(app, /const manualPaymentAllowed = !stripeOnly \|\| order\.source !== "app" \|\| order\.payment_status === "submitted";/);
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
