import { expect, test } from "@playwright/test";

// Founder decision (2026-09-16 #479, reconfirmed 2026-09-26): WYNOS does not
// zoom, like a native app. The viewport must keep safe-area layout.
test("mobile viewport disables zoom without regressing safe-area layout", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const content = await page.locator('meta[name="viewport"]').getAttribute("content");
  expect(content).not.toBeNull();
  expect(content).toContain("viewport-fit=cover");
  expect(content).toMatch(/user-scalable\s*=\s*no/i);
  expect(content).toMatch(/maximum-scale\s*=\s*1(?:\.0+)?(?:\s*[,;]|$)/i);
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).touchAction)).toBe("manipulation");
});

// iOS Safari ignores user-scalable=no for pinch; its gesture events must be cancelled.
test("iOS pinch-zoom gestures are cancelled", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const cancelled = await page.evaluate(() => ["gesturestart", "gesturechange", "gestureend"].map((type) => {
    const event = new Event(type, { bubbles: true, cancelable: true });
    document.body.dispatchEvent(event);
    return event.defaultPrevented;
  }));
  expect(cancelled).toEqual([true, true, true]);
});
