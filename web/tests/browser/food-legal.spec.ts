import { expect, test } from "@playwright/test";

test.describe("ZOKY public policy drafts", () => {
  test.use({ serviceWorkers: "block" });

  test("policies are readable without signing in and remain drafts before operator approval", async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    for (const [path, title] of [
      ["/food/terms", "ข้อกำหนดการใช้งาน ZOKY"],
      ["/food/privacy", "นโยบายความเป็นส่วนตัว ZOKY"],
    ]) {
      const response = await page.goto(path);
      expect(response?.status()).toBe(200);
      await expect(page.getByRole("heading", { name: title, exact: true })).toBeVisible();
      await expect(page.getByText("ฉบับร่าง ยังไม่มีผลบังคับใช้", { exact: true })).toBeVisible();
      await expect(page.locator('meta[name="robots"]')).toHaveAttribute("content", /noindex/);
      await expect(page.locator('input[type="password"]')).toHaveCount(0);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    }
    expect(errors).toEqual([]);
  });

  test("signup links open both documents and return to the ZOKY account flow", async ({ page }) => {
    const errors: string[] = [];
    const externalAuthCalls: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.route(/\/(?:auth|rest|storage|functions)\/v1(?:\/|$)/, async (route) => {
      externalAuthCalls.push(route.request().url());
      await route.fulfill({ status: 403, contentType: "application/json", body: "{}" });
    });
    await page.goto("/food/signup");
    await page.getByRole("link", { name: "ข้อกำหนดการใช้งาน", exact: true }).click();
    await expect(page).toHaveURL(/\/food\/terms$/);
    await expect(page.getByRole("heading", { name: "ข้อกำหนดการใช้งาน ZOKY", exact: true })).toBeVisible();
    await page.getByRole("link", { name: "← กลับไปสมัคร ZOKY", exact: true }).click();
    await expect(page.getByRole("heading", { name: "สมัคร ZOKY", exact: true })).toBeVisible();
    await page.getByRole("link", { name: "นโยบายความเป็นส่วนตัว", exact: true }).click();
    await expect(page).toHaveURL(/\/food\/privacy$/);
    await expect(page.getByRole("heading", { name: "นโยบายความเป็นส่วนตัว ZOKY", exact: true })).toBeVisible();
    await page.getByRole("link", { name: "เข้าสู่ระบบ ZOKY", exact: true }).click();
    await expect(page.getByRole("heading", { name: "เข้าสู่ระบบ ZOKY", exact: true })).toBeVisible();
    expect(externalAuthCalls).toEqual([]);
    expect(errors).toEqual([]);
  });
});
