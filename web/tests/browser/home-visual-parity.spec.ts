import { expect, test } from "@playwright/test";

/**
 * WYN-158 Home visual regression.
 *
 * Renders the deterministic fixture at /dev/home-fixture (see
 * components/home/home-fixture.tsx) instead of a live Supabase feed, so
 * screenshots are stable across runs. Covers a normal verified user with
 * a long username, a pending-follow author, Thai multiline captions with
 * hashtags, a single image, non-zero interaction counts, an active Like
 * state, and a second (long-caption) post.
 *
 * Snapshots live under tests/browser/home-visual-parity.spec.ts-snapshots/
 * (standard Playwright layout). Run `npx playwright test
 * home-visual-parity --update-snapshots` after an intentional visual
 * change to re-baseline.
 */

test.beforeEach(async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  // Fixture images are remote (picsum.photos); wait for the first post's
  // photo to finish loading so the screenshot never captures a placeholder.
  await page.locator(".wyn-post-media-item").first().evaluate((img) => {
    const image = img as HTMLImageElement;
    if (image.complete) return;
    return new Promise((resolve) => {
      image.addEventListener("load", resolve, { once: true });
      image.addEventListener("error", resolve, { once: true });
    });
  });
});

test("Home header and tabs match the Flutter chrome contract", async ({ page }) => {
  await expect(page.locator(".wyn-home")).toHaveScreenshot("home-header-tabs.png");
});

test("full first post matches Flutter HomeDropCard geometry", async ({ page }) => {
  await expect(page.locator(".wyn-post").first()).toHaveScreenshot("home-first-post.png");
});

test("Home with bottom navigation matches Founder metrics", async ({ page }) => {
  await expect(page).toHaveScreenshot("home-bottom-nav.png", { fullPage: true });
});

test("long caption state stays dense with no unnecessary blank gap", async ({ page }) => {
  await expect(page.locator(".wyn-post").nth(1)).toHaveScreenshot("home-long-caption.png");
});
