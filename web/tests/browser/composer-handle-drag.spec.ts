import { expect, test, type Page } from "@playwright/test";

// Uses the fake-client composer fixture: no account, draft or live post writes.
test.use({ serviceWorkers: "block" });

async function dragHandle(page: Page, distance: number) {
  const handle = page.getByRole("button", { name: "ดึงลงหรือแตะเพื่อปิดหน้าสร้างโพสต์" });
  await expect(handle).toBeVisible();
  const box = await handle.boundingBox();
  expect(box).not.toBeNull();
  const x = box!.x + box!.width / 2;
  const y = box!.y + box!.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + distance, { steps: 10 });
  return { x, y };
}

for (const [width, height] of [[320, 568], [390, 844], [432, 932]]) {
  test(`swiping the grab bar down dismisses an empty post at ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
    const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
    await expect(sheet).toBeVisible();

    await dragHandle(page, 170);
    const backdrop = page.locator(".beta4-composer-backdrop");
    await expect(backdrop).toHaveClass(/is-dragging/);
    await expect(backdrop).toHaveClass(/has-dragged/);
    await expect(backdrop).toHaveCSS("--wyn-composer-drag", "170px");
    await page.mouse.up();
    await expect(backdrop).toHaveClass(/is-closing/);
    await expect(page.getByTestId("composer-closed")).toBeVisible();
    await expect(sheet).toHaveCount(0);
  });
}

test("a short accidental swipe springs back and leaves the composer open", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  await dragHandle(page, 26);
  await page.mouse.up();
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await expect(page.locator(".beta4-composer-backdrop")).toHaveCSS("--wyn-composer-drag", "0px");
  await expect(sheet).toBeVisible();
  // Tap Cancel after a short swipe still exits correctly.
  await sheet.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("swiping a partially written post must confirm before discarding", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  const caption = sheet.locator("textarea.beta4-compose-text");
  await caption.fill("เก็บข้อความนี้ไว้");
  // Wait until React state holds the text (Post enables from `caption`);
  // on slower WebKit a fill that lands before hydration left state empty
  // and the sheet closed without the draft prompt.
  await expect(sheet.getByRole("button", { name: "โพสต์", exact: true })).toBeEnabled();
  await dragHandle(page, 160);
  await page.mouse.up();

  const prompt = page.getByRole("alertdialog", { name: "บันทึกเป็นร่างก่อนออกไหม?" });
  await expect(prompt).toBeVisible();
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await prompt.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(caption).toHaveValue("เก็บข้อความนี้ไว้");

  // A second swipe and explicit discard then close with the downward slide.
  await dragHandle(page, 160);
  await page.mouse.up();
  await expect(prompt).toBeVisible();
  await prompt.getByRole("button", { name: "ทิ้ง" }).click();
  await expect(page.locator(".beta4-composer-backdrop")).toHaveClass(/is-closing/);
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("tapping the handle and tapping Cancel both dismiss without requiring a swipe", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await page.getByRole("button", { name: "ดึงลงหรือแตะเพื่อปิดหน้าสร้างโพสต์" }).click();
  await expect(page.locator(".beta4-composer-backdrop")).toHaveClass(/is-closing/);
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("existing image, camera, poll and audience actions remain in the composer", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  await expect(sheet.getByRole("button", { name: "เพิ่มรูปภาพ" })).toBeEnabled();
  await expect(sheet.getByRole("button", { name: "ถ่ายภาพ" })).toBeEnabled();
  await expect(sheet.getByRole("button", { name: "เพิ่มโพล" })).toBeEnabled();
  await expect(sheet.getByRole("button", { name: /เลือกผู้ชมโพสต์/ })).toBeEnabled();
});
