import { expect, test } from "@playwright/test";

test.describe("Web Beta1 email signup security", () => {
  test("signup rejects a password shorter than twelve characters before calling Auth", async ({ page }) => {
    await page.goto("/signup/step-1");
    await page.locator('input[name="username"]').fill("signup_policy_test");
    await page.locator('input[name="displayName"]').fill("Signup Policy");
    await page.locator('select[aria-label="วัน"]').selectOption("01");
    await page.locator('select[aria-label="เดือน"]').selectOption("01");
    await page.locator('select[aria-label="ปี"]').selectOption("2000");
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-2$/);

    await expect(page.locator('input[name="password"]')).toHaveAttribute("placeholder", "อย่างน้อย 12 ตัวอักษร");
    await page.locator('input[name="email"]').fill("policy@example.invalid");
    await expect(page.locator('input[name="email"]')).toHaveValue("policy@example.invalid");
    await page.locator('input[name="password"]').fill("12345678901");
    await page.locator('input[name="confirmPassword"]').fill("12345678901");
    await page.getByRole("button", { name: "สร้างบัญชี", exact: true }).click();

    await expect(page.locator("#phone p[role=alert]")).toHaveText("รหัสผ่านต้องมีอย่างน้อย 12 ตัวอักษร");
    await expect(page).toHaveURL(/\/signup\/step-2$/);
  });

  test("an invalid email confirmation callback fails safely without leaking its code", async ({ page }) => {
    await page.goto("/auth/callback?error=access_denied&code=should-not-remain");
    await expect(page.locator("main p[role=alert]")).toContainText("ยืนยันอีเมลไม่สำเร็จ");
    await expect(page).toHaveURL(/\/auth\/callback$/);
    await expect(page.getByRole("button", { name: "ไปหน้าเข้าสู่ระบบ" })).toBeVisible();
  });
});
