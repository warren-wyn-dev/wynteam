import { expect, test } from "@playwright/test";

test.describe("Web Beta1 password recovery", () => {
  // Installed PWA service workers can claim the page midway through recovery;
  // Playwright page.route does not intercept requests from service workers.
  // Block them in this isolated Auth API mock suite, not in production.
  test.use({ serviceWorkers: "block" });
  test("opening the reset page without a recovery link never exposes password inputs", async ({ page }) => {
    await page.goto("/reset-password");
    await expect(page.getByRole("heading", { name: "ตั้งรหัสผ่านใหม่" })).toBeVisible();
    await expect(page.locator("#phone p[role=alert]")).toContainText("ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ");
    await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
    await page.getByRole("button", { name: "ขอลิงก์ใหม่" }).click();
    await expect(page).toHaveURL(/\/forgot-password$/);
  });

  test("an expired recovery link clears sensitive query and fragment immediately", async ({ page }) => {
    await page.goto("/reset-password?error=access_denied&code=must-disappear#access_token=hidden");
    await expect(page.locator("#phone p[role=alert]")).toContainText("ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ");
    await expect(page).toHaveURL(/\/reset-password$/);
    await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
  });

  test("a legacy recovery query URL also waits for a deliberate tap", async ({ page }) => {
    await page.goto("/reset-password?token_hash=unused-legacy-hash&type=recovery");
    await expect(page.getByRole("button", { name: "ยืนยันและตั้งรหัสผ่านใหม่" })).toBeVisible();
    await expect(page).toHaveURL(/\/reset-password$/);
    await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
  });

  test("a signup token hash does not unlock password recovery", async ({ page }) => {
    await page.goto("/reset-password?token_hash=fake&type=signup");
    await expect(page.locator("#phone p[role=alert]")).toContainText("ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ");
    await expect(page).toHaveURL(/\/reset-password$/);
  });

  test("Food recovery renders ZOKY from the server and returns to Food login", async ({ page, request }) => {
    const path = "/forgot-password?returnTo=%2Ffood%2Flogin";
    const response = await request.get(path);
    expect(response.ok()).toBe(true);
    expect(await response.text()).toContain('data-auth-product="zoky"');

    const errors: string[] = [];
    page.on("pageerror", (error) => errors.push(error.message));
    page.on("console", (message) => {
      if (message.type() === "error" && /hydrat|server.rendered/i.test(message.text())) errors.push(message.text());
    });
    await page.goto(path);
    await expect(page).toHaveTitle("ลืมรหัสผ่าน — ZOKY");
    await expect(page.locator(".password-recovery-brand")).toHaveText("ZOKY");
    await page.getByRole("button", { name: "ส่งลิงก์รีเซ็ตรหัสผ่าน" }).click();
    await expect(page.locator("#phone p[role=alert]")).toHaveText("กรุณากรอกอีเมลให้ถูกต้อง");
    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/food\/login$/);
    expect(errors).toEqual([]);
  });

  test("Food recovery removes the token but preserves its destination after reload", async ({ page }) => {
    await page.goto("/reset-password?returnTo=%2Ffood%2Flogin&untrusted=discard#type=recovery&token_hash=unused-food-recovery");
    await expect(page.getByRole("button", { name: "ยืนยันและตั้งรหัสผ่านใหม่" })).toBeVisible();
    await expect(page).toHaveURL(/\/reset-password\?returnTo=%2Ffood%2Flogin$/);
    await expect(page).toHaveTitle("ตั้งรหัสผ่านใหม่ — ZOKY");
    await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);

    await page.reload();
    await expect(page.locator("#phone p[role=alert]")).toContainText("ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ");
    await expect(page.locator(".password-recovery-brand")).toHaveText("ZOKY");
    await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
    await page.getByRole("button", { name: "ขอลิงก์ใหม่" }).click();
    await expect(page).toHaveURL(/\/forgot-password\?returnTo=%2Ffood%2Flogin$/);
    await expect(page.locator(".password-recovery-brand")).toHaveText("ZOKY");
    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/food\/login$/);
  });

  test("an external recovery destination is discarded without changing Social recovery", async ({ page }) => {
    await page.goto("/reset-password?returnTo=https%3A%2F%2Fexample.test&error=expired#access_token=discard");
    await expect(page.locator("#phone p[role=alert]")).toContainText("ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ");
    await expect(page).toHaveURL(/\/reset-password$/);
    await expect(page.locator(".password-recovery-brand")).toHaveCount(0);
    await expect(page).toHaveTitle("Wynos — ตั้งรหัสผ่านใหม่");
    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/login$/);
  });

  for (const returnTo of ["/login", "/food/login"] as const) {
    test(`a recovery token requires a user click and returns to ${returnTo} after saving`, async ({ page }) => {
      test.skip(!process.env.NEXT_PUBLIC_SUPABASE_URL, "Fake Auth API configured only in focused security QA");
      const origin = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL!).origin;
      const user = {
        id: "9f8669bd-a864-4f41-a494-cc3226e21d77",
        aud: "authenticated",
        role: "authenticated",
        email: "recovery@example.test",
        app_metadata: { provider: "email", providers: ["email"] },
        user_metadata: {},
        created_at: "2026-09-01T00:00:00Z",
      };
      const jwt = [
        Buffer.from('{"alg":"HS256","typ":"JWT"}').toString("base64url"),
        Buffer.from(JSON.stringify({ exp: Math.floor(Date.now() / 1000) + 3600, sub: user.id, role: "authenticated" })).toString("base64url"),
        "test-signature",
      ].join(".");
      const session = {
        access_token: jwt,
        refresh_token: "test-only-refresh",
        expires_in: 3600,
        expires_at: Math.floor(Date.now() / 1000) + 3600,
        token_type: "bearer",
        user,
      };
      let verifyCount = 0;
      const passwordUpdates: string[] = [];
      await page.context().route(origin + "/auth/v1/**", async (route) => {
        const req = route.request();
        const url = new URL(req.url());
        if (url.pathname.endsWith("/verify") && req.method() === "POST") {
          const body = req.postDataJSON() as { token_hash?: string; type?: string };
          expect(body.token_hash).toBe("one-time-recovery-hash");
          expect(body.type).toBe("recovery");
          verifyCount += 1;
          await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(session) });
        } else if (url.pathname.endsWith("/user") && req.method() === "GET") {
          await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(user) });
        } else if (url.pathname.endsWith("/user") && req.method() === "PUT") {
          const body = req.postDataJSON() as { password?: string };
          passwordUpdates.push(body.password ?? "");
          await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(user) });
        } else {
          await route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
        }
      });

      // The email link goes to our app, not Supabase /verify. A scanner can
      // prefetch this URL without consuming the one-time recovery credential.
      const query = returnTo === "/food/login" ? "?returnTo=%2Ffood%2Flogin" : "";
      await page.goto(`/reset-password${query}#type=recovery&token_hash=one-time-recovery-hash`);
      await expect(page).toHaveURL(new RegExp(`/reset-password${query ? "\\?returnTo=%2Ffood%2Flogin" : ""}$`));
      await expect(page.getByRole("button", { name: "ยืนยันและตั้งรหัสผ่านใหม่" })).toBeVisible();
      await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
      expect(verifyCount).toBe(0);
      await page.getByRole("button", { name: "ยืนยันและตั้งรหัสผ่านใหม่" }).click();
      await expect(page.getByText("บัญชี: recovery@example.test")).toBeVisible();
      await expect(page.locator('input[name="newPassword"]')).toBeVisible();
      expect(verifyCount).toBe(1);

      await page.locator('input[name="newPassword"]').fill("12345678901");
      await page.locator('input[name="confirmNewPassword"]').fill("12345678901");
      await page.getByRole("button", { name: "บันทึกรหัสผ่านใหม่" }).click();
      await expect(page.locator("#phone p[role=alert]")).toContainText("อย่างน้อย 12 ตัวอักษร");
      expect(passwordUpdates).toEqual([]);

      await page.locator('input[name="newPassword"]').fill("strongPassword2026!");
      await page.locator('input[name="confirmNewPassword"]').fill("mismatchPassword");
      await page.getByRole("button", { name: "บันทึกรหัสผ่านใหม่" }).click();
      await expect(page.locator("#phone p[role=alert]")).toContainText("ไม่ตรงกัน");
      expect(passwordUpdates).toEqual([]);

      await page.locator('input[name="confirmNewPassword"]').fill("strongPassword2026!");
      await page.getByRole("button", { name: "บันทึกรหัสผ่านใหม่" }).click();
      await expect(page.getByText("เปลี่ยนรหัสผ่านสำเร็จแล้ว", { exact: false })).toBeVisible();
      expect(passwordUpdates).toEqual(["strongPassword2026!"]);
      await expect(page.locator('input[name="newPassword"]')).toHaveCount(0);
      await page.getByRole("button", { name: "ไปหน้าเข้าสู่ระบบ" }).click();
      await expect(page).toHaveURL(new URL(returnTo, page.url()).href);
    });
  }
});
