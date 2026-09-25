import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("the existing compact mobile post image requests a content-column-sized source", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 780 });
  await page.goto("/dev/home-fixture", { waitUntil: "networkidle" });
  const image = page.locator(".wyn-post-media-item").first();
  await expect(image).toHaveAttribute("sizes", "(max-width: 680px) calc(100vw - 72px), 600px");
  await expect(image).toHaveAttribute("loading", "lazy");
  const frame = await image.boundingBox();
  expect(frame).not.toBeNull();
  expect(frame!.width).toBeLessThan(390);
});

// Source guard for the actual authenticated Home feed: fixture-only browser
// tests cannot observe its Supabase fetch pipeline without user credentials.
test("background feed tabs wait for idle and respect mobile data saving", () => {
  const home = readFileSync(path.join(process.cwd(), "components/home/home-screen.tsx"), "utf8");
  expect(home).toContain("requestIdleCallback(warmOtherTabs");
  expect(home).toContain("hints?.saveData");
  expect(home).toContain('hints?.effectiveType === "2g"');
  expect(home).toContain('document.visibilityState !== "visible"');
  expect(home).toContain("window.cancelIdleCallback(handle)");
});
