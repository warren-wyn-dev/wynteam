import { readFileSync } from "node:fs";
import { strict as assert } from "node:assert";
const src = (path) => readFileSync(new URL("../../" + path, import.meta.url), "utf8");
const api = src("merchant-android/app/src/main/java/online/wynos/merchant/MerchantApi.kt");
const ui = src("merchant-android/app/src/main/java/online/wynos/merchant/MainActivity.kt");
const model = src("merchant-android/app/src/main/java/online/wynos/merchant/MerchantViewModel.kt");
const printer = src("merchant-android/app/src/main/java/online/wynos/merchant/MerchantPrinter.kt");
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
assert.match(api, /"delivery\/" \+ filter\(orderId\)/);
assert.match(api, /merchant_platform_campaigns/);
assert.match(api, /merchant_food_campaigns/);
assert.match(api, /merchant_staff_members/);
assert.match(api, /merchant_store_reviews/);
assert.match(api, /merchant_ad_account/);
assert.match(api, /merchant_request_ad_topup/);
assert.match(api, /Bitmap\.CompressFormat\.JPEG/);
assert.match(ui, /MenuOptionsEditor\(options/);
assert.match(api, /sold_out_until/);
// Never retain customer/order media across tenant switching or failed authorization.
assert.match(model, /fun selectStore\(storeId: String\)/);
assert.match(model, /state\.stores\.any \{ it\.optString\("id"\) == storeId \}/);
assert.match(model, /if \(state\.store\?\.optString\("id"\) == storeId\) return/);
assert.match(model, /state = MerchantState\(\s*configured = api\.configured,\s*signedIn = true/);
assert.match(model, /fun refresh\(\) = execute \{/);
assert.match(model, /state = MerchantState\(configured = api\.configured\)/);
// Receipt/label PDFs must paginate instead of silently cutting off long orders.
assert.match(printer, /PAGE_COUNT_UNKNOWN/);
assert.match(printer, /private fun drawPaginated/);
assert.match(printer, /if \(y \+ lineHeight > bottom\) newPage\(\)/);
assert.match(printer, /document\.finishPage\(page\)/);
assert.match(model, /terminalWithin24h/);
assert.match(model, /pendingPageLoad/);
assert.match(model, /if \(state\.busy\) pendingPageLoad = page else loadPageData\(page\)/);
assert.match(model, /fun loadMoreOrders\(\)/);
assert.match(ui, /vm::loadMoreOrders/);
assert.match(api, /fun readiness\(storeId: String\): JSONObject =[\s\S]*?food_store_publish_readiness/);
assert.match(api, /val current = readiness\(storeId\)/);
assert.doesNotMatch(api, /"merchant_store_readiness"/);
assert.match(api, /"Prefer", "return=representation"/);
assert.match(api, /result is JSONArray && result\.length\(\) == 0/);
assert.match(api, /fun uploadStoreImage\(storeId: String, kind: String, uri: Uri\)/);
assert.match(api, /fun uploadMenuImage/);
assert.match(api, /fun uploadAdTopup/);
assert.match(ui, /MerchantCategoryManager/);
assert.match(ui, /MerchantExtraScreen/);
assert.match(model, /86_400_000/);
assert.match(ui, /"cooking" -> order\.text\("status"\) in listOf\("preparing", "ready_for_delivery"\)/);
assert.match(ui, /"delivery" -> order\.text\("status"\) == "out_for_delivery"/);
assert.doesNotMatch(api, /service_role|sb_secret_/);
assert.match(api, /KeyProperties\.KEY_ALGORITHM_AES/);
console.log("Native foundation static contract checks passed (not an Android build).");
