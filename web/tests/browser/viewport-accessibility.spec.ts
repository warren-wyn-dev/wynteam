import { expect, test } from "@playwright/test";

// A native-feeling PWA must still allow people to enlarge web content.
test("mobile viewport allows pinch zoom without regressing safe-area layout", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const content = await page.locator('meta[name="viewport"]').getAttribute("content");
  expect(content).not.toBeNull();
  expect(content).toContain("viewport-fit=cover");
  expect(content).not.toMatch(/user-scalable\s*=\s*(?:no|0)(?:\s*[,;]|$)/i);
  expect(content).not.toMatch(/maximum-scale\s*=\s*1(?:\.0+)?(?:\s*[,;]|$)/i);
});
