import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

/**
 * Release gate for the existing WYNOS mobile Feed.
 * Uses the deterministic shared HomePostCard fixture; no real accounts,
 * production writes, or destructive changes.
 */
for (const width of [320, 390, 432]) {
  test("mobile Feed keeps its final action row clear of the fixed nav at " + width + "px", async ({ page }) => {
    await page.setViewportSize({ width, height: 768 });
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });

    const nav = page.locator(".route-bottom-nav");
    const lastActions = page.locator(".wyn-post").last().locator(".wyn-post-actions");
    await expect(nav).toHaveCSS("position", "fixed");
    await expect(nav.locator(".route-nav-link")).toHaveCount(5);
    await expect(lastActions).toBeVisible();

    // Scroll all the way to the document end, not merely into the viewport:
    // scrollIntoViewIfNeeded() ignores a position:fixed overlay.
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    const result = await page.evaluate(() => {
      const nav = document.querySelector<HTMLElement>(".route-bottom-nav")!;
      const actions = [...document.querySelectorAll<HTMLElement>(".wyn-post-actions")].at(-1)!;
      const route = document.querySelector<HTMLElement>(".route-with-bottom-nav")!;
      const navBox = nav.getBoundingClientRect();
      const actionsBox = actions.getBoundingClientRect();
      return {
        clearance: navBox.top - actionsBox.bottom,
        routePadding: parseFloat(getComputedStyle(route).paddingBottom),
        navHeight: navBox.height,
        pageOverflow: document.documentElement.scrollWidth - window.innerWidth,
      };
    });
    expect(result.routePadding).toBeGreaterThanOrEqual(result.navHeight - 1);
    expect(result.clearance).toBeGreaterThanOrEqual(-2);
    expect(result.pageOverflow).toBeLessThanOrEqual(1);
  });

  test("single-photo Feed keeps the approved inset image layout at " + width + "px", async ({ page }) => {
    await page.setViewportSize({ width, height: 768 });
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
    const post = page.locator(".wyn-post").nth(3);
    const caption = post.locator(".wyn-post-caption-wrap");
    const track = post.locator(".wyn-post-media-track");
    const image = track.locator(".wyn-post-media-item");
    const actions = post.locator(".wyn-post-actions");
    const [captionBox, trackBox, imageBox, actionBox] = await Promise.all([
      caption.boundingBox(), track.boundingBox(), image.boundingBox(), actions.boundingBox(),
    ]);
    for (const box of [captionBox, trackBox, imageBox, actionBox]) expect(box).not.toBeNull();
    await expect(track).toHaveClass(/is-single/);
    expect(Math.abs(trackBox!.x - captionBox!.x)).toBeLessThanOrEqual(1);
    expect(Math.abs(actionBox!.x - captionBox!.x)).toBeLessThanOrEqual(1);
    expect(Math.abs(imageBox!.width - trackBox!.width)).toBeLessThanOrEqual(1);
    await expect(image).toHaveCSS("border-radius", "14px");
    await expect(track).toHaveCSS("scroll-snap-type", "x mandatory");
  });
}

test("Home verified badge has an accessible label and uses the shared approved asset", () => {
  const read = (file: string) => readFileSync(path.join(process.cwd(), file), "utf8");
  const author = read("components/home/post-author-row.tsx");
  const css = read("app/phase3.css");
  const post = read("components/home/home-post-card.tsx");
  expect(author).toContain('className="route-verified wyn-post-verified" aria-label="ยืนยันแล้ว"');
  expect(css).toContain('verified-badge-v2.svg?v=3');
  expect(post).toContain("new Intl.Segmenter");
  expect(post).toContain("chars.length > 190");
  expect(post).toContain("… ดูเพิ่มเติม");
});