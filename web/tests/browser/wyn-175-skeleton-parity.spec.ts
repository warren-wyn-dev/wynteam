import { expect, test } from "@playwright/test";

/**
 * WYN-175 regression coverage. The first version of NotificationSkeleton
 * and the Discovery hashtag skeleton row were built from the first CSS
 * rule found for `.notification-row`/`.hashtag-row`, not the one that
 * actually wins this codebase's parity/pixel-parity override cascade — causing
 * a real layout shift once data replaced the skeleton
 * (`.wyn/tasks/bugs/WYN-175-skeleton-row-height-cascade-mismatch.md`).
 * Asserts every skeleton row stays within 1px of the real row it stands
 * in for, so a future CSS change to either side that reintroduces a
 * mismatch fails CI instead of only being caught by manual QA.
 */
test.beforeEach(async ({ page }) => {
  await page.goto("/dev/wyn-175-skeleton-fixture", { waitUntil: "networkidle" });
});

async function heightOf(page: import("@playwright/test").Page, selector: string) {
  const box = await page.locator(selector).first().boundingBox();
  if (!box) throw new Error(`${selector} did not render`);
  return box.height;
}

test("search user skeleton row height matches the real row", async ({ page }) => {
  const skel = await heightOf(page, "#skel-user .wyn-skeleton-search-person-row");
  const real = await heightOf(page, "#real-user .route-person-row");
  expect(Math.abs(skel - real)).toBeLessThanOrEqual(1);
});

test("search club skeleton row height matches the real row", async ({ page }) => {
  const skel = await heightOf(page, "#skel-club .wyn-skeleton-search-club-row");
  const real = await heightOf(page, "#real-club");
  expect(Math.abs(skel - real)).toBeLessThanOrEqual(1);
});

test("notification skeleton row height matches the real row", async ({ page }) => {
  const skel = await heightOf(page, "#skel-notification .wyn-skeleton-notification-row");
  const real = await heightOf(page, "#real-notification");
  expect(Math.abs(skel - real)).toBeLessThanOrEqual(1);
});

test("discovery hashtag skeleton row height matches the real row", async ({ page }) => {
  const skel = await heightOf(page, "#skel-discovery .wyn-skeleton-hashtag-row");
  const real = await heightOf(page, "#real-hashtag");
  expect(Math.abs(skel - real)).toBeLessThanOrEqual(1);
});

test("skeleton shimmer animation runs, and stops under prefers-reduced-motion", async ({ page }) => {
  const el = page.locator("#skel-user .wyn-skeleton").first();
  const running = await el.evaluate((node) => getComputedStyle(node, "::after").animationName);
  expect(running).toBe("wyn-skeleton-shimmer");

  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.reload({ waitUntil: "networkidle" });
  const reduced = await page.locator("#skel-user .wyn-skeleton").first().evaluate(
    (node) => getComputedStyle(node, "::after").animationName,
  );
  expect(reduced).toBe("none");
});
