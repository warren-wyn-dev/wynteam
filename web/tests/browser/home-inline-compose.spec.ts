import { expect, test } from "@playwright/test";

// Uses the same presentational component as signed-in Home, but without
// accounts, API traffic, live posts or drafts.
test.use({ serviceWorkers: "block" });

for (const width of [320, 390, 432]) {
  test(`minimal quick compose stays under the tabs and opens the existing composer at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 768 });
    await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
    const tabs = page.locator(".wyn-home-tabs");
    const row = page.getByRole("link", { name: "สร้างโพสต์ มีอะไรอยากแชร์?" });

    await expect(row).toBeVisible();
    await expect(row).toHaveAttribute("href", "/?compose=1");
    await expect(row).toContainText("มีอะไรอยากแชร์?");
    await expect(row.locator(".wyn-home-quick-compose-avatar .wyn-default-profile-avatar")).toBeVisible();
    await expect(row.locator(".wyn-home-quick-compose-image")).toBeVisible();
    await expect(row).toHaveCSS("border-bottom-width", "1px");
    await expect(row).toHaveCSS("box-shadow", "none");
    await expect(row).toHaveCSS("border-radius", "0px");

    const [tabsBox, composeBox, firstPostBox] = await Promise.all([
      tabs.boundingBox(), row.boundingBox(), page.locator(".wyn-post").first().boundingBox(),
    ]);
    expect(tabsBox).not.toBeNull();
    expect(composeBox).not.toBeNull();
    expect(firstPostBox).not.toBeNull();
    expect(Math.abs(composeBox!.y - (tabsBox!.y + tabsBox!.height))).toBeLessThanOrEqual(1);
    expect(Math.abs(firstPostBox!.y - (composeBox!.y + composeBox!.height))).toBeLessThanOrEqual(1);
    expect(composeBox!.height).toBeGreaterThanOrEqual(60);
    expect(composeBox!.height).toBeLessThanOrEqual(75);
  });
}

test("quick compose is present in For You and Following, not Clubs", async ({ page }) => {
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const row = page.getByRole("link", { name: "สร้างโพสต์ มีอะไรอยากแชร์?" });

  await expect(row).toBeVisible();
  await page.getByRole("tab", { name: "กำลังติดตาม" }).click();
  await expect(row).toBeVisible();
  await page.getByRole("tab", { name: "คลับของฉัน" }).click();
  await expect(row).toHaveCount(0);
  await page.getByRole("tab", { name: "สำหรับคุณ" }).click();
  await expect(row).toBeVisible();
});

test("inline composer scrolls with the feed while the existing header stays sticky", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 768 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const row = page.getByRole("link", { name: "สร้างโพสต์ มีอะไรอยากแชร์?" });
  const initial = await row.boundingBox();
  expect(initial).not.toBeNull();

  await page.evaluate(() => window.scrollTo(0, 300));
  await expect(page.locator("html")).toHaveClass(/wyn-home-scroll-hidden/);
  const scrolled = await row.boundingBox();
  expect(scrolled).not.toBeNull();
  expect(scrolled!.y).toBeLessThan(initial!.y - 200);
  await expect(page.locator(".wyn-home-post-fab")).toBeVisible();
});

test("quick compose stays quiet and legible in dark mode", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const row = page.getByRole("link", { name: "สร้างโพสต์ มีอะไรอยากแชร์?" });
  await expect(row).toBeVisible();
  const style = await row.evaluate((el) => {
    const computed = getComputedStyle(el);
    const prompt = getComputedStyle(el.querySelector(".wyn-home-quick-compose-prompt")!);
    return { rowBackground: computed.backgroundColor, promptColor: prompt.color, shadow: computed.boxShadow };
  });
  expect(style.rowBackground).not.toBe("rgb(255, 255, 255)");
  expect(style.promptColor).not.toBe(style.rowBackground);
  expect(style.shadow).toBe("none");
});
