import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 7: search query + result tab live in the URL, so a
 * refresh/back/forward/shared link reproduces the same search, typing is
 * debounced, and "ทั้งหมด" (All) is the default tab -- not "User" (which
 * used to make a query that only matches posts land on an empty User tab
 * first). Drives the URL-sync logic directly via /dev/search-url-fixture
 * (see search-url-fixture.tsx), since the real search-route.tsx needs a
 * live Supabase session for its actual result data.
 */
test.use({ viewport: { width: 390, height: 844 } });

test("typing debounces into the URL as ?q=...", async ({ page }) => {
  await page.goto("/dev/search-url-fixture", { waitUntil: "networkidle" });
  await page.locator("#search-input").fill("wynos");
  // Not yet -- debounce hasn't elapsed.
  await expect(page).not.toHaveURL(/q=wynos/);
  await expect(page).toHaveURL(/q=wynos/, { timeout: 2000 });
  await expect(page.locator("#active-state")).toHaveText("all:wynos");
});

test("defaults to the \"ทั้งหมด\" (All) tab, not User", async ({ page }) => {
  await page.goto("/dev/search-url-fixture?q=wynos", { waitUntil: "networkidle" });
  await expect(page.locator("#tab-all")).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#active-state")).toHaveText("all:wynos");
});

test("clicking a tab updates ?type= and stays there on reload", async ({ page }) => {
  await page.goto("/dev/search-url-fixture?q=wynos", { waitUntil: "networkidle" });
  await page.locator("#tab-posts").click();
  await expect(page).toHaveURL(/type=posts/);
  await page.reload({ waitUntil: "networkidle" });
  await expect(page.locator("#tab-posts")).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#active-state")).toHaveText("posts:wynos");
});

test("loading a shared URL with q and type reproduces the same search", async ({ page }) => {
  await page.goto("/dev/search-url-fixture?q=hello&type=clubs", { waitUntil: "networkidle" });
  await expect(page.locator("#search-input")).toHaveValue("hello");
  await expect(page.locator("#tab-clubs")).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#active-state")).toHaveText("clubs:hello");
});

test("a single-character query does not trigger a search", async ({ page }) => {
  await page.goto("/dev/search-url-fixture", { waitUntil: "networkidle" });
  await page.locator("#search-input").fill("a");
  await page.waitForTimeout(600);
  await expect(page).not.toHaveURL(/q=/);
  await expect(page.locator("#active-state")).toHaveText("discovery");
});
