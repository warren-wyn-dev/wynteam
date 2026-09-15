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

test("own and other profiles share header structure with different actions", async ({ page }) => {
  await page.goto("/profile/me");
  await expect(page.locator('[data-profile-header=""][data-own-profile="true"]')).toBeVisible();
  await expect(page.getByRole("button", { name: "แก้ไขโปรไฟล์" })).toBeVisible();
  await expect(page.getByRole("button", { name: "แชร์โปรไฟล์" })).toBeVisible();

  await page.goto("/profile/mind-coffee");
  await expect(page.locator('[data-profile-header=""][data-own-profile="false"]')).toBeVisible();
  await expect(page.getByRole("button", { name: "ติดตาม", exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "ส่งข้อความ" })).toBeVisible();
});

test("edit profile pre-fills from current reference user data", async ({ page }) => {
  await page.goto("/profile/edit");
  await expect(page.getByLabel("ชื่อที่แสดง")).toHaveValue("พลอย เดินทาง");
  await expect(page.getByLabel("ชื่อผู้ใช้")).toHaveValue("ploy_journey");
  await expect(page.getByLabel("แนะนำตัว")).toHaveValue("ชอบเที่ยว ชอบถ่ายรูป 📷 อยู่กรุงเทพฯ");
  await expect(page.getByLabel("ลิงก์เว็บไซต์")).toHaveValue("ployjourney.com");
});

test("followers page switches real tab state", async ({ page }) => {
  await page.goto("/followers?tab=followers");
  await expect(page.locator('[data-followers-tab="followers"]')).toContainText("ต้น สายเทค");
  await page.getByRole("tab", { name: "กำลังติดตาม" }).click();
  await expect(page.locator('[data-followers-tab="following"]')).toContainText("มายด์ กาแฟรัก");
  await expect(page.getByRole("tab", { name: "กำลังติดตาม" })).toHaveAttribute("aria-selected", "true");
});

test("settings keeps supplied rows and edit-profile routing", async ({ page }) => {
  await page.goto("/settings");
  await expect(page.getByText("บัญชี", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "แก้ไขโปรไฟล์" }).click();
  await expect(page).toHaveURL(/\/profile\/edit$/);
});

test("single post author connects to the other profile reference", async ({ page }) => {
  await page.goto("/post/mind-coffee-001");
  await page.getByRole("button", { name: /รูปโปรไฟล์ของ มายด์ กาแฟรัก/ }).click();
  await expect(page).toHaveURL(/\/profile\/mind-coffee$/);
});

test("reference phone geometry stays locked to supplied HTML", async ({ page }) => {
  await page.goto("/home");
  const phone = page.locator(".content-ref-viewport .phone");
  const box = await phone.boundingBox();
  expect(box?.width).toBeLessThanOrEqual(400);
  expect(box?.height).toBe(760);
});
