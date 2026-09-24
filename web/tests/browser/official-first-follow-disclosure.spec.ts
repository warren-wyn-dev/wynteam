import { expect, test } from "@playwright/test";

test.describe("Official first-follow signup disclosure", () => {
  test("new members see clear Official auto-follow and unfollow terms before signing up", async ({ page }) => {
    await page.goto("/signup/step-1");
    const disclosure = page.getByText("เมื่อสมัครบัญชีใหม่ คุณจะติดตามบัญชี Official @wynos_s โดยอัตโนมัติ และสามารถเลิกติดตามได้ทุกเมื่อ");
    await expect(disclosure).toBeVisible();
    await expect(page.getByRole("button", { name: "หน้าถัดไป" })).toBeVisible();
  });
});
