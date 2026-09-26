import { expect, test } from "@playwright/test";

/**
 * Uses the real HomePostCard + PostActions, backed by the deterministic
 * /dev/home-fixture. No real accounts or production writes.
 */
test("liked heart stays vivid red and engagement numbers roll with direction", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

  const like = page.locator(".wyn-post").first().locator(".wyn-post-actions button").first();
  const count = like.locator(".wyn-animated-count");

  await expect(like).toHaveAttribute("aria-pressed", "true");
  await expect(like).toHaveCSS("color", "rgb(255, 59, 48)");
  await expect(count).toHaveText("6");

  await like.click();
  await expect(like).toHaveAttribute("aria-pressed", "false");
  await expect(count).toHaveAttribute("data-direction", "down");
  await expect(count).toHaveText("5");

  await like.click();
  await expect(like).toHaveAttribute("aria-pressed", "true");
  await expect(like).toHaveCSS("color", "rgb(255, 59, 48)");
  await expect(count).toHaveAttribute("data-direction", "up");
  await expect(count).toHaveText("6");
});

test("reduced-motion users still see updated engagement values", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const like = page.locator(".wyn-post").first().locator(".wyn-post-actions button").first();
  const count = like.locator(".wyn-animated-count");
  await like.click();
  await expect(count).toHaveText("5");
  await like.click();
  await expect(count).toHaveText("6");
});
