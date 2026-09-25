import { expect, test } from "@playwright/test";

// The fixture uses a fake Supabase client; no live posts or drafts are made.
test.use({ serviceWorkers: "block" });

for (const [width, height] of [[320, 568], [390, 844], [432, 932]]) {
  test(`Cancel slides the mobile composer down before unmount at ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
    const composer = page.getByRole("dialog", { name: "สร้างโพสต์" });
    const backdrop = page.locator(".beta4-composer-backdrop");
    await expect(composer).toBeVisible();
    await composer.getByRole("button", { name: "ยกเลิก" }).click();
    await expect(backdrop).toHaveClass(/is-closing/);
    await expect(composer).toHaveCSS("animation-name", "wyn-composer-sheet-dismiss");
    await expect(page.getByTestId("composer-closed")).toBeVisible();
    await expect(composer).toHaveCount(0);
  });
}

test("tapping the backdrop dismisses an empty post with the same slide", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
  await page.mouse.click(8, 8);
  await expect(page.locator(".beta4-composer-backdrop")).toHaveClass(/is-closing/);
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("draft confirmation remains before the slide; canceling the prompt preserves text", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const composer = page.getByRole("dialog", { name: "สร้างโพสต์" });
  const caption = composer.locator("textarea.beta4-compose-text");
  await caption.fill("ข้อความที่ต้องเก็บไว้");
  await composer.getByRole("button", { name: "ยกเลิก" }).click();
  const confirmation = page.getByRole("alertdialog", { name: "บันทึกเป็นร่างก่อนออกไหม?" });
  await expect(confirmation).toBeVisible();
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await confirmation.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(confirmation).toHaveCount(0);
  await expect(caption).toHaveValue("ข้อความที่ต้องเก็บไว้");
  await composer.getByRole("button", { name: "ยกเลิก" }).click();
  await confirmation.getByRole("button", { name: "ทิ้ง" }).click();
  await expect(page.locator(".beta4-composer-backdrop")).toHaveClass(/is-closing/);
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("reduced-motion users dismiss without any exit animation delay", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
  await expect(page.locator(".beta4-composer")).toHaveCSS("animation-name", "none");
  await page.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});
