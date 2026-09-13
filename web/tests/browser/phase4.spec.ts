import { expect, test } from "@playwright/test";

const id = "00000000-0000-0000-0000-000000000000";
const routes = [
  "/",
  "/search",
  "/notifications",
  "/chat",
  "/settings",
  "/profile/me",
  `/profile/${id}`,
  `/drop/${id}`,
  `/pop/${id}`,
  `/club/${id}`,
  `/club-post/${id}`,
  "/club-invite/phase4-test",
  "/@wynos",
];

test("consumer routes render without fatal errors or horizontal overflow", async ({ page }) => {
  const pageErrors: string[] = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  for (const route of routes) {
    const response = await page.goto(route, { waitUntil: "domcontentloaded" });
    expect(response, `${route} should return a document response`).not.toBeNull();
    expect(response!.status(), `${route} should not return a server error`).toBeLessThan(500);
    await expect(page.locator("body")).toBeVisible();

    const layout = await page.evaluate(() => ({
      viewport: window.innerWidth,
      documentWidth: document.documentElement.scrollWidth,
      platformViews: document.querySelectorAll("flt-platform-view").length,
    }));
    expect(layout.documentWidth, `${route} should not overflow horizontally`).toBeLessThanOrEqual(layout.viewport + 1);
    expect(layout.platformViews, `${route} should remain DOM-native`).toBe(0);
  }

  expect(pageErrors).toEqual([]);
});

test("system-font stack remains browser/OS native", async ({ page }) => {
  await page.goto("/", { waitUntil: "domcontentloaded" });
  const fontFamily = await page.evaluate(() => getComputedStyle(document.body).fontFamily);
  expect(fontFamily).toContain("-apple-system");
  expect(fontFamily).toContain("BlinkMacSystemFont");
  expect(fontFamily).not.toMatch(/SF Pro|CupertinoSystemText|CupertinoSystemDisplay/i);
});

test("repeated route churn keeps the page process alive", async ({ page }) => {
  await page.goto("/", { waitUntil: "domcontentloaded" });
  await page.evaluate(() => sessionStorage.setItem("wyn-phase4-marker", "alive"));

  const churnRoutes = ["/search", "/notifications", "/chat", "/settings", "/profile/me", "/"];
  for (let cycle = 0; cycle < 3; cycle += 1) {
    for (const route of churnRoutes) {
      const response = await page.goto(route, { waitUntil: "domcontentloaded" });
      expect(response?.status() ?? 500).toBeLessThan(500);
      await expect(page.locator("body")).toBeVisible();
    }
  }

  expect(await page.evaluate(() => sessionStorage.getItem("wyn-phase4-marker"))).toBe("alive");
});
