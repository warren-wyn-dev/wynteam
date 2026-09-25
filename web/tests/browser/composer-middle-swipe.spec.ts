import { expect, test, type Page } from "@playwright/test";

// Exercise native TouchEvent listeners using actual touch-shaped DOM events,
// without needing an authenticated account or making any live post/draft writes.
test.use({ serviceWorkers: "block" });

async function swipe(page: Page, selector: string, distanceY: number, distanceX = 0) {
  await page.locator(selector).evaluate((element, { dy, dx }) => {
    const target = element;
    const makeTouch = (x: number, y: number) => new Touch({
      identifier: 9,
      target,
      clientX: x,
      clientY: y,
      pageX: x,
      pageY: y,
      screenX: x,
      screenY: y,
    });
    const start = makeTouch(180, 360);
    target.dispatchEvent(new TouchEvent("touchstart", {
      bubbles: true, cancelable: true, touches: [start], targetTouches: [start], changedTouches: [start],
    }));
    for (let i = 1; i <= 8; i += 1) {
      const point = makeTouch(180 + dx * i / 8, 360 + dy * i / 8);
      target.dispatchEvent(new TouchEvent("touchmove", {
        bubbles: true, cancelable: true, touches: [point], targetTouches: [point], changedTouches: [point],
      }));
    }
    const end = makeTouch(180 + dx, 360 + dy);
    target.dispatchEvent(new TouchEvent("touchend", {
      bubbles: true, cancelable: true, touches: [], targetTouches: [], changedTouches: [end],
    }));
  }, { dy: distanceY, dx: distanceX });
}

for (const [width, height] of [[320, 568], [390, 844], [432, 932]]) {
  test(`swiping down from the empty middle closes a post at ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
    const surface = page.locator(".beta4-composer-scroll");
    await expect(surface).toBeVisible();
    await swipe(page, ".beta4-composer-scroll", 170);
    await expect(page.locator(".beta4-composer-backdrop")).toHaveClass(/is-closing/);
    await expect(page.getByTestId("composer-closed")).toBeVisible();
  });
}

test("a short middle swipe springs back without closing", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await swipe(page, ".beta4-composer-scroll", 20);
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await expect(page.locator(".beta4-composer-backdrop")).toHaveCSS("--wyn-composer-drag", "0px");
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
});

test("a middle swipe with written content asks before discarding, then supports Cancel", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const caption = page.locator("textarea.beta4-compose-text");
  await caption.fill("ข้อความยังไม่เสร็จ");
  await swipe(page, ".beta4-composer-scroll", 170);
  const prompt = page.getByRole("alertdialog", { name: "บันทึกเป็นร่างก่อนออกไหม?" });
  await expect(prompt).toBeVisible();
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await prompt.getByRole("button", { name: "ยกเลิก" }).click();
  await expect(caption).toHaveValue("ข้อความยังไม่เสร็จ");
  await swipe(page, ".beta4-composer-scroll", 170);
  await expect(prompt).toBeVisible();
  await prompt.getByRole("button", { name: "ทิ้ง" }).click();
  await expect(page.getByTestId("composer-closed")).toBeVisible();
});

test("scrolling a long draft does not close the sheet when the scroll surface is below its top", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const surface = page.locator(".beta4-composer-scroll");
  await surface.evaluate((element) => {
    const extra = document.createElement("div");
    extra.style.height = "2000px";
    element.appendChild(extra);
    element.scrollTop = 200;
  });
  await expect.poll(() => surface.evaluate((element) => element.scrollTop)).toBeGreaterThan(1);
  await swipe(page, ".beta4-composer-scroll", 170);
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
});

test("middle swiping upward or horizontally leaves the composer open", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  await swipe(page, ".beta4-composer-scroll", -160);
  await swipe(page, ".beta4-composer-scroll", 5, 170);
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
});

test("swiping on the actual caption input does not dismiss or prevent editing", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const caption = page.locator("textarea.beta4-compose-text");
  await caption.fill("ทดสอบพิมพ์");
  await swipe(page, "textarea.beta4-compose-text", 170);
  await expect(page.getByRole("dialog", { name: "สร้างโพสต์" })).toBeVisible();
  await expect(caption).toHaveValue("ทดสอบพิมพ์");
  await expect(page.locator(".beta4-composer-backdrop")).not.toHaveClass(/is-closing/);
});

test("middle swipe does not intercept clicks on audience, gallery, camera or polls", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/dev/composer-fixture", { waitUntil: "networkidle" });
  const sheet = page.getByRole("dialog", { name: "สร้างโพสต์" });
  await expect(sheet.getByRole("button", { name: "เพิ่มรูปภาพ" })).toBeEnabled();
  await expect(sheet.getByRole("button", { name: "ถ่ายภาพ" })).toBeEnabled();
  await sheet.getByRole("button", { name: "เพิ่มโพล" }).click();
  await expect(sheet.getByPlaceholder("ตัวเลือกที่ 1")).toBeVisible();
  await sheet.getByRole("button", { name: "เพิ่มโพล" }).click();
  await sheet.getByRole("button", { name: /เลือกผู้ชมโพสต์/ }).click();
  await expect(page.getByRole("dialog", { name: "เลือกผู้ชมโพสต์" })).toBeVisible();
});
