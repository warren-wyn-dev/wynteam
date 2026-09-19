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
    // Real production page, not a desktop-preview phone mockup: #phone must
    // fill the actual device viewport (no fixed 400x760 frame, no rounded
    // corners, no surrounding backdrop) — see the Founder's screenshot of
    // the old fake-frame rendering on a real iPhone.
    const viewport = page.viewportSize();
    const phoneStyles = await page.locator("#phone").evaluate((element) => {
      const style = getComputedStyle(element);
      const rect = element.getBoundingClientRect();
      return {
        width: rect.width,
        maxWidth: style.maxWidth,
        borderRadius: style.borderRadius,
        boxShadow: style.boxShadow,
        backgroundColor: style.backgroundColor,
      };
    });
    expect(phoneStyles.maxWidth).toBe("none");
    expect(phoneStyles.borderRadius).toBe("0px");
    expect(phoneStyles.boxShadow).toBe("none");
    expect(phoneStyles.backgroundColor).toBe("rgb(255, 255, 255)");
    expect(phoneStyles.width).toBe(viewport?.width);

    const primaryButtonStyles = await page.getByRole("button", { name: "สร้างบัญชีใหม่" }).evaluate((element) => {
      const style = getComputedStyle(element);
      return { height: style.height, borderRadius: style.borderRadius };
    });
    // WYN-163 (2026-09-19): Founder-approved "Apple-inspired" squircle pass —
    // buttons moved off the full-pill shape to a taller, more rounded-rect
    // treatment. See .wyn/docs/design/wyn-163-onboarding-button-redesign.md.
    expect(primaryButtonStyles).toEqual({ height: "58px", borderRadius: "24px" });

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
    // WYN-163 (2026-09-19): same squircle pass as the button geometry above.
    expect(inputStyles).toEqual({ height: "56px", borderRadius: "18px" });
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
    await page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true }).click();
    await expect(page).toHaveURL(/\/login$/);

    await page.getByText("ลืมรหัสผ่าน?", { exact: true }).click();
    await expect(page).toHaveURL(/\/forgot-password$/);

    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/login$/);

    await page.getByText("สร้างบัญชีใหม่", { exact: true }).last().click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
  });

  // WYN-164 (2026-09-19): regression coverage for the 2 findings from
  // WYN-163's QA round 1 — a mid-word headline wrap at 320px, and
  // /account/add silently inheriting the new button/input sizing from
  // shared auth-reference.css without the matching Google icon/headline.
  test("welcome headline stays on one line at 320px", async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 844 });
    await page.goto("/welcome");
    const tagline = page.getByText("ทุกเรื่องราว มีจุดเริ่มต้น", { exact: true });
    await expect(tagline).toBeVisible();
    const box = await tagline.boundingBox();
    // A single line at this font size is ~34-40px tall; 2 lines would be
    // roughly double that. 55px is a safe ceiling that still fails loudly
    // if the text wraps again.
    expect(box?.height ?? 0).toBeLessThan(55);
  });

  test("account/add matches the shared squircle button treatment and has a Google icon", async ({ page }) => {
    await page.goto("/account/add");
    const primaryStyles = await page.getByRole("button", { name: "เข้าสู่ระบบและเพิ่มบัญชี" }).evaluate((element) => {
      const style = getComputedStyle(element);
      return { height: style.height, borderRadius: style.borderRadius };
    });
    expect(primaryStyles).toEqual({ height: "58px", borderRadius: "24px" });

    const googleButton = page.getByRole("button", { name: "เข้าสู่ระบบด้วย Google" });
    await expect(googleButton.locator("svg")).toBeVisible();

    const headlineFontSize = await page.getByText("เพิ่มบัญชี", { exact: true }).evaluate((element) => getComputedStyle(element).fontSize);
    expect(headlineFontSize).toBe("32px");
  });
});
