import { expect, test } from "@playwright/test";

test("Phase 3 Plus stays non-billing when developer preview is disabled", async ({ page }) => {
  test.skip(process.env.NEXT_PUBLIC_WYNOS_PLUS_PREVIEW === "1", "Feature-enabled staging has a separate owner-authenticated acceptance gate");
  await page.goto("/plus", { waitUntil: "networkidle" });
  await expect(page.getByRole("heading", { name: "WYNOS Plus" })).toBeVisible();
  await expect(page.getByText("ระบบสมาชิกกำลังพัฒนา และยังไม่เปิดรับสมัคร")).toBeVisible();
  await expect(page.getByRole("button", { name: /ชำระ|สมัคร/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "กลับไปการตั้งค่า" })).toHaveAttribute("href", "/settings");
});
