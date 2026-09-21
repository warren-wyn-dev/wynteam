import { expect, test } from "@playwright/test";

/**
 * WYNOS Web Beta1, item 12: MAX_POST_IMAGES (web/lib/post-limits.ts) is
 * the single source of truth for the per-post image cap (9), shared by
 * the composer's picker, its truncation, and its counter -- previously
 * scattered as a bare `9` in ~6 places. Selecting more than the cap must
 * truncate AND notify, not silently drop the extras. Drives
 * /dev/image-limit-fixture (the composer's gallery-picker logic in
 * isolation), since the full composer needs a live Supabase session.
 */
function makeTempImageFiles(count: number): { name: string; mimeType: string; buffer: Buffer }[] {
  const tiny1x1PngBytes = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  );
  return Array.from({ length: count }, (_, index) => ({
    name: `photo-${index + 1}.png`,
    mimeType: "image/png",
    buffer: tiny1x1PngBytes,
  }));
}

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/image-limit-fixture", { waitUntil: "networkidle" });
});

test("selecting exactly the max (9) shows no error and the full count", async ({ page }) => {
  await page.locator("#gallery-input").setInputFiles(makeTempImageFiles(9));
  await expect(page.locator("#image-count")).toHaveText("9/9");
  await expect(page.locator("#image-error")).toHaveCount(0);
});

test("selecting more than the max (12) truncates to 9 and shows a notice", async ({ page }) => {
  await page.locator("#gallery-input").setInputFiles(makeTempImageFiles(12));
  await expect(page.locator("#image-count")).toHaveText("9/9");
  await expect(page.locator("#image-error")).toContainText("สูงสุด 9 รูป");
});

test("adding more on top of an already-full selection still caps at 9 with a notice", async ({ page }) => {
  await page.locator("#gallery-input").setInputFiles(makeTempImageFiles(9));
  await page.locator("#gallery-input").setInputFiles(makeTempImageFiles(3));
  await expect(page.locator("#image-count")).toHaveText("9/9");
  await expect(page.locator("#image-error")).toBeVisible();
});
