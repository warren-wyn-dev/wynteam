import { expect, test } from "@playwright/test";

test.use({ colorScheme: "light", serviceWorkers: "block" });

test("Beta 2 Home keeps the approved Threads layout while softening secondary chrome", async ({ page }) => {
  await page.setViewportSize({ width: 430, height: 932 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

  const tabs = page.locator(".wyn-home-tabs");
  const composer = page.locator(".wyn-home-quick-compose");
  const post = page.locator(".wyn-post").first();
  const timestamp = post.locator(".wyn-post-timestamp");
  const actions = post.locator(".wyn-post-actions.wyn-threads-actions");
  const idleAction = actions.locator(".wyn-action-button:not(.is-liked):not(.is-active)").first();
  const idleCount = idleAction.locator(".wyn-action-button-count").first();
  const likedCount = actions.locator(".wyn-action-button.is-liked .wyn-action-button-count").first();
  const save = actions.locator(".wyn-action-save");
  const inactiveNav = page.locator(".route-nav-link:not(.active)").first();

  await expect(tabs).toBeVisible();
  await expect(composer).toBeVisible();
  await expect(post).toBeVisible();
  await expect(actions).toBeVisible();
  await expect(save).toBeVisible();

  await expect(tabs).toHaveCSS("border-bottom-color", "rgb(237, 240, 242)");
  await expect(composer).toHaveCSS("border-bottom-color", "rgb(237, 240, 242)");
  await expect(composer).toHaveCSS("min-height", "58px");
  await expect(page.getByRole("tab", { name: "สำหรับคุณ" })).toHaveCSS("font-size", "17px");
  await expect(timestamp).toHaveCSS("color", "rgb(141, 147, 156)");
  await expect(idleAction).toHaveCSS("color", "rgb(133, 140, 150)");
  if (await idleCount.count()) {
    await expect(idleCount).toHaveCSS("color", "rgb(154, 160, 169)");
    await expect(idleCount).toHaveCSS("font-weight", "400");
  }
  if (await likedCount.count()) {
    await expect(likedCount).toHaveCSS("color", "rgb(255, 59, 48)");
  }
  await expect(inactiveNav).toHaveCSS("color", "rgb(150, 155, 163)");

  const saveBox = await save.boundingBox();
  const actionsBox = await actions.boundingBox();
  expect(saveBox).not.toBeNull();
  expect(actionsBox).not.toBeNull();
  // Bookmark remains the right-most action, as approved.
  expect(saveBox!.x + saveBox!.width).toBeGreaterThan(actionsBox!.x + actionsBox!.width * 0.88);

  const stroke = await idleAction.locator("svg").first().evaluate((svg) => getComputedStyle(svg).strokeWidth);
  expect(parseFloat(stroke)).toBeCloseTo(1.6, 2);
});
