import { expect, test } from "@playwright/test";

test.describe("signup username availability before account creation", () => {
  // Mock only the public boolean endpoint. No production accounts are created.
  test.use({ serviceWorkers: "block" });
  test.skip(!process.env.NEXT_PUBLIC_SUPABASE_URL, "Requires mocked public Supabase client in focused security QA");

  async function fillBasics(page: import("@playwright/test").Page, username: string) {
    await page.goto("/signup/step-1");
    await page.locator('input[name="username"]').fill(username);
    await page.locator('input[name="displayName"]').fill("Signup QA");
    await page.locator('select[aria-label="วัน"]').selectOption("01");
    await page.locator('select[aria-label="เดือน"]').selectOption("01");
    await page.locator('select[aria-label="ปี"]').selectOption("2000");
  }

  test("shows taken name under its field and blocks Next before collecting email", async ({ page }) => {
    const names: string[] = [];
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => {
      names.push((route.request().postDataJSON() as { p_username: string }).p_username);
      await route.fulfill({ status: 200, contentType: "application/json", body: "false" });
    });
    await fillBasics(page, "existing_user");
    await expect(page.locator("#signup-username-status")).toHaveText("ชื่อผู้ใช้นี้ถูกใช้แล้ว กรุณาเลือกชื่ออื่น");
    expect(names).toContain("existing_user");
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
    await expect(page.locator("#phone p[role=alert]")).toContainText("ชื่อผู้ใช้นี้ถูกใช้แล้ว");
    await expect(page.locator('input[name="email"]')).toHaveCount(0);
  });

  test("accepts free names, ignores stale responses, and allows Next", async ({ page }) => {
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => {
      const name = (route.request().postDataJSON() as { p_username: string }).p_username;
      await route.fulfill({ status: 200, contentType: "application/json", body: name === "already_used" ? "false" : "true" });
    });
    await fillBasics(page, "already_used");
    await expect(page.locator("#signup-username-status")).toContainText("ถูกใช้แล้ว");
    await page.locator('input[name="username"]').fill("fresh_user");
    await expect(page.locator("#signup-username-status")).toHaveText("ชื่อผู้ใช้นี้ใช้ได้");
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-2$/);
  });

  test("cannot treat lookup errors as availability", async ({ page }) => {
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => {
      await route.fulfill({ status: 503, contentType: "application/json", body: '{"code":"PGRST000","message":"Unavailable"}' });
    });
    await fillBasics(page, "server_error");
    await expect(page.locator("#signup-username-status")).toContainText("ตรวจสอบชื่อผู้ใช้ไม่ได้");
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
    await expect(page.locator("#phone p[role=alert]")).toContainText("ตรวจสอบชื่อผู้ใช้ไม่ได้");
  });

  test("rechecks at step 2 before creating Auth user when name was claimed meanwhile", async ({ page }) => {
    let lookups = 0;
    let signupRequests = 0;
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => {
      lookups += 1;
      await route.fulfill({ status: 200, contentType: "application/json", body: lookups >= 3 ? "false" : "true" });
    });
    await page.route("**/auth/v1/signup**", async (route) => {
      signupRequests += 1;
      await route.fulfill({ status: 500, body: "{}" });
    });
    await fillBasics(page, "race_user");
    await expect(page.locator("#signup-username-status")).toHaveText("ชื่อผู้ใช้นี้ใช้ได้");
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-2$/);
    await page.locator('input[name="email"]').fill("race@example.invalid");
    await page.locator('input[name="password"]').fill("strongPassword2026!");
    await page.locator('input[name="confirmPassword"]').fill("strongPassword2026!");
    await page.getByRole("button", { name: "สร้างบัญชี", exact: true }).click();
    await expect(page.locator("#phone p[role=alert]")).toContainText("ย้อนกลับไปเปลี่ยนชื่อผู้ใช้");
    expect(signupRequests).toBe(0);
  });

  test("reserved and invalid values do not call public endpoint", async ({ page }) => {
    let calls = 0;
    await page.route("**/rest/v1/rpc/is_signup_username_available", async (route) => { calls++; await route.fulfill({ status: 200, body: "true" }); });
    await fillBasics(page, "admin");
    await expect(page.locator("#signup-username-status")).toContainText("ถูกใช้แล้ว");
    await page.locator('input[name="username"]').fill("bad-name!");
    await expect(page.locator("#signup-username-status")).toContainText("3–20");
    expect(calls).toBe(0);
  });
});
