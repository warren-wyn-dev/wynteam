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

test("single post author connects to the other profile route", async ({ page }) => {
  await page.goto("/post/mind-coffee-001");
  const profileRequest = page.waitForRequest((request) => request.url().includes("/profile/mind-coffee"));
  await page.getByRole("button", { name: /รูปโปรไฟล์ของ มายด์ กาแฟรัก/ }).click();
  await profileRequest;
});

test("club invite reference keeps the supplied QR and invite URL", async ({ page }) => {
  await page.goto("/club/wynos-community/invite");
  await expect(page.getByText("เชิญเข้าคลับ", { exact: true })).toBeVisible();
  await expect(page.getByText("wynos.app/invite/coffeeclub", { exact: true })).toBeVisible();
  await expect(page.getByText("คัดลอก", { exact: true })).toBeVisible();
});
