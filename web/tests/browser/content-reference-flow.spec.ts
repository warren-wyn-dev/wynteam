import { expect, test } from "@playwright/test";

test("reference home renders reusable feed cards and routes by post id", async ({ page }) => {
  await page.goto("/home");
  await expect(page.getByText("สำหรับคุณ")).toBeVisible();
  await expect(page.locator(".wyn-post-card--feed")).toHaveCount(2);
  await page.getByText("เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด แนะนำเลยถ้าใครผ่านแถวนี้").click();
  await expect(page).toHaveURL(/\/post\/mind-coffee-001$/);
  await expect(page.getByText("@mind_coffee")).toBeVisible();
});

test("compose supports text, poll and image conditional modes", async ({ page }) => {
  await page.goto("/compose-post");
  await expect(page.locator("[data-compose-mode]")).toHaveCount(0);
  await page.getByRole("button", { name: "สร้างโพล" }).click();
  await expect(page.locator('[data-compose-mode="poll"]')).toBeVisible();
  await page.getByRole("button", { name: "แนบรูป" }).click();
  await expect(page.locator('[data-compose-mode="image"]')).toBeVisible();
  await page.getByRole("button", { name: "แนบรูป" }).click();
  await expect(page.locator("[data-compose-mode]")).toHaveCount(0);
});

test("notifications reference surface is wired back to home", async ({ page }) => {
  await page.goto("/notifications");
  await expect(page.getByText("การแจ้งเตือน")).toBeVisible();
  await expect(page.getByText("กดใจโพสต์ของคุณ")).toBeVisible();
});

test("search renders four ranked Thailand trends", async ({ page }) => {
  await page.goto("/search");
  await expect(page.getByText("กำลังมาแรงในไทย")).toBeVisible();
  await expect(page.locator(".trend-row")).toHaveCount(4);
  await expect(page.locator(".trend-row").nth(3)).toContainText("#Wynos");
});

test("reference phone geometry stays locked to supplied HTML", async ({ page }) => {
  await page.goto("/home");
  const phone = page.locator(".content-ref-viewport .phone");
  const box = await phone.boundingBox();
  expect(box?.width).toBeLessThanOrEqual(400);
  expect(box?.height).toBe(760);
});
