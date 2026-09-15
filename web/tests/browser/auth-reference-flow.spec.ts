import { expect, test } from "@playwright/test";

test.describe("HTML-reference auth flow", () => {
  test("six routes render and preserve source geometry", async ({ page }) => {
    const routes = [
      ["/welcome", "ทุกเรื่องราว มีจุดเริ่มต้น"],
      ["/signup/step-1", "สร้างบัญชี"],
      ["/signup/step-2", "ตั้งรหัสผ่าน"],
      ["/onboarding/profile", "เพิ่มรูปโปรไฟล์"],
      ["/login", "เข้าสู่ระบบ"],
      ["/forgot-password", "ลืมรหัสผ่าน?"],
    ] as const;

    for (const [route, text] of routes) {
      await page.goto(route);
      await expect(page.getByText(text, { exact: true }).first()).toBeVisible();
      await expect(page.locator("#phone")).toBeVisible();
    }

    await page.goto("/welcome");
    const phoneStyles = await page.locator("#phone").evaluate((element) => {
      const style = getComputedStyle(element);
      return {
        maxWidth: style.maxWidth,
        height: style.height,
        borderRadius: style.borderRadius,
        backgroundColor: style.backgroundColor,
      };
    });
    expect(phoneStyles).toEqual({
      maxWidth: "400px",
      height: "760px",
      borderRadius: "28px",
      backgroundColor: "rgb(255, 255, 255)",
    });

    const primaryButtonStyles = await page.getByRole("button", { name: "สร้างบัญชีใหม่" }).evaluate((element) => {
      const style = getComputedStyle(element);
      return { height: style.height, borderRadius: style.borderRadius };
    });
    expect(primaryButtonStyles).toEqual({ height: "50px", borderRadius: "999px" });

    await page.goto("/signup/step-1");
    const topbarStyles = await page.locator(".topbar").evaluate((element) => {
      const style = getComputedStyle(element);
      return { paddingTop: style.paddingTop, paddingRight: style.paddingRight, paddingBottom: style.paddingBottom, paddingLeft: style.paddingLeft };
    });
    expect(topbarStyles).toEqual({ paddingTop: "14px", paddingRight: "16px", paddingBottom: "14px", paddingLeft: "16px" });

    const inputStyles = await page.locator('input[name="displayName"]').evaluate((element) => {
      const style = getComputedStyle(element);
      return { height: style.height, borderRadius: style.borderRadius };
    });
    expect(inputStyles).toEqual({ height: "44px", borderRadius: "10px" });
  });

  test("signup step 1 state survives step 2 and the in-flow back button", async ({ page }) => {
    await page.goto("/signup/step-1");
    await page.locator('input[name="username"]').fill("ploy_journey");
    await page.locator('input[name="displayName"]').fill("พลอย เดินทาง");
    await page.locator('input[name="birthDate"]').fill("01 / 01 / 2000");

    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-2$/);
    await page.locator('input[name="email"]').fill("ploy@example.com");
    await page.locator('input[name="password"]').fill("password123");
    await page.locator('input[name="confirmPassword"]').fill("password123");

    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
    await expect(page.locator('input[name="username"]')).toHaveValue("ploy_journey");
    await expect(page.locator('input[name="displayName"]')).toHaveValue("พลอย เดินทาง");
    await expect(page.locator('input[name="birthDate"]')).toHaveValue("01 / 01 / 2000");
  });

  test("reference buttons connect the auth routes", async ({ page }) => {
    await page.goto("/welcome");
    await page.getByRole("button", { name: "เข้าสู่ระบบ" }).click();
    await expect(page).toHaveURL(/\/login$/);

    await page.getByText("ลืมรหัสผ่าน?", { exact: true }).click();
    await expect(page).toHaveURL(/\/forgot-password$/);

    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/login$/);

    await page.getByText("สร้างบัญชีใหม่", { exact: true }).last().click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
  });
});
