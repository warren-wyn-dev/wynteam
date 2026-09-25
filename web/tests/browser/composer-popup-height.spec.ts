import { expect, test } from "@playwright/test";

/**
 * Layout-only regression for the existing Beta4 composer. The fixture uses
 * a fake Supabase client: these tests never publish, upload or modify live
 * account data.
 */
test.use({ serviceWorkers: "block" });

for (const [width, height] of [[320, 568], [390, 844], [432, 932]]) {
  test(`post composer opens as a near-full-height bottom sheet at ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });

    const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
    const backdrop = page.locator(".beta4-composer-backdrop");
    const handle = sheet.locator(".beta4-composer-sheet-handle");
    const title = sheet.getByRole("button", { name: "ฉบับร่าง" });
    const post = sheet.getByRole("button", { name: "โพสต์", exact: true });
    const scroll = sheet.locator(".beta4-composer-scroll");
    const toolbar = sheet.locator(".beta4-bottom-bar");

    await expect(sheet).toBeVisible();
    await expect(handle).toBeVisible();
    await expect(backdrop).toHaveCSS("align-items", "flex-end");
    await expect(post).toBeDisabled();
    await expect(title).toBeVisible();
    await expect(sheet.locator(".beta4-compose-text")).toBeVisible();
    await expect(toolbar.getByRole("button")).toHaveCount(4);

    const [box, handleBox, scrollBox, toolbarBox] = await Promise.all([
      sheet.boundingBox(), handle.boundingBox(), scroll.boundingBox(), toolbar.boundingBox(),
    ]);
    for (const value of [box, handleBox, scrollBox, toolbarBox]) expect(value).not.toBeNull();

    // The top edge sits around 8% below the viewport, leaving a glimpse of
    // the feed and status bar; the bottom edge stays flush with the screen.
    expect(box!.height / height).toBeGreaterThan(0.88);
    expect(box!.height / height).toBeLessThanOrEqual(0.93);
    expect(box!.y).toBeGreaterThan(0);
    expect(Math.abs(box!.y + box!.height - height)).toBeLessThanOrEqual(2);
    expect(handleBox!.y).toBeGreaterThanOrEqual(box!.y);
    expect(scrollBox!.y).toBeGreaterThan(handleBox!.y + handleBox!.height);
    expect(toolbarBox!.y).toBeGreaterThanOrEqual(scrollBox!.y + scrollBox!.height - 2);
    expect(toolbarBox!.y + toolbarBox!.height).toBeLessThanOrEqual(height + 2);
  });
}

test("post sheet keeps existing audience, photo, camera, poll and draft-close controls", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });

  await sheet.getByRole("button", { name: /เลือกผู้ชมโพสต์/ }).click();
  const audience = page.getByRole("dialog", { name: "เลือกผู้ชมโพสต์" });
  await expect(audience).toBeVisible();
  await audience.getByRole("button", { name: /เพื่อน/ }).click();
  await expect(sheet.getByRole("button", { name: /ตอนนี้เลือก เพื่อน/ })).toBeVisible();

  await expect(sheet.getByRole("button", { name: "เพิ่มรูปภาพ" })).toBeEnabled();
  await expect(sheet.getByRole("button", { name: "ถ่ายภาพ" })).toBeEnabled();
  await sheet.getByRole("button", { name: "เพิ่มโพล" }).click();
  await expect(sheet.getByPlaceholder("ตัวเลือกที่ 1")).toBeVisible();
  await expect(sheet.getByPlaceholder("ตัวเลือกที่ 2")).toBeVisible();
  await sheet.getByRole("button", { name: "เพิ่มโพล" }).click();

  await sheet.locator("textarea.beta4-compose-text").fill("ทดสอบเก็บฉบับร่าง");
  await expect(sheet.getByRole("button", { name: "โพสต์", exact: true })).toBeEnabled();
  await sheet.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(page.getByRole("alertdialog", { name: "บันทึกเป็นร่างก่อนออกไหม?" })).toBeVisible();
});

test("post sheet resizes with the mobile viewport while keeping the toolbar available", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await page.setViewportSize({ width: 390, height: 480 });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  const toolbar = sheet.locator(".beta4-bottom-bar");
  await expect(toolbar).toBeVisible();
  const box = await sheet.boundingBox();
  const bar = await toolbar.boundingBox();
  expect(box).not.toBeNull();
  expect(bar).not.toBeNull();
  expect(box!.height).toBeLessThanOrEqual(480);
  expect(Math.abs(box!.y + box!.height - 480)).toBeLessThanOrEqual(2);
  expect(bar!.y + bar!.height).toBeLessThanOrEqual(482);
  await expect(sheet.locator(".beta4-composer-scroll")).toHaveCSS("overflow-y", "auto");
});

test("desktop create-post composer is a centered popup rather than a full-page takeover", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  const box = await sheet.boundingBox();
  expect(box).not.toBeNull();
  expect(box!.width).toBeLessThanOrEqual(620);
  expect(box!.height).toBeLessThan(800);
  expect(box!.y).toBeGreaterThan(0);
  await expect(sheet).toHaveCSS("border-top-left-radius", "26px");
});
