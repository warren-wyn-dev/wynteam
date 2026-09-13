import { expect, test } from "@playwright/test";

test("signed-out Welcome mirrors the Flutter golden master", async ({ page }) => {
  await page.goto("/", { waitUntil: "networkidle" });

  await expect(page.getByRole("heading", { name: "WYNOS" })).toBeVisible();
  await expect(page.getByText("BETA", { exact: true })).toBeVisible();
  await expect(page.getByText("เชื่อมต่อ แสดงตัวตน และสร้างชุมชนของคุณเอง", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "เริ่มต้นใช้งาน" })).toBeVisible();
  await expect(page.getByText(/Next\.js Web รุ่นทดสอบภายใน/)).toHaveCount(0);

  const metrics = await page.evaluate(() => {
    const title = document.querySelector<HTMLElement>(".parity-wordmark-line h1");
    const cta = document.querySelector<HTMLElement>(".parity-welcome-cta");
    if (!title || !cta) return null;
    return {
      titleSize: getComputedStyle(title).fontSize,
      titleWeight: getComputedStyle(title).fontWeight,
      ctaHeight: cta.getBoundingClientRect().height,
    };
  });

  expect(metrics).not.toBeNull();
  expect(metrics!.titleSize).toBe("34px");
  expect(Number(metrics!.titleWeight)).toBe(500);
  expect(metrics!.ctaHeight).toBeGreaterThanOrEqual(56);
});

test("Welcome continues to the original auth-method and email flows", async ({ page }) => {
  await page.goto("/", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "เริ่มต้นใช้งาน" }).click();

  await expect(page.getByRole("heading", { name: "เข้าสู่ระบบ WYNOS" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วย Google" })).toBeVisible();
  await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วยอีเมล" })).toBeVisible();

  await page.getByRole("button", { name: "เข้าสู่ระบบด้วยอีเมล" }).click();
  await expect(page.getByText("สมัครสมาชิก", { exact: true }).first()).toBeVisible();
  await expect(page.getByLabel("อีเมล")).toBeVisible();
  await expect(page.getByLabel("รหัสผ่าน")).toBeVisible();
  await expect(page.getByText("อย่างน้อย 6 ตัวอักษร", { exact: true })).toBeVisible();
});
