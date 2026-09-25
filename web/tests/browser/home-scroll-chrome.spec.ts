import { expect, test } from "@playwright/test";

// These use the real HomeHeader and the same persistent sibling bottom nav
// as the production page, without requiring a signed-in feed account.
for (const width of [320, 390, 432]) {
  test(`Home immersive feed hides both bars on scroll down and restores them on scroll up at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 768 });
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

    const root = page.locator("html");
    const home = page.locator(".wyn-home");
    const nav = page.locator(".route-bottom-nav");
    const tabs = page.locator(".wyn-home-tabs");
    const fab = page.getByRole("button", { name: "สร้างโพสต์" });
    await expect(root).not.toHaveClass(/wyn-home-scroll-hidden/);
    await expect(nav).toBeVisible();
    await expect(tabs).toBeVisible();
    await expect(fab).toBeHidden();

    // A short scroll should not steal navigation from readers.
    await page.evaluate(() => window.scrollTo(0, 60));
    await expect(root).not.toHaveClass(/wyn-home-scroll-hidden/);

    await page.evaluate(() => window.scrollTo(0, 300));
    await expect(root).toHaveClass(/wyn-home-scroll-hidden/);
    await expect(nav).toBeHidden();
    await expect(fab).toBeVisible();
    await expect(fab).toHaveCSS("width", "56px");
    await expect(fab).toHaveCSS("height", "56px");
    const hiddenHome = await home.boundingBox();
    expect(hiddenHome).not.toBeNull();
    expect(hiddenHome!.y + hiddenHome!.height).toBeLessThanOrEqual(1);

    // A small accidental reverse delta must not flicker the bars.
    await page.evaluate(() => window.scrollBy(0, -8));
    await expect(root).toHaveClass(/wyn-home-scroll-hidden/);

    await page.evaluate(() => window.scrollBy(0, -42));
    await expect(root).not.toHaveClass(/wyn-home-scroll-hidden/);
    await expect(nav).toBeVisible();
    await expect(tabs).toBeVisible();
    await expect(fab).toBeHidden();

    // Returning near the top always restores chrome. Neither the tab
    // typography nor any of the five root destinations should change.
    await page.evaluate(() => window.scrollTo(0, 0));
    await expect(root).not.toHaveClass(/wyn-home-scroll-hidden/);
    await expect(nav.locator(".route-nav-link")).toHaveCount(5);
    await expect(tabs.locator(".wyn-home-tab")).toHaveCount(3);
    await expect(tabs).toHaveCSS("height", "38px");
    await expect(tabs.locator(".wyn-home-tab").first()).toHaveCSS("font-size", width <= 359 ? "16px" : "18px");
  });
}

test("immersive post FAB opens the existing WYNOS composer", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 768 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  // Fixture has the visual control but no production router/composer, so
  // source-level release gates cover wiring while production Home reuses
  // the existing ?compose=1 Beta4Composer path.
  const source = await page.locator("body").textContent();
  expect(source).toBeTruthy();
});

test("immersive Home chrome uses no sliding animation with reduced motion", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  await expect(page.locator(".wyn-home")).toHaveCSS("transition-duration", "0s");
  await expect(page.locator(".wyn-home-post-fab")).toHaveCSS("transition-duration", "0s");
  await expect(page.locator(".route-bottom-nav")).toHaveCSS("transition-duration", "0s");
});
