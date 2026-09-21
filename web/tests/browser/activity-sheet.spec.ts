import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 8: the Activity sheet grew from 2 tabs (Likes/
 * Reposts) to 5 (+Views/Comments/Saves). Views/Saves must be count-only
 * (no person list — drop_views/saves are both privacy-scoped so there's
 * nothing to list even for the post's own author); Likes/Comments/Reposts
 * keep showing a person list, with its own empty state distinct from the
 * count tabs. Drives /dev/activity-sheet-fixture (see
 * activity-sheet-fixture.tsx) since the real sheet needs a live Supabase
 * session for its RPC calls.
 */
test.use({ viewport: { width: 390, height: 844 } });

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/activity-sheet-fixture", { waitUntil: "networkidle" });
});

test("all 5 tabs render with their counts", async ({ page }) => {
  await expect(page.locator("#tab-views")).toContainText("ยอดดู (42)");
  await expect(page.locator("#tab-likes")).toContainText("ถูกใจ (2)");
  await expect(page.locator("#tab-comments")).toContainText("ความคิดเห็น (1)");
  await expect(page.locator("#tab-redrops")).toContainText("รีโพสต์ (0)");
  await expect(page.locator("#tab-saves")).toContainText("บันทึก (5)");
});

test("Views tab is count-only, no person list", async ({ page }) => {
  await expect(page.locator("#tab-views")).toHaveAttribute("aria-selected", "true");
  await expect(page.locator("#count-only strong")).toHaveText("42");
  await expect(page.locator("#person-list")).toHaveCount(0);
});

test("Saves tab is count-only, no person list", async ({ page }) => {
  await page.locator("#tab-saves").click();
  await expect(page.locator("#count-only strong")).toHaveText("5");
  await expect(page.locator("#person-list")).toHaveCount(0);
});

test("Likes tab shows the person list", async ({ page }) => {
  await page.locator("#tab-likes").click();
  await expect(page.locator("#person-list a")).toHaveCount(2);
  await expect(page.locator("#count-only")).toHaveCount(0);
});

test("Reposts tab (0 count) shows a distinct empty state, not the count-only view", async ({ page }) => {
  await page.locator("#tab-redrops").click();
  await expect(page.locator("#empty-state")).toBeVisible();
  await expect(page.locator("#count-only")).toHaveCount(0);
  await expect(page.locator("#person-list")).toHaveCount(0);
});
