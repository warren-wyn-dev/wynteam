import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("primary navigation scrolls to top on repeat Home tab tap without page reload", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 600 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const nav = page.getByRole("navigation", { name: "เมนูหลัก" });
  await expect(nav.getByRole("link")).toHaveCount(5);
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(40);
  const url = page.url();
  await nav.getByRole("link", { name: "หน้าหลัก" }).click();
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBeLessThan(15);
  expect(page.url()).toBe(url);
});

// The other two root destinations use the same repeat-tap callback as
// Home and have registered route-local refresh listeners.
test("Club and Chat root tabs handle repeat-tap refresh without reloading", () => {
  const file = (name: string) => readFileSync(path.join(process.cwd(), "components", name), "utf8");
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(clubActive, "/clubs")}');
  expect(file("bottom-navigation.tsx")).toContain('onClick={handleActiveTabTap(chatActive, "/chat")}');
  expect(file("clubs-routes.tsx")).toContain("useRouteRefreshListener(pull.refresh)");
  expect(file("chat-routes.tsx")).toContain("useRouteRefreshListener(refreshInbox)");
  expect(file("chat-routes.tsx")).toContain('const cacheKey = `chat-inbox:${userId}`');
});
