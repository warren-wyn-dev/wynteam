import { expect, test } from "@playwright/test";

test.describe("Post composer caption spacing", () => {
  test("keeps an empty caption compact and grows with text", async ({ page }) => {
    await page.goto("/compose-post");
    const caption = page.locator("textarea").first();
    await expect(caption).toBeVisible();
    const emptyHeight = await caption.evaluate((node) => node.getBoundingClientRect().height);
    expect(emptyHeight).toBeLessThanOrEqual(32);
    await caption.fill("บรรทัดที่หนึ่ง\nบรรทัดที่สอง\nบรรทัดที่สาม");
    await caption.dispatchEvent("input");
    const filledHeight = await caption.evaluate((node) => node.getBoundingClientRect().height);
    expect(filledHeight).toBeGreaterThan(emptyHeight);
    expect(filledHeight).toBeLessThanOrEqual(168);
  });
});
