import { expect, test } from "@playwright/test";

// WYNOS already has a manifest, icons, splash assets and a service worker.
// These regressions cover the user-facing install flow rather than replacing it.
test("PWA manifest and install assets are served", async ({ request }) => {
  const response = await request.get("/manifest.webmanifest");
  expect(response.ok()).toBeTruthy();
  const manifest = await response.json();
  expect(manifest.name).toBe("WYNOS");
  expect(manifest.display).toBe("standalone");
  expect(manifest.scope).toBe("/");
  for (const icon of manifest.icons) {
    expect((await request.get(icon.src)).ok()).toBeTruthy();
  }
  expect((await request.get("/sw.js")).ok()).toBeTruthy();
});

test("manual install shortcut bypasses the automatic prompt cooldown", async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== "webkit-iphone", "iOS install instructions");
  await page.addInitScript(() => {
    localStorage.setItem("wyn-install-prompt-dismissed-at", String(Date.now()));
  });
  await page.goto("/welcome", { waitUntil: "networkidle" });
  await page.waitForFunction(() => document.documentElement.dataset.wynosInstallReady === "true");
  await page.evaluate(() => window.dispatchEvent(new Event("wynos:open-install")));
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toBeVisible();
  await expect(page.getByText("เปิด WYNOS ใน Safari")).toBeVisible();
  await page.getByRole("button", { name: "ปิด" }).click();
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toHaveCount(0);
});

test("manual Android install shows menu guidance without a Chrome prompt", async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-android", "Android install instructions");
  await page.goto("/welcome", { waitUntil: "networkidle" });
  await page.waitForFunction(() => document.documentElement.dataset.wynosInstallReady === "true");
  await page.evaluate(() => window.dispatchEvent(new Event("wynos:open-install")));
  await expect(page.getByText("เปิด WYNOS ใน Chrome แล้วแตะเมนู")).toBeVisible();
  await expect(page.getByRole("button", { name: "ติดตั้ง", exact: true })).toHaveCount(0);
});

test("installed app does not show install instructions", async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== "webkit-iphone", "iOS standalone detection");
  await page.addInitScript(() => {
    Object.defineProperty(navigator, "standalone", { configurable: true, value: true });
  });
  await page.goto("/welcome", { waitUntil: "networkidle" });
  // Installed mode intentionally does not install the manual shortcut.
  await page.evaluate(() => window.dispatchEvent(new Event("wynos:open-install")));
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toHaveCount(0);
});

test("appinstalled hides install UI for the rest of the current browser session", async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-android", "Android install event");
  await page.goto("/welcome", { waitUntil: "networkidle" });
  await page.waitForFunction(() => document.documentElement.dataset.wynosInstallReady === "true");
  await page.evaluate(() => window.dispatchEvent(new Event("wynos:open-install")));
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toBeVisible();
  await page.evaluate(() => window.dispatchEvent(new Event("appinstalled")));
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toHaveCount(0);
  await page.evaluate(() => window.dispatchEvent(new Event("wynos:open-install")));
  await expect(page.getByRole("dialog", { name: "เพิ่ม WYNOS ไว้ที่หน้าจอหลัก" })).toHaveCount(0);
});
