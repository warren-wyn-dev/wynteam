import { expect, test } from "@playwright/test";

test.describe("Web Beta1 email signup security", () => {
  // The mocked public username RPC must not be claimed by an installed PWA service worker on WebKit.
  test.use({ serviceWorkers: "block" });
  test("signup rejects a password shorter than twelve characters before calling Auth", async ({ page }) => {
    // The prior password-only regression runs with a fake Supabase origin.
    // Stub the new availability gate so it can reach the password step.
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: "true" });
    });
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
    // The keyed 220ms exit/entry animation used to remount the auth layout
    // after inputs were already interactive, silently clearing the form.
    await page.waitForTimeout(600);
    await expect(page.locator('input[name="email"]')).toHaveValue("policy@example.invalid");
    await expect(page.locator('input[name="password"]')).toHaveValue("12345678901");
    await expect(page.locator('input[name="confirmPassword"]')).toHaveValue("12345678901");
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
