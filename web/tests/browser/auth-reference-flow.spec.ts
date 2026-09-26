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
    await page.locator('select[aria-label="วัน"]').selectOption("01");
    await page.locator('select[aria-label="เดือน"]').selectOption({ label: "มกราคม" });
    await page.locator('select[aria-label="ปี"]').selectOption("2000");

    await page.getByRole("button", { name: "หน้าถัดไป" }).click();
    await expect(page).toHaveURL(/\/signup\/step-2$/);
    await page.locator('input[name="email"]').fill("ploy@example.com");
    await page.locator('input[name="password"]').fill("password123");
    await page.locator('input[name="confirmPassword"]').fill("password123");

    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
    await expect(page.locator('input[name="username"]')).toHaveValue("ploy_journey");
    await expect(page.locator('input[name="displayName"]')).toHaveValue("พลอย เดินทาง");
    await expect(page.locator('select[aria-label="วัน"]')).toHaveValue("01");
    await expect(page.locator('select[aria-label="เดือน"]')).toHaveValue("01");
    await expect(page.locator('select[aria-label="ปี"]')).toHaveValue("2000");
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

  // WYN-166 (2026-09-19), Founder follow-up same day: a native
  // <input type="date"> displays in the browser/OS's own language, not the
  // page's — so it could show English "mm/dd/yyyy" even on an all-Thai app.
  // Replaced with 3 plain <select> boxes (วัน/เดือน/ปี) so the text is
  // always Thai regardless of the visitor's device locale. Month labels are
  // spelled-out Thai month names; the year option's visible label is the
  // Buddhist Era year (Founder-approved, พ.ศ. = ค.ศ. + 543) but its value —
  // and the value ultimately stored/validated — stays Gregorian, unchanged
  // from before. The year dropdown itself only offers years satisfying
  // MIN_ONBOARDING_AGE, but a day/month later in the calendar than today
  // within the oldest eligible year is still genuinely underage, so this
  // also confirms the JS validation on submit still catches that case
  // (reachable through completely normal UI use, not just a bypass).
  test("signup step 1 birth date is 3 Thai วัน/เดือน/ปี selects gated to the minimum onboarding age", async ({ page }) => {
    await page.goto("/signup/step-1");
    const monthOptionLabels = await page.locator('select[aria-label="เดือน"] option').allTextContents();
    expect(monthOptionLabels).toContain("มกราคม");
    expect(monthOptionLabels).toContain("ธันวาคม");
    // No English digits should leak into the visible option text.
    for (const label of monthOptionLabels) expect(label).not.toMatch(/[0-9]/);

    const yearOptionLabels = await page.locator('select[aria-label="ปี"] option').allTextContents();
    const today = new Date();
    const newestEligibleGregorianYear = today.getUTCFullYear() - 13;
    expect(yearOptionLabels[1]).toBe(String(newestEligibleGregorianYear + 543));

    await page.locator('input[name="username"]').fill("younguser");
    await page.locator('input[name="displayName"]').fill("Young User");
    await page.locator('select[aria-label="วัน"]').selectOption("31");
    await page.locator('select[aria-label="เดือน"]').selectOption({ label: "ธันวาคม" });
    await page.locator('select[aria-label="ปี"]').selectOption({ index: 1 }); // newest eligible year, but Dec 31 hasn't happened yet this year
    await page.getByRole("button", { name: "หน้าถัดไป" }).click();

    await expect(page).toHaveURL(/\/signup\/step-1$/);
    await expect(page.getByText("กรุณากรอกวันเกิดให้ถูกต้อง (อายุอย่างน้อย 13 ปี)")).toBeVisible();
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

  test("Add Account reuses the branded welcome and login UI without bottom navigation", async ({ page }) => {
    await page.goto("/account/add");
    await expect(page.getByRole("img", { name: "WYNOS" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "ทุกเรื่องราว มีจุดเริ่มต้น" })).toBeVisible();
    await expect(page.locator(".route-bottom-nav")).toHaveCount(0);

    const primaryStyles = await page.getByRole("button", { name: "สร้างบัญชีใหม่" }).first().evaluate((element) => {
      const style = getComputedStyle(element);
      return { height: style.height, borderRadius: style.borderRadius };
    });
    expect(primaryStyles).toEqual({ height: "58px", borderRadius: "24px" });
    await expect(page.getByRole("button", { name: "เข้าสู่ระบบด้วย Google" }).locator("svg")).toBeVisible();

    await page.getByRole("button", { name: "เข้าสู่ระบบ", exact: true }).click();
    await expect(page.getByRole("heading", { name: "เข้าสู่ระบบ", exact: true })).toBeVisible();
    await expect(page.getByRole("img", { name: "WYNOS" })).toBeVisible();
    await expect(page.getByRole("button", { name: "เข้าสู่ระบบและเพิ่มบัญชี" })).toBeDisabled();
    await page.getByRole("button", { name: "ย้อนกลับ" }).click();
    await expect(page.getByRole("heading", { name: "ทุกเรื่องราว มีจุดเริ่มต้น" })).toBeVisible();

    await page.getByRole("button", { name: "สร้างบัญชีใหม่" }).click();
    await expect(page).toHaveURL(/\/signup\/step-1$/);
    const pending = await page.evaluate(() => JSON.parse(localStorage.getItem("wynos.pending-add-account.v1") ?? "null"));
    expect(pending?.slot).toMatch(/^wynos\.account\./);
  });

  // WYN-165 (2026-09-19): the username field on signup step 1 wraps its
  // <Input bare> in a manually-styled box, but Input always applies the
  // shared .wyn-input class regardless of `bare`. That class's own height
  // (56px) exceeded the wrapper's content-box height (54px, after its 1px
  // border), so the input's opaque background overflowed 1px top/bottom and
  // painted over the wrapper's border — making the box look broken on
  // production. A plain boundingBox() comparison doesn't catch this (the
  // input's rendered rect coincides with the wrapper's outer rect since the
  // overflow paints over the border rather than extending past it), so this
  // compares against the wrapper's clientHeight (content box, border excluded).
  test("signup step 1 username field input never exceeds its wrapper's content box", async ({ page }) => {
    await page.goto("/signup/step-1");
    const field = page.locator(".field", { has: page.locator("label", { hasText: "ชื่อผู้ใช้" }) });
    const wrapper = field.locator("> div").first();
    const input = field.locator("input");

    const wrapperClientHeight = await wrapper.evaluate((element) => element.clientHeight);
    const inputBox = await input.boundingBox();
    expect(inputBox).not.toBeNull();
    expect(inputBox!.height).toBeLessThanOrEqual(wrapperClientHeight);
  });
});
