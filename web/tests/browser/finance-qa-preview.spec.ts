import { expect, test } from "@playwright/test";

// REAL React component, but local CI-only mock SupabaseClient fixture.
// This does not prove Supabase signed-JWT / PostgREST authorization.
const PATH = "/finance-qa-ci-fixture";
const QA_ORDER = "10000000-0000-4000-8000-000000000002";
const NO_PROJECTION = "10000000-0000-4000-8000-000000000003";

test("Finance v2 QA Preview renders simulation-only daily/monthly buckets", async ({ page }) => {
  await page.goto(PATH);
  const preview = page.getByRole("region", { name: "พรีวิวรายงานการเงิน QA" });
  await expect(preview.getByRole("heading", { name: "Finance v2 · QA Preview" })).toBeVisible();
  await expect(preview.getByText("ข้อมูลจำลองเท่านั้น")).toBeVisible();
  await expect(preview.getByText("ยอดชำระจำลอง")).toBeVisible();
  await expect(preview.getByText("GP Reversal จำลอง")).toBeVisible();
  await expect(preview.getByText("ค่าธรรมเนียม Stripe: ไม่ทราบ")).toBeVisible();
  await expect(preview.getByText("ยอดโอนสุทธิ: ยังไม่ได้กระทบยอด")).toBeVisible();
  await expect(preview.locator("tbody tr")).toHaveCount(1);
  await expect(preview.locator("tbody tr")).toContainText("2026-10-08");
  await expect(preview.locator("tbody tr")).toContainText("0.00");
  await preview.getByLabel("แสดงผล").selectOption("month");
  await expect.poll(async () => page.evaluate(() =>
    window.__qaFinanceRequests?.findLast(r =>
      r.method === "merchant_food_finance_buckets_v2_qa")?.args.p_granularity
  )).toBe("month");
  await expect(preview.getByText("ข้อมูลจำลองเท่านั้น")).toBeVisible();
});

test("Finance QA date validation and invalid order id fail closed", async ({ page }) => {
  await page.goto(PATH);
  const preview = page.getByRole("region", { name: "พรีวิวรายงานการเงิน QA" });
  await expect(preview.getByText("ยอดชำระจำลอง")).toBeVisible();
  await preview.getByLabel("UUID ออเดอร์ QA").fill("invalid");
  await preview.getByRole("button", { name: "ตรวจออเดอร์" }).click();
  await expect(preview.getByText("กรุณากรอก UUID ออเดอร์ QA ที่ถูกต้อง")).toBeVisible();
  await preview.getByLabel("เริ่มต้น").fill("2026-12-31");
  await preview.getByLabel("สิ้นสุด").fill("2026-01-01");
  await expect(preview.getByText("เลือกช่วงวันที่ไม่เกิน 366 วัน")).toBeVisible();
  await expect(preview.getByText("ยอดชำระจำลอง")).toHaveCount(0);
});

test("Order QA detail uses owner-only RPC mock, no customer PII or actual payout", async ({ page }) => {
  await page.goto(PATH);
  const preview = page.getByRole("region", { name: "พรีวิวรายงานการเงิน QA" });
  await expect(preview.getByText("ยอดชำระจำลอง")).toBeVisible();
  await preview.getByLabel("UUID ออเดอร์ QA").fill(QA_ORDER);
  await preview.getByRole("button", { name: "ตรวจออเดอร์" }).click();
  await expect(preview.getByText(/QA-ORDER-0002/)).toBeVisible();
  await expect(preview.getByText(/GP 750 bps/)).toBeVisible();
  await expect.poll(async () => page.evaluate(() =>
    window.__qaFinanceRequests?.some(r => r.method === "merchant_food_finance_order_details_v2_qa")
  )).toBe(true);
  await expect(preview).not.toContainText("stripe_payment_intent_id");
  await expect(preview).not.toContainText("recipient_phone");
  await preview.getByLabel("UUID ออเดอร์ QA").fill(NO_PROJECTION);
  await preview.getByRole("button", { name: "ตรวจออเดอร์" }).click();
  await expect(preview.getByText("ออเดอร์นี้ยังไม่มี Finance Projection ใน QA")).toBeVisible();
});

test("Unauthorized mock RPC errors are not converted to optimistic balances", async ({ page }) => {
  await page.goto(PATH + "?scenario=forbidden");
  const preview = page.getByRole("region", { name: "พรีวิวรายงานการเงิน QA" });
  await expect(preview.getByText("ไม่สามารถอ่านรายงาน QA ได้ กรุณาตรวจสอบสิทธิ์เจ้าของร้าน")).toBeVisible();
  await expect(preview.getByText("ยอดชำระจำลอง")).toHaveCount(0);
  await preview.getByLabel("UUID ออเดอร์ QA").fill(QA_ORDER);
  await preview.getByRole("button", { name: "ตรวจออเดอร์" }).click();
  await expect(preview.getByText("อ่านรายละเอียดไม่ได้ หรือไม่มีสิทธิ์")).toBeVisible();
  await expect(preview).not.toContainText("QA-ORDER-0002");
});
