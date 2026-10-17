import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const android = (relativePath) =>
  readFileSync(new URL(`../../food-android/${relativePath}`, import.meta.url), "utf8");

test("native slip picker is a local image preview rather than a payment write", () => {
  const picker = android("app/src/main/java/online/wynos/food/ui/FoodStagingSlipPicker.kt");
  assert.match(picker, /ActivityResultContracts\.GetContent\(\)/);
  assert.match(picker, /picker\.launch\("image\/\*"\)/);
  assert.match(picker, /AsyncImage\(/);
  assert.match(picker, /remember\(orderId\)/);
  assert.match(picker, /selectedUri = null/);
  assert.doesNotMatch(picker, /supabase\.storage|uploadTo|\.rpc\(|food_submit_payment|food_create_order/i);
});

test("slip picker is hidden on ordinary or release builds and paid orders", () => {
  const ui = android("app/src/main/java/online/wynos/food/ui/FoodStagingSlipPicker.kt");
  const detail = android("app/src/main/java/online/wynos/food/ui/FoodOrderDetailDialog.kt");
  const gradle = android("app/build.gradle.kts");
  assert.match(ui, /stagingPaymentEnabled &&/);
  assert.match(ui, /orderStatus == "pending_acceptance"/);
  assert.match(ui, /paymentStatus in setOf\("pending", "issue"\)/);
  assert.match(detail, /state\.stagingMobilePaymentEnabled/);
  assert.match(detail, /shouldShowStagingSlipPreview\(/);
  assert.match(gradle, /"STAGING_MOBILE_PAYMENT_ALLOWED", "false"/);
});

test("staging slip preview is translated and clearly does not submit", () => {
  const thai = android("app/src/main/res/values/strings.xml");
  const english = android("app/src/main/res/values-en/strings.xml");
  for (const content of [thai, english]) {
    for (const id of [
      "slip_preview_title",
      "slip_preview_no_upload",
      "slip_preview_selected_local",
      "slip_preview_choose",
      "slip_preview_replace",
      "slip_preview_remove",
      "slip_preview_image_description",
    ]) assert.match(content, new RegExp(`name="${id}"`));
  }
  assert.match(thai, /ยังไม่อัปโหลด/);
  assert.match(english, /does not upload or submit/);
});
