import { expect, test } from "@playwright/test";

test.use({ colorScheme: "light", serviceWorkers: "block" });

test("Beta 2 Home matches the approved clean feed reference", async ({ page }) => {
  await page.setViewportSize({ width: 430, height: 932 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

  const tabs = page.locator(".wyn-home-tabs");
  const composer = page.locator(".wyn-home-quick-compose");
  const post = page.locator(".wyn-post").first();
  const author = post.locator(".wyn-post-author-name");
  const caption = post.locator(".wyn-post-caption-wrap");
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
  await expect(page.getByRole("tab", { name: "สำหรับคุณ" })).toHaveCSS("font-size", "17px");
  await expect(composer).toHaveCSS("border-bottom-color", "rgb(237, 240, 242)");
  await expect(composer).toHaveCSS("min-height", "64px");
  await expect(composer.locator(".wyn-home-quick-compose-avatar")).toHaveCSS("width", "38px");
  await expect(composer.locator(".wyn-home-quick-compose-prompt")).toHaveCSS("font-size", "15px");

  await expect(author).toHaveCSS("font-size", "15.5px");
  await expect(timestamp).toHaveCSS("font-size", "13.5px");
  await expect(timestamp).toHaveCSS("color", "rgb(141, 147, 156)");
  await expect(caption).toHaveCSS("font-size", "16px");
  await expect(caption).toHaveCSS("margin-top", "2px");

  await expect(actions).toHaveCSS("gap", "26px");
  await expect(actions.locator(".wyn-action-button").nth(0).locator("svg")).toHaveCSS("width", "22px");
  await expect(actions.locator(".wyn-action-button").nth(1).locator("svg")).toHaveCSS("width", "24px");
  await expect(save.locator("svg")).toHaveCSS("width", "22px");

  await expect(idleAction).toHaveCSS("color", "rgb(133, 140, 150)");
  if (await idleCount.count()) {
    await expect(idleCount).toHaveCSS("color", "rgb(143, 150, 160)");
    await expect(idleCount).toHaveCSS("font-weight", "400");
  }
  if (await likedCount.count()) {
    await expect(likedCount).toHaveCSS("color", "rgb(255, 59, 48)");
  }
  await expect(inactiveNav).toHaveCSS("color", "rgb(143, 149, 158)");

  // Founder decision: Bookmark remains the right-most action.
  const saveBox = await save.boundingBox();
  const actionsBox = await actions.boundingBox();
  expect(saveBox).not.toBeNull();
  expect(actionsBox).not.toBeNull();
  expect(saveBox!.x + saveBox!.width).toBeGreaterThan(actionsBox!.x + actionsBox!.width * 0.88);

  // Keep the original interaction-row dimensions while reducing only visual weight.
  const stroke = await idleAction.locator("svg").first().evaluate((svg) => getComputedStyle(svg).strokeWidth);
  expect(parseFloat(stroke)).toBeCloseTo(1.75, 2);

  await expect(page.locator(".route-nav-glyph").first()).toHaveCSS("width", "28px");
  await expect(page.locator(".route-nav-link").first()).toHaveCSS("font-size", "10px");
});

for (const width of [320, 390, 432]) {
  test(`Beta 2 feed stays stable at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: width === 320 ? 700 : 932 });
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

    const tabs = page.getByRole("tab");
    const post = page.locator(".wyn-post").first();
    const actions = post.locator(".wyn-post-actions.wyn-threads-actions");
    const save = actions.locator(".wyn-action-save");

    await expect(tabs).toHaveCount(3);
    await expect(page.getByRole("tab", { name: "สำหรับคุณ" })).toBeVisible();
    await expect(page.getByRole("tab", { name: "กำลังติดตาม" })).toBeVisible();
    await expect(page.getByRole("tab", { name: "คลับของฉัน" })).toBeVisible();
    await expect(post).toBeVisible();
    await expect(actions).toBeVisible();
    await expect(save).toBeVisible();

    await expect(actions).toHaveCSS("gap", width <= 359 ? "22px" : "26px");

    const saveBox = await save.boundingBox();
    const actionsBox = await actions.boundingBox();
    expect(saveBox).not.toBeNull();
    expect(actionsBox).not.toBeNull();
    expect(saveBox!.x + saveBox!.width).toBeGreaterThan(actionsBox!.x + actionsBox!.width * 0.88);

    await expect(page.locator(".route-bottom-nav").getByRole("link")).toHaveCount(5);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    expect(overflow).toBeLessThanOrEqual(1);
  });
}
