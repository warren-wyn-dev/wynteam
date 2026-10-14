import { readFileSync } from "node:fs";
import { strict as assert } from "node:assert";
const src = (path) => readFileSync(new URL("../../" + path, import.meta.url), "utf8");
const api = src("merchant-android/app/src/main/java/online/wynos/merchant/MerchantApi.kt");
const ui = src("merchant-android/app/src/main/java/online/wynos/merchant/MainActivity.kt");
const model = src("merchant-android/app/src/main/java/online/wynos/merchant/MerchantViewModel.kt");
const web = src("web/lib/food-merchant.ts");
const merchantWeb = src("web/components/merchant/wynos-merchant-app.tsx");
assert.match(ui, /setContent\s*\{/);
assert.doesNotMatch(api + ui + model, /\bWebView\b|\bTrustedWebActivity\b/);
assert.match(api, /merchant_users\?select=user_id,active,identity_mode/);
for (const rpc of ["food_has_merchant_access", "merchant_sales_report",
  "merchant_finance_summary", "food_transition_order", "food_set_payment_status"]) {
  assert.ok(api.includes(rpc), "missing native RPC: " + rpc);
  assert.ok(web.includes(rpc) || merchantWeb.includes(rpc) || rpc === "merchant_finance_summary",
    "merchant web RPC is missing: " + rpc);
}
assert.match(model, /payment_status"\) == "paid"/);
assert.match(ui, /payment != "paid"/);
assert.match(ui, /approveSlipAndAccept\(order, reviewed, eta\)/);
assert.match(ui, /completeOrder\(order, method, locationNote, deliveryUri\)/);
assert.match(api, /food_complete_delivery/);
assert.match(api, /storage\/v1\/object\/sign\/food-private/);
assert.match(api, /"delivery\/\$id\/"/);
assert.match(api, /Bitmap\.CompressFormat\.JPEG/);
assert.match(ui, /MenuOptionsEditor\(options/);
assert.match(api, /sold_out_until/);
assert.match(model, /86_400_000/);
assert.match(ui, /"cooking" -> order\.text\("status"\) in listOf\("preparing", "ready_for_delivery"\)/);
assert.match(ui, /"delivery" -> order\.text\("status"\) == "out_for_delivery"/);
assert.doesNotMatch(api, /service_role|sb_secret_/);
assert.match(api, /KeyProperties\.KEY_ALGORITHM_AES/);
console.log("Native foundation static contract checks passed (not an Android build).");
