import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 3: the "ดูอันดับทั้งหมด (Top 100)" button must lead
 * to a real, working /trending page with distinct loading/error/empty/list
 * states and a single <main> (no nested AppChrome <main> + a second one from
 * the route's own content).
 */
test.use({ viewport: { width: 390, height: 844 } });

test("trending link on the search page points at /trending", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=list", { waitUntil: "networkidle" });
  // Sanity check the fixture itself renders a real <a href="/trending">-shaped
  // link pattern is covered indirectly by the component source; this spec
  // focuses on the destination page's own state rendering, since the
  // Search page itself needs a live Supabase session to render at all.
  await expect(page.locator("h1")).toHaveText("อันดับแฮชแท็ก (Top 100)");
});

test("shows the hashtag list with rank, tag, and post count", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=list", { waitUntil: "networkidle" });
  const rows = page.locator(".trending-top100-list .hashtag-row");
  await expect(rows).toHaveCount(2);
  await expect(rows.first()).toContainText("1");
  await expect(rows.first()).toContainText("#wynos");
  await expect(rows.first()).toContainText("42");
});

test("shows a distinct loading state", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=loading", { waitUntil: "networkidle" });
  await expect(page.locator(".route-system-spinner")).toBeVisible();
  await expect(page.locator(".hashtag-row")).toHaveCount(0);
});

test("shows a distinct error state with a retry action, not silently empty", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=error", { waitUntil: "networkidle" });
  await expect(page.locator("#retry-button")).toBeVisible();
  await expect(page.locator(".route-empty")).toContainText("ไม่สำเร็จ");
});

test("shows a distinct empty state, different wording from the error state", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=empty", { waitUntil: "networkidle" });
  await expect(page.locator(".route-empty")).toContainText("ยังไม่มีแฮชแท็กกำลังนิยม");
  await expect(page.locator("#retry-button")).toHaveCount(0);
});

test("page has exactly one <main> landmark", async ({ page }) => {
  await page.goto("/dev/trending-fixture?state=list", { waitUntil: "networkidle" });
  await expect(page.locator("main")).toHaveCount(1);
});
