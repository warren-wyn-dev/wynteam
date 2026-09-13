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

test("consumer routes render without fatal errors or horizontal overflow", async ({ page }, testInfo) => {
  let currentRoute = "<before-first-navigation>";
  const pageErrors: Array<{ route: string; pageUrl: string; message: string }> = [];
  const requestFailures: Array<{
    route: string;
    pageUrl: string;
    resourceType: string;
    requestUrl: string;
    errorText: string;
  }> = [];
  const badResponses: Array<{
    route: string;
    pageUrl: string;
    resourceType: string;
    responseUrl: string;
    status: number;
  }> = [];

  page.on("pageerror", (error) => {
    pageErrors.push({
      route: currentRoute,
      pageUrl: page.url(),
      message: error.message,
    });
  });

  page.on("requestfailed", (request) => {
    requestFailures.push({
      route: currentRoute,
      pageUrl: page.url(),
      resourceType: request.resourceType(),
      requestUrl: request.url(),
      errorText: request.failure()?.errorText ?? "unknown request failure",
    });
  });

  page.on("response", (response) => {
    if (response.status() < 400) return;
    badResponses.push({
      route: currentRoute,
      pageUrl: page.url(),
      resourceType: response.request().resourceType(),
      responseUrl: response.url(),
      status: response.status(),
    });
  });

  for (const route of routes) {
    currentRoute = route;
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

  if (pageErrors.length > 0) {
    const diagnostics = { pageErrors, requestFailures, badResponses };
    const body = JSON.stringify(diagnostics, null, 2);
    console.error(`Hosted browser diagnostics:\n${body}`);
    await testInfo.attach("hosted-browser-diagnostics", {
      body,
      contentType: "application/json",
    });
  }

  expect(pageErrors, "browser page errors with route/network diagnostics above").toEqual([]);
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
